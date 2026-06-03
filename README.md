# History Browser

History Browser is a small macOS SwiftUI app that reads Safari's local
`History.db` SQLite database and shows every visit in the file, including visits
older than Safari's History menu/view cutoff.

Safari stores history at:

```text
~/Library/Safari/History.db
```

The app copies `History.db` plus its `-wal` and `-shm` sidecar files into a
temporary directory before querying them. It never writes to Safari's live
database.

## Build

Open `HistoryBrowser.xcodeproj` in Xcode and build the `HistoryBrowser` scheme.

You can also build from the command line:

```bash
xcodebuild \
  -project HistoryBrowser.xcodeproj \
  -scheme HistoryBrowser \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

To create a local app bundle in `dist/`, run:

```bash
./scripts/build_app.sh
```

The app bundle is created at:

```text
dist/HistoryBrowser.app
```

## Run

Open `dist/HistoryBrowser.app`.

On recent macOS versions, access to `~/Library/Safari/History.db` is protected
by macOS privacy controls. History Browser cannot bypass that protection; it
needs one of these user-granted access paths.

### Option 1: Grant the Safari folder

Use **Grant Safari Folder** in the app and select:

```text
~/Library/Safari
```

This is the narrowest useful permission because it lets the app read
`History.db`, `History.db-wal`, and `History.db-shm` together. The app stores a
security-scoped bookmark so it can try to reuse that folder permission on later
launches.

### Option 2: Full Disk Access

1. Open System Settings.
2. Go to Privacy & Security > Full Disk Access.
3. Add History Browser, Terminal, or your IDE depending on how you launch it.
4. Restart the app.

Full Disk Access is broader than the app needs, but it is the most reliable way
to let a local macOS app read Safari's protected history database without file
picker prompts.

You can also use **Access > Choose History.db Copy** in the app to select a
copied standalone database manually.

## Icon

The app icon lives in:

```text
Sources/HistoryBrowser/Assets.xcassets/AppIcon.appiconset
```

Regenerate it with:

```bash
swift scripts/generate_icon.swift
```

## GitHub

The repository includes a shared Xcode scheme and a GitHub Actions workflow that
builds the app on `macos-latest`.

## License

MIT
