#!/bin/bash

# GhostRoom Multi-Platform Ultimate Build Script (V2.0.1)
# Generates all formats: AppImage, DEB, RPM, Tar.xz, APK (Fat), IPA, DMG, PKG, and Checksums.

set -e

# Detect Version from pubspec.yaml
VERSION=$(grep '^version: ' client/pubspec.yaml | sed 's/version: //;s/+[0-9]*//' | tr -d ' ' | tr -d '\r')
echo "📦 Detected Version: $VERSION"

PROJECT_ROOT=$(pwd)
DIST_DIR="$PROJECT_ROOT/dist"
CLIENT_DIR="$PROJECT_ROOT/client"
OS=$(uname -s)
ARCH=$(uname -m)

# Map uname arch to Flutter/Distribution labels
if [ "$ARCH" = "x86_64" ]; then
    FLUTTER_ARCH="x64"
    ARCH_LABEL="x86_64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    FLUTTER_ARCH="arm64"
    ARCH_LABEL="aarch64"
else
    FLUTTER_ARCH="$ARCH"
    ARCH_LABEL="$ARCH"
fi

echo "🚀 Starting GhostRoom $VERSION distribution build on $OS ($ARCH)..."

# 1. Prepare Environment
mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR"/*
rm -rf "$PROJECT_ROOT/build"
rm -rf "$PROJECT_ROOT/client/build"

# 2. Linux Dependencies
if [ "$OS" = "Linux" ]; then
    echo "📦 Installing Linux build tools..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        clang cmake ninja-build pkg-config \
        libgtk-3-dev liblzma-dev libstdc++-14-dev \
        libglu1-mesa-dev libsecret-1-dev libjsoncpp-dev \
        zip tar alien wget xz-utils
fi

# 3. Flutter Build
cd "$CLIENT_DIR"
echo "📥 Fetching Flutter dependencies..."
flutter pub get

# --- BUILD: WEB ---
echo "🌐 Building Web..."
flutter build web --release

# --- BUILD: ANDROID ---
echo "🤖 Building Android (Fat APK & Bundle)..."
if command -v flutter &> /dev/null; then
    # Fat APK (All Arch)
    flutter build apk --release --target-platform android-arm,android-arm64,android-x64
    cp build/app/outputs/flutter-apk/app-release.apk "$DIST_DIR/GhostRoom-android-all-arch.apk"
    
    # App Bundle
    flutter build appbundle --release
    cp build/app/outputs/bundle/release/app-release.aab "$DIST_DIR/GhostRoom-android.aab"
fi

# --- BUILD: LINUX ---
if [ "$OS" = "Linux" ]; then
    echo "🐧 Building Linux ($ARCH_LABEL)..."
    flutter build linux --release
    LINUX_BUNDLE="build/linux/$FLUTTER_ARCH/release/bundle"
    
    # 1. Tar.xz (spotube-linux-5.1.2-x86_64.tar.xz style)
    echo "   -> Creating tar.xz..."
    (cd "$LINUX_BUNDLE" && tar -cJf "$DIST_DIR/ghostroom-linux-$VERSION-$ARCH_LABEL.tar.xz" .)
    
    # 2. Debian (.deb) (Spotube-linux-x86_64.deb style)
    echo "   -> Creating .deb..."
    DEB_ARCH="amd64"
    [ "$ARCH_LABEL" = "aarch64" ] && DEB_ARCH="arm64"
    DEB_DIR="build/linux/deb/ghostroom_${VERSION}_$DEB_ARCH"
    mkdir -p "$DEB_DIR/DEBIAN" "$DEB_DIR/usr/bin" "$DEB_DIR/opt/ghostroom" "$DEB_DIR/usr/share/applications" "$DEB_DIR/usr/share/icons/hicolor/512x512/apps"
    cp -r "$LINUX_BUNDLE"/* "$DEB_DIR/opt/ghostroom/"
    ln -sf /opt/ghostroom/ghostroom "$DEB_DIR/usr/bin/ghostroom"
    
    cat <<CTRL > "$DEB_DIR/DEBIAN/control"
Package: ghostroom
Version: $VERSION
Section: utils
Priority: optional
Architecture: $DEB_ARCH
Depends: libgtk-3-0, libsecret-1-0
Maintainer: GhostRoom Team <https://github.com/Sugarcube08/GhostRoom>
Description: GhostRoom - Privacy-First Ephemeral Messenger
CTRL

    cat <<DESK > "$DEB_DIR/usr/share/applications/ghostroom.desktop"
[Desktop Entry]
Version=1.0
Name=GhostRoom
Comment=Privacy-First Ephemeral Messenger
Terminal=false
Type=Application
Categories=Network;Chat;
Exec=/opt/ghostroom/ghostroom
Icon=ghostroom
DESK
    
    [ -f "web/icons/Icon-512.png" ] && cp web/icons/Icon-512.png "$DEB_DIR/usr/share/icons/hicolor/512x512/apps/ghostroom.png"
    dpkg-deb --build "$DEB_DIR" "$DIST_DIR/GhostRoom-linux-$ARCH_LABEL.deb" > /dev/null
    
    # 3. RPM (via alien)
    echo "   -> Creating .rpm..."
    if command -v alien &> /dev/null; then
        (cd "$DIST_DIR" && sudo alien -r --to-rpm "GhostRoom-linux-$ARCH_LABEL.deb" && mv *.rpm "GhostRoom-linux-$ARCH_LABEL.rpm" && sudo chown $(id -u):$(id -g) "GhostRoom-linux-$ARCH_LABEL.rpm") > /dev/null 2>&1 || true
    fi

    # 4. AppImage (Spotube-linux-x86_64.AppImage style)
    echo "   -> Creating .AppImage..."
    APPIMAGE_TOOL="$PROJECT_ROOT/appimagetool-$ARCH_LABEL.AppImage"
    
    # Official AppImageTool releases use x86_64 and aarch64
    if [ ! -f "$APPIMAGE_TOOL" ] || [ ! -s "$APPIMAGE_TOOL" ]; then
        echo "      -> Downloading appimagetool for $ARCH_LABEL..."
        wget -qO "$APPIMAGE_TOOL" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$ARCH_LABEL.AppImage" || \
        wget -qO "$APPIMAGE_TOOL" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" # Fallback
        chmod +x "$APPIMAGE_TOOL"
    fi
    
    # Extract appimagetool to avoid FUSE issues (Critical for many environments)
    rm -rf "$PROJECT_ROOT/squashfs-root"
    (cd "$PROJECT_ROOT" && ./"$(basename "$APPIMAGE_TOOL")" --appimage-extract) > /dev/null
    
    APPDIR="$PROJECT_ROOT/build/linux/AppDir"
    rm -rf "$APPDIR"
    mkdir -p "$APPDIR/usr/bin"
    mkdir -p "$APPDIR/usr/share/applications"
    mkdir -p "$APPDIR/usr/share/icons/hicolor/512x512/apps"
    
    # Copy bundle contents
    cp -r "$LINUX_BUNDLE"/* "$APPDIR/"
    
    # Move binary to usr/bin as expected by some tools
    cp "$LINUX_BUNDLE/ghostroom" "$APPDIR/usr/bin/ghostroom"
    
    # Setup Desktop file and Icon in root (Required for appimagetool)
    cp "$DEB_DIR/usr/share/applications/ghostroom.desktop" "$APPDIR/ghostroom.desktop"
    [ -f "web/icons/Icon-512.png" ] && cp web/icons/Icon-512.png "$APPDIR/ghostroom.png"
    
    # Create AppRun script
    cat <<APP > "$APPDIR/AppRun"
#!/bin/sh
HERE="\$(dirname "\$(readlink -f "\${0}")")"
export LD_LIBRARY_PATH="\${HERE}/lib:\${LD_LIBRARY_PATH}"
exec "\${HERE}/ghostroom" "\$@"
APP
    chmod +x "$APPDIR/AppRun"
    
    # Build AppImage using extracted tool (Absolute paths)
    echo "      -> Running appimagetool..."
    export ARCH=$ARCH_LABEL
    "$PROJECT_ROOT/squashfs-root/AppRun" "$APPDIR" "$DIST_DIR/GhostRoom-linux-$ARCH_LABEL.AppImage"
    
    # Cleanup
    rm -rf "$PROJECT_ROOT/squashfs-root"
fi

# --- BUILD: macOS & iOS ---
if [ "$OS" = "Darwin" ]; then
    echo "🍎 Building macOS & iOS..."
    flutter build macos --release
    flutter build ipa --release
    
    # DMG
    echo "   -> Creating .dmg..."
    if command -v hdiutil &> /dev/null; then
        hdiutil create -volname GhostRoom -srcfolder build/macos/Build/Products/Release/ghostroom.app -ov -format UDZO "$DIST_DIR/GhostRoom-macos-universal.dmg" > /dev/null
    fi
    
    # IPA
    cp build/ios/ipa/*.ipa "$DIST_DIR/GhostRoom-iOS.ipa"
fi

# --- BUILD: Windows ---
if [[ "$OS" == *"NT"* ]] || [[ "$OS" == *"MINGW"* ]]; then
    echo "🪟 Building Windows..."
    flutter build windows --release
    # Note: Full .exe setup typically requires Inno Setup or NSIS. 
    # For now, we zip the runner.
    (cd build/windows/x64/release/runner && zip -r "$DIST_DIR/GhostRoom-windows-x86_64.zip" .)
fi

# 9. Source Code Packaging
echo "📦 Packaging source code..."
cd "$PROJECT_ROOT"
git archive --format=zip HEAD -o "$DIST_DIR/Source-code.zip"
git archive --format=tar.gz HEAD -o "$DIST_DIR/Source-code.tar.gz"

# 10. Checksums
echo "🛡️ Generating checksums..."
cd "$DIST_DIR"
# Generate for all files excluding the checksum files themselves
find . -type f ! -name "RELEASE.*" -exec md5sum {} + > RELEASE.md5sum
find . -type f ! -name "RELEASE.*" -exec sha256sum {} + > RELEASE.sha256sum

echo "✅ Distribution build complete! Artifacts in 'dist/':"
ls -lh "$DIST_DIR"
