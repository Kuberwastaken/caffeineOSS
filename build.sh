#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="CaffeineOSS.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"

echo "Compiling…"
swiftc -O main.swift -o "$BIN_DIR/CaffeineOSS"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>CaffeineOSS</string>
  <key>CFBundleDisplayName</key>     <string>CaffeineOSS</string>
  <key>CFBundleIdentifier</key>      <string>local.caffeineoss</string>
  <key>CFBundleVersion</key>         <string>1.0</string>
  <key>CFBundleShortVersionString</key> <string>1.0</string>
  <key>CFBundlePackageType</key>     <string>APPL</string>
  <key>CFBundleExecutable</key>      <string>CaffeineOSS</string>
  <key>LSUIElement</key>            <true/>
  <key>LSMinimumSystemVersion</key>  <string>13.0</string>
</dict>
</plist>
PLIST

echo "Ad-hoc signing…"
codesign --force --deep --sign - "$APP"

echo "Built: $(pwd)/$APP"
