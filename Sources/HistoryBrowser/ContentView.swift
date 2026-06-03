import SwiftUI

extension Notification.Name {
    static let historyBrowserRefresh = Notification.Name("HistoryBrowserRefresh")
    static let historyBrowserGrantSafariFolder = Notification.Name("HistoryBrowserGrantSafariFolder")
    static let historyBrowserChooseDatabase = Notification.Name("HistoryBrowserChooseDatabase")
    static let historyBrowserRevealDatabase = Notification.Name("HistoryBrowserRevealDatabase")
    static let historyBrowserOpenFullDiskAccess = Notification.Name("HistoryBrowserOpenFullDiskAccess")
    static let historyBrowserJumpToday = Notification.Name("HistoryBrowserJumpToday")
    static let historyBrowserShowAllDates = Notification.Name("HistoryBrowserShowAllDates")
}

struct ContentView: View {
    @StateObject private var store = HistoryStore()
    @State private var searchText = ""
    @State private var selectedEntry: HistoryEntry.ID?
    @State private var calendarDate = Date()
    @State private var isDateFilterActive = false

    private var searchedEntries: [HistoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return store.entries
        }

        return store.entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(query)
                || entry.url.localizedCaseInsensitiveContains(query)
                || entry.host.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredEntries: [HistoryEntry] {
        guard isDateFilterActive else {
            return searchedEntries
        }

        return searchedEntries.filter { entry in
            Calendar.current.isDate(entry.visitDate, inSameDayAs: calendarDate)
        }
    }

    private var selectedDayEntries: [HistoryEntry] {
        store.entries.filter { entry in
            Calendar.current.isDate(entry.visitDate, inSameDayAs: calendarDate)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if store.entries.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    calendarPane
                    Divider()
                    historyTable
                }
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search title, URL, or host")
        .task {
            store.loadDefaultHistory()
        }
        .onChange(of: store.newestVisit) { _, newestVisit in
            if !isDateFilterActive, let newestVisit {
                calendarDate = newestVisit
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyBrowserRefresh)) { _ in
            store.loadDefaultHistory()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyBrowserGrantSafariFolder)) { _ in
            store.chooseSafariFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyBrowserChooseDatabase)) { _ in
            store.chooseDatabase()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyBrowserRevealDatabase)) { _ in
            store.revealInFinder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyBrowserOpenFullDiskAccess)) { _ in
            store.openFullDiskAccessSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyBrowserJumpToday)) { _ in
            jumpToToday()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyBrowserShowAllDates)) { _ in
            showAllDates()
        }
        .alert("History Browser", isPresented: errorBinding) {
            Button("Grant Safari Folder") {
                store.chooseSafariFolder()
            }
            Button("Full Disk Access") {
                store.openFullDiskAccessSettings()
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Safari History")
                    .font(.title2.weight(.semibold))

                Text(summaryText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                store.revealInFinder()
            } label: {
                Label("Reveal", systemImage: "folder")
            }
            .help("Reveal the selected History.db in Finder")

            Button {
                store.chooseSafariFolder()
            } label: {
                Label("Grant Folder", systemImage: "lock.open")
            }
            .help("Grant access to ~/Library/Safari")

            Menu {
                Button("Choose Safari Folder") {
                    store.chooseSafariFolder()
                }

                Button("Choose History.db Copy") {
                    store.chooseDatabase()
                }

                Divider()

                Button("Open Full Disk Access Settings") {
                    store.openFullDiskAccessSettings()
                }
            } label: {
                Label("Access", systemImage: "ellipsis.circle")
            }
            .menuStyle(.button)
            .help("Manage history database access")

            Button {
                store.loadDefaultHistory()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r")
            .disabled(store.isLoading)
            .help("Reload Safari history")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var calendarPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HistoryCalendarView(
                selectedDate: calendarSelection,
                entries: store.entries,
                oldestDate: store.oldestVisit,
                newestDate: store.newestVisit
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(calendarDate.formatted(date: .complete, time: .omitted))
                    .font(.headline)
                    .lineLimit(2)

                Text(daySummaryText)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Button {
                    jumpToToday()
                } label: {
                    Label("Today", systemImage: "calendar")
                }
                .disabled(store.entries.isEmpty)

                Button {
                    showAllDates()
                } label: {
                    Label("All", systemImage: "calendar.badge.minus")
                }
                .disabled(!isDateFilterActive)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label(dateRangeText, systemImage: "calendar.badge.clock")
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Label("\(store.entries.count.formatted()) total visits", systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 300)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var historyTable: some View {
        Table(filteredEntries, selection: $selectedEntry) {
            TableColumn("Visited") { entry in
                Text(entry.visitDate, format: .dateTime.year().month().day().hour().minute())
                    .monospacedDigit()
            }
            .width(min: 170, ideal: 190, max: 220)

            TableColumn("Title") { entry in
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .lineLimit(1)
                    Text(entry.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .width(min: 260, ideal: 420)

            TableColumn("URL") { entry in
                Text(entry.url)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .width(min: 360, ideal: 560)

            TableColumn("Visits") { entry in
                Text(entry.visitCount.formatted())
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 80, max: 100)
        }
        .overlay(alignment: .center) {
            if filteredEntries.isEmpty {
                if isDateFilterActive {
                    ContentUnavailableView {
                        Label("No Visits", systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text(calendarDate.formatted(date: .complete, time: .omitted))
                    }
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No History Loaded", systemImage: "clock.arrow.circlepath")
        } description: {
            if store.isLoading {
                Text("Reading Safari history...")
            } else {
                Text("Grant access to the Safari folder, or add History Browser to Full Disk Access.")
            }
        } actions: {
            Button("Grant Safari Folder") {
                store.chooseSafariFolder()
            }

            Button("Refresh") {
                store.loadDefaultHistory()
            }
            .disabled(store.isLoading)
        }
    }

    private var summaryText: String {
        if store.isLoading {
            return "Loading \(store.selectedDatabaseURL.path)"
        }

        guard !store.entries.isEmpty else {
            return store.selectedDatabaseURL.path
        }

        let range: String
        if let oldest = store.oldestVisit, let newest = store.newestVisit {
            range = "\(oldest.formatted(date: .abbreviated, time: .omitted)) - \(newest.formatted(date: .abbreviated, time: .omitted))"
        } else {
            range = "date range unavailable"
        }

        let filtered = filteredEntries.count == store.entries.count
            ? ""
            : " | \(filteredEntries.count.formatted()) shown"

        return "\(store.entries.count.formatted()) visits | \(range)\(filtered)"
    }

    private var daySummaryText: String {
        guard isDateFilterActive else {
            return "Showing all dates"
        }

        let dayCount = selectedDayEntries.count
        let searchCount = filteredEntries.count

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(dayCount.formatted()) visits on this date"
        }

        return "\(searchCount.formatted()) of \(dayCount.formatted()) visits match search"
    }

    private var dateRangeText: String {
        guard let oldest = store.oldestVisit, let newest = store.newestVisit else {
            return "No date range loaded"
        }

        return "\(oldest.formatted(date: .abbreviated, time: .omitted)) - \(newest.formatted(date: .abbreviated, time: .omitted))"
    }

    private var calendarSelection: Binding<Date> {
        Binding(
            get: { calendarDate },
            set: { newDate in
                calendarDate = newDate
                isDateFilterActive = true
                selectedEntry = nil
            }
        )
    }

    private func jumpToToday() {
        calendarDate = Date()
        isDateFilterActive = true
        selectedEntry = nil
    }

    private func showAllDates() {
        isDateFilterActive = false
        selectedEntry = nil
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    store.errorMessage = nil
                }
            }
        )
    }
}

private struct HistoryCalendarView: View {
    @Binding var selectedDate: Date

    let entries: [HistoryEntry]
    let oldestDate: Date?
    let newestDate: Date?

    @State private var visibleMonth: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(
        selectedDate: Binding<Date>,
        entries: [HistoryEntry],
        oldestDate: Date?,
        newestDate: Date?
    ) {
        _selectedDate = selectedDate
        self.entries = entries
        self.oldestDate = oldestDate
        self.newestDate = newestDate
        _visibleMonth = State(initialValue: Calendar.current.startOfMonth(for: selectedDate.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .help("Previous month")

                Menu {
                    ForEach(1...12, id: \.self) { month in
                        Button(monthName(month)) {
                            setVisibleMonth(month: month)
                        }
                    }
                } label: {
                    Text(monthName(calendar.component(.month, from: visibleMonth)))
                        .frame(maxWidth: .infinity)
                }
                .menuStyle(.button)
                .frame(minWidth: 118)

                Menu {
                    ForEach(yearRange, id: \.self) { year in
                        Button(year.formatted(.number.grouping(.never))) {
                            setVisibleYear(year)
                        }
                    }
                } label: {
                    Text(calendar.component(.year, from: visibleMonth).formatted(.number.grouping(.never)))
                        .frame(width: 58)
                }
                .menuStyle(.button)

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .help("Next month")
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 18)
                }

                ForEach(calendarDays) { day in
                    Button {
                        selectedDate = day.date
                    } label: {
                        VStack(spacing: 2) {
                            Text(day.dayNumber)
                                .font(.callout)
                                .monospacedDigit()

                            Circle()
                                .fill(day.visitCount > 0 ? Color.accentColor : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(width: 32, height: 34)
                        .foregroundStyle(day.isInVisibleMonth ? Color.primary : Color.secondary.opacity(0.55))
                        .background(dayBackground(day))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help(dayHelp(day))
                }
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            visibleMonth = calendar.startOfMonth(for: newDate)
        }
    }

    private var calendarDays: [HistoryCalendarDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
            let gridInterval = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let endGridInterval = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else {
            return []
        }

        var days: [HistoryCalendarDay] = []
        var date = gridInterval.start
        let endDate = endGridInterval.end
        let visitCounts = visitCountsByDay

        while date < endDate {
            let dayStart = calendar.startOfDay(for: date)
            days.append(
                HistoryCalendarDay(
                    date: dayStart,
                    dayNumber: calendar.component(.day, from: dayStart).formatted(),
                    isInVisibleMonth: calendar.isDate(dayStart, equalTo: visibleMonth, toGranularity: .month),
                    isSelected: calendar.isDate(dayStart, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(dayStart),
                    visitCount: visitCounts[dayStart] ?? 0
                )
            )

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDate
        }

        return days
    }

    private var visitCountsByDay: [Date: Int] {
        Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.visitDate) })
            .mapValues(\.count)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        return Array(symbols[firstIndex...]) + Array(symbols[..<firstIndex])
    }

    private var yearRange: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        let oldestYear = oldestDate.map { calendar.component(.year, from: $0) } ?? currentYear - 10
        let newestYear = newestDate.map { calendar.component(.year, from: $0) } ?? currentYear
        return Array(Array(min(oldestYear, newestYear)...max(oldestYear, newestYear)).reversed())
    }

    private func dayBackground(_ day: HistoryCalendarDay) -> some ShapeStyle {
        if day.isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.28))
        }

        if day.isToday {
            return AnyShapeStyle(Color.accentColor.opacity(0.12))
        }

        return AnyShapeStyle(Color.clear)
    }

    private func dayHelp(_ day: HistoryCalendarDay) -> String {
        let dateText = day.date.formatted(date: .complete, time: .omitted)
        let countText = day.visitCount == 1 ? "1 visit" : "\(day.visitCount.formatted()) visits"
        return "\(dateText), \(countText)"
    }

    private func moveMonth(by value: Int) {
        visibleMonth = calendar.startOfMonth(for: calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth)
    }

    private func setVisibleMonth(month: Int) {
        var components = calendar.dateComponents([.year], from: visibleMonth)
        components.month = month
        components.day = 1
        visibleMonth = calendar.date(from: components) ?? visibleMonth
    }

    private func setVisibleYear(_ year: Int) {
        var components = calendar.dateComponents([.month], from: visibleMonth)
        components.year = year
        components.day = 1
        visibleMonth = calendar.date(from: components) ?? visibleMonth
    }

    private func monthName(_ month: Int) -> String {
        calendar.monthSymbols[month - 1]
    }
}

private struct HistoryCalendarDay: Identifiable {
    let date: Date
    let dayNumber: String
    let isInVisibleMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let visitCount: Int

    var id: Date { date }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}
