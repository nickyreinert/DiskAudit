# DISK AUDIT

## Prerequisites
- macOS 13 or newer
- Xcode Command Line Tools (Swift 5.9+)

## Build (CLI)
- Run in the project root: `swift build -c release`
- Output binary: `.build/release/DiskAuditApp`

## Deploy (Local .app Bundle)
- Run script: `./Scripts/build_app.sh`
- Result: `$HOME/Applications/DISK AUDIT.app`
- The script creates/updates `Info.plist`, copies the release binary, sets permissions, and includes the app icon.

## Launch
- Open the app in Finder under `~/Applications`
- Or launch directly: `open "$HOME/Applications/DISK AUDIT.app"`
