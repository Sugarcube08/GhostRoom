#!/bin/bash

# GhostRoom Local Build Script for Pop!_OS (Ubuntu-based)
# This script builds for Android, Linux, and Web.

set -e

PROJECT_ROOT=$(pwd)
DIST_DIR="$PROJECT_ROOT/dist"

echo "🚀 Starting local build for GhostRoom..."

# 1. Install System Dependencies
echo "📦 Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-14-dev \
    libglu1-mesa-dev libsecret-1-dev libjsoncpp-dev \
    zip tar

# 2. Get Flutter Dependencies
echo "📥 Getting Flutter packages..."
cd "$PROJECT_ROOT/client"
flutter pub get

# 3. Build Web
echo "🌐 Building Web..."
flutter build web --release

# 4. Build Linux
echo "🐧 Building Linux..."
flutter build linux --release

# 5. Build Android (Requires Android SDK)
echo "🤖 Building Android APK..."
if command -v flutter &> /dev/null && [ -d "$ANDROID_HOME" ] || [ -d "$HOME/Android/Sdk" ]; then
    flutter build apk --release
else
    echo "⚠️ Android SDK not found. Skipping Android build."
    echo "   Please set ANDROID_HOME or install Android Studio."
fi

# 6. Package Artifacts
echo "📦 Packaging artifacts..."
mkdir -p "$DIST_DIR"

# Web
echo "📦 Packaging Web..."
(cd build/web && zip -r "$DIST_DIR/ghostroom-web.zip" .)

# Linux
echo "📦 Packaging Linux..."
(cd build/linux/x64/release/bundle && tar -czvf "$DIST_DIR/ghostroom-linux.tar.gz" .)

# Android
echo "📦 Packaging Android..."
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    cp "$APK_PATH" "$DIST_DIR/ghostroom-android.apk"
    echo "✅ Android APK copied to dist/"
else
    echo "⚠️ Android APK not found at $APK_PATH"
fi

echo "✅ Local builds complete! Artifacts are in the 'dist' folder:"
ls -lh "$DIST_DIR"
echo "⚠️ Note: iOS, macOS, and Windows builds still require their respective native environments."
