#!/bin/bash
set -euo pipefail

APP_NAME="Sweep"
BUNDLE_ID="com.elzanaty.sweep"
VERSION="1.0.0"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/.build/release"
APP_DIR="$ROOT/dist/$APP_NAME.app"

echo "==> Building release binary"
swift build -c release --package-path "$ROOT"

echo "==> Assembling bundle"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/MacCleaner" "$APP_DIR/Contents/MacOS/$APP_NAME"

echo "==> Generating icon"
ICONSET="$ROOT/.build/AppIcon.iconset"
rm -rf "$ICONSET"
swift "$ROOT/Resources/makeicon.swift" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>NSDesktopFolderUsageDescription</key><string>Sweep scans your Desktop for build artifacts and large files.</string>
    <key>NSDocumentsFolderUsageDescription</key><string>Sweep scans Documents for build artifacts and large files.</string>
    <key>NSDownloadsFolderUsageDescription</key><string>Sweep scans Downloads for stale installers and large files.</string>
</dict>
</plist>
PLIST

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "   ad-hoc signing skipped"

echo "==> Built $APP_DIR"

if [[ "${1:-}" == "install" ]]; then
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_DIR" /Applications/
    echo "==> Installed to /Applications/$APP_NAME.app"
fi
