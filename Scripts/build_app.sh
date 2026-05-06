#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DISK AUDIT"
APP_BUNDLE="$HOME/Applications/${APP_NAME}.app"
BIN_NAME="DiskAuditApp"

cd "$ROOT_DIR"
swift build -c release

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>DISK AUDIT</string>
  <key>CFBundleDisplayName</key>
  <string>DISK AUDIT</string>
  <key>CFBundleIdentifier</key>
  <string>local.nicky.diskaudit</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>DiskAuditApp</string>
  <key>CFBundleIconFile</key>
  <string>icon</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
</dict>
</plist>
PLIST

cp "$ROOT_DIR/.build/release/$BIN_NAME" "$APP_BUNDLE/Contents/MacOS/$BIN_NAME"
cp "$ROOT_DIR/icon.icns" "$APP_BUNDLE/Contents/Resources/icon.icns"
chmod +x "$APP_BUNDLE/Contents/MacOS/$BIN_NAME"

echo "Created app bundle at: $APP_BUNDLE"
open -R "$APP_BUNDLE"
