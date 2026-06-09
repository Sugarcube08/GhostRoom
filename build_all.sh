#!/bin/bash

# GhostRoom Cross-Platform Build Script
# This script builds for Linux, Android, Web, macOS, and iOS depending on the host OS.

set -e

PROJECT_ROOT=$(pwd)
DIST_DIR="$PROJECT_ROOT/dist"
OS=$(uname -s)

# Read version dynamically
VERSION=$(grep '"version"' "$PROJECT_ROOT/VERSION.json" | head -n 1 | awk -F '"' '{print $4}')
if [ -z "$VERSION" ]; then
    VERSION=$(grep "^version:" "$PROJECT_ROOT/client/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1)
fi
DEB_VERSION="${VERSION//+/-}"
if [ -z "$DEB_VERSION" ]; then
    DEB_VERSION="1.0.0"
fi

echo "🚀 Starting local build for GhostRoom v$VERSION on $OS..."

# 1. Install System Dependencies (Linux only)
if [ "$OS" = "Linux" ]; then
    echo "📦 Checking Linux system dependencies..."
    MISSING_DEPS=()
    for pkg in clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libglu1-mesa-dev libsecret-1-dev libjsoncpp-dev zip tar alien; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            MISSING_DEPS+=("$pkg")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "📦 Installing missing system dependencies: ${MISSING_DEPS[*]}..."
        sudo apt-get update
        sudo apt-get install -y "${MISSING_DEPS[@]}"
    else
        echo "✅ All system dependencies are already installed."
    fi
fi

# 2. Get Flutter Dependencies
echo "📥 Getting Flutter packages..."
cd "$PROJECT_ROOT/client"
flutter pub get

# 3. Build Web
echo "🌐 Building Web..."
flutter build web --release

# 4. Build Linux (Linux only)
if [ "$OS" = "Linux" ]; then
    echo "🐧 Building Linux..."
    flutter build linux --release
fi

# 5. Build Android (Requires Android SDK)
echo "🤖 Building Android APK..."
if command -v flutter &> /dev/null && { [ -d "$ANDROID_HOME" ] || [ -d "$HOME/Android/Sdk" ] || [ -d "$HOME/Library/Android/sdk" ]; }; then
    flutter build apk --release
else
    echo "⚠️ Android SDK not found. Skipping Android build."
fi

# 6. Build macOS & iOS (macOS only)
if [ "$OS" = "Darwin" ]; then
    echo "🍎 Building macOS..."
    flutter build macos --release
    
    echo "📱 Building iOS..."
    flutter build ipa --release || echo "⚠️ iOS build failed. Note: iOS builds require a valid code signing setup in Xcode."
fi

# 7. Package Artifacts
echo "📦 Packaging artifacts..."
mkdir -p "$DIST_DIR"

# Web
echo "📦 Packaging Web..."
(cd build/web && zip -r "$DIST_DIR/ghostroom-web.zip" .) > /dev/null

# Linux Packages
if [ "$OS" = "Linux" ]; then
    echo "📦 Packaging Linux (tar.gz)..."
    (cd build/linux/x64/release/bundle && tar -czvf "$DIST_DIR/ghostroom-linux.tar.gz" .) > /dev/null

    echo "📦 Packaging Linux (.deb)..."
    if command -v dpkg-deb &> /dev/null; then
        DEB_DIR="build/linux/deb/ghostroom_${DEB_VERSION}_amd64"
        mkdir -p "$DEB_DIR/DEBIAN" "$DEB_DIR/usr/bin" "$DEB_DIR/opt/ghostroom" "$DEB_DIR/usr/share/applications" "$DEB_DIR/usr/share/icons/hicolor/512x512/apps"
        cp -r build/linux/x64/release/bundle/* "$DEB_DIR/opt/ghostroom/"
        ln -sf /opt/ghostroom/ghostroom "$DEB_DIR/usr/bin/ghostroom"
        
        cat <<CTRL > "$DEB_DIR/DEBIAN/control"
Package: ghostroom
Version: ${DEB_VERSION}
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libsecret-1-0
Maintainer: GhostRoom Team
Description: Privacy-First Ephemeral Communication
CTRL

        cat <<DESK > "$DEB_DIR/usr/share/applications/ghostroom.desktop"
[Desktop Entry]
Version=1.0
Name=GhostRoom
GenericName=GhostRoom
Comment=Privacy-First Ephemeral Communication
Terminal=false
Type=Application
Categories=Network;Chat;
Exec=/opt/ghostroom/ghostroom
Icon=ghostroom
DESK
        
        cp web/icons/Icon-512.png "$DEB_DIR/usr/share/icons/hicolor/512x512/apps/ghostroom.png"
        dpkg-deb --build "$DEB_DIR" "$DIST_DIR/ghostroom-linux.deb" > /dev/null
        echo "✅ Debian package created."
    else
        echo "⚠️ dpkg-deb not found. Skipping .deb creation."
    fi

    echo "📦 Packaging Linux (.rpm)..."
    if command -v alien &> /dev/null; then
        (cd "$DIST_DIR" && sudo alien -r ghostroom-linux.deb || echo "⚠️ RPM creation failed") > /dev/null
        echo "✅ RPM package created."
    else
        echo "⚠️ alien not found. Skipping .rpm creation. (Run: sudo apt install alien)"
    fi

    echo "📦 Packaging Linux (.AppImage)..."
    APPIMAGE_TOOL="$PROJECT_ROOT/appimagetool-x86_64.AppImage"
    if [ ! -f "$APPIMAGE_TOOL" ]; then
        echo "📥 Downloading appimagetool..."
        wget -qO "$APPIMAGE_TOOL" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "$APPIMAGE_TOOL"
    fi
    
    APPDIR="build/linux/AppDir"
    mkdir -p "$APPDIR"
    cp -r build/linux/x64/release/bundle/* "$APPDIR/"
    
    # AppImage metadata
    cp "$DEB_DIR/usr/share/applications/ghostroom.desktop" "$APPDIR/"
    cp "$DEB_DIR/usr/share/icons/hicolor/512x512/apps/ghostroom.png" "$APPDIR/"
    
    cat <<APP > "$APPDIR/AppRun"
#!/bin/sh
HERE="\$(dirname "\$(readlink -f "\${0}")")"
export LD_LIBRARY_PATH="\${HERE}/lib:\${LD_LIBRARY_PATH}"
exec "\${HERE}/ghostroom" "\$@"
APP
    chmod +x "$APPDIR/AppRun"
    
    # We use --appimage-extract-and-run because many FUSE environments (like Docker/WSL) 
    # don't support mounting AppImages directly
    ARCH=x86_64 "$APPIMAGE_TOOL" --appimage-extract-and-run "$APPDIR" "$DIST_DIR/ghostroom-linux.AppImage" > /dev/null 2>&1 || \
    ARCH=x86_64 "$APPIMAGE_TOOL" "$APPDIR" "$DIST_DIR/ghostroom-linux.AppImage" > /dev/null 2>&1 || {
        echo "⚠️ AppImage creation failed. Retrying without output suppression to show errors:"
        ARCH=x86_64 "$APPIMAGE_TOOL" --appimage-extract-and-run "$APPDIR" "$DIST_DIR/ghostroom-linux.AppImage"
    }
    
    if [ -f "$DIST_DIR/ghostroom-linux.AppImage" ]; then
        echo "✅ AppImage created."
    fi
fi

# Android
echo "📦 Packaging Android (.apk)..."
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    cp "$APK_PATH" "$DIST_DIR/ghostroom-android.apk"
    echo "✅ Android APK copied to dist/"
fi

# macOS & iOS
if [ "$OS" = "Darwin" ]; then
    echo "📦 Packaging macOS (.zip)..."
    if [ -d "build/macos/Build/Products/Release/ghostroom.app" ]; then
        (cd build/macos/Build/Products/Release && zip -r "$DIST_DIR/ghostroom-macos.zip" ghostroom.app) > /dev/null
        echo "✅ macOS App copied to dist/"
    fi
    
    echo "📦 Packaging iOS (.ipa)..."
    if ls build/ios/ipa/*.ipa 1> /dev/null 2>&1; then
        cp build/ios/ipa/*.ipa "$DIST_DIR/ghostroom-ios.ipa"
        echo "✅ iOS IPA copied to dist/"
    fi
fi

echo "✅ Builds complete! Artifacts generated in the 'dist' folder:"
ls -lh "$DIST_DIR"