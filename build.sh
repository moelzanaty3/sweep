#!/bin/bash
set -euo pipefail

APP_NAME="Sweep"
BUNDLE_ID="com.elzanaty.sweep"
VERSION="1.0.2" # x-release-please-version
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

if [[ -n "${DEVELOPER_ID:-}" ]]; then
    echo "==> Signing with $DEVELOPER_ID"
    # Hardened runtime is a precondition for notarization. It does not restrict
    # Process spawning, so the du/find/rm/git shell-outs keep working.
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP_DIR"
else
    echo "==> Signing (ad-hoc — set DEVELOPER_ID to sign for distribution)"
    codesign --force --sign - "$APP_DIR" 2>/dev/null || echo "   ad-hoc signing skipped"
fi

echo "==> Built $APP_DIR"

make_dmg() {
    DMG="$ROOT/dist/$APP_NAME-$VERSION.dmg"
    echo "==> Building DMG"
    rm -f "$DMG"
    STAGE="$ROOT/.build/dmg"
    rm -rf "$STAGE" && mkdir -p "$STAGE"
    cp -R "$APP_DIR" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
    echo "==> Built $DMG"
}

case "${1:-}" in
install)
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_DIR" /Applications/
    echo "==> Installed to /Applications/$APP_NAME.app"
    ;;
dmg)
    make_dmg
    shasum -a 256 "$DMG"
    ;;
notarize)
    : "${DEVELOPER_ID:?set DEVELOPER_ID to your \"Developer ID Application: NAME (TEAMID)\" identity}"
    : "${NOTARY_PROFILE:=sweep}"

    ZIP="$ROOT/dist/$APP_NAME-$VERSION.zip"

    echo "==> Submitting app to Apple notary service"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_DIR"

    make_dmg

    # The DMG is a separate artifact and needs its own signature, ticket and staple,
    # or Gatekeeper flags the download even though the app inside is notarized.
    codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"

    echo "==> Verifying"
    spctl -a -vvv -t install "$APP_DIR"
    shasum -a 256 "$DMG"
    ;;
esac
