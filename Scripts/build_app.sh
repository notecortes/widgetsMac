#!/bin/bash
set -e

echo "🚀 Building Pulse Monitor for macOS 27.2 / 26+..."

# 0. Clean extended attributes to avoid codesign detritus issues
xattr -cr . 2>/dev/null || true

# Determine signing identity
SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | awk '{print $2}' || true)
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="-"
    echo "ℹ️ Using ad-hoc signing (-)"
else
    echo "🔑 Using signing identity: $SIGN_IDENTITY"
fi

# 1. Compile in Release mode via xcodebuild if project exists, or swift build
mkdir -p build
if [ -f "PulseMonitor.xcodeproj/project.pbxproj" ]; then
    echo "🔨 Building with xcodebuild (Release)..."
    xcodebuild -scheme PulseMonitor -configuration Release -destination 'platform=macOS' build >/dev/null
    XCODE_APP="/Users/paspas/Library/Developer/Xcode/DerivedData/PulseMonitor-dnqzioqcggbcppfwyhocrylbjuqp/Build/Products/Release/PulseMonitor.app"
    rm -rf build/PulseMonitor.app
    cp -R "$XCODE_APP" build/PulseMonitor.app
else
    echo "🔨 Building with swift build (Release)..."
    swift build -c release
    BIN_DIR="$(swift build -c release --show-bin-path)"
    APP_DIR="build/PulseMonitor.app"
    CONTENTS="$APP_DIR/Contents"
    MACOS="$CONTENTS/MacOS"
    RESOURCES="$CONTENTS/Resources"
    PLUGINS="$CONTENTS/PlugIns"
    APPEX="$PLUGINS/PulseWidgets.appex"
    APPEX_CONTENTS="$APPEX/Contents"
    APPEX_MACOS="$APPEX_CONTENTS/MacOS"

    rm -rf "$APP_DIR"
    mkdir -p "$MACOS" "$RESOURCES" "$APPEX_MACOS"

    cp "$BIN_DIR/PulseMonitor" "$MACOS/"
    chmod +x "$MACOS/PulseMonitor"
    cp "Sources/PulseMonitor/Resources/Info.plist" "$CONTENTS/"
    cp "Sources/PulseMonitor/Resources/AppIcon.icns" "$RESOURCES/" 2>/dev/null || true
    cp -R Sources/PulseMonitor/Resources/*.lproj "$RESOURCES/" 2>/dev/null || true

    if [ -f "$BIN_DIR/PulseWidgets" ]; then
        cp "$BIN_DIR/PulseWidgets" "$APPEX_MACOS/PulseWidgets"
        chmod +x "$APPEX_MACOS/PulseWidgets"
    fi
    cp "Sources/PulseWidgets/Resources/Info.plist" "$APPEX_CONTENTS/"

    xattr -cr "$APP_DIR" 2>/dev/null || true

    codesign --force --sign "$SIGN_IDENTITY" --entitlements "Sources/PulseWidgets/Resources/PulseWidgets.entitlements" "$APPEX"
    codesign --force --sign "$SIGN_IDENTITY" --entitlements "Sources/PulseMonitor/Resources/PulseMonitor.entitlements" "$APP_DIR"
fi

echo "✅ Pulse Monitor successfully built and bundled at build/PulseMonitor.app"
