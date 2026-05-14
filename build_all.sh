#!/bin/bash

# GhostRoom Local Build Script for Pop!_OS (Ubuntu-based)
# This script builds for Android, Linux, and Web.

set -e

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
cd client
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
mkdir -p ../dist

# Web
cd build/web && zip -r ../../../dist/ghostroom-web.zip . && cd ../..
# Linux
cd build/linux/x64/release/bundle && tar -czvf ../../../../../../dist/ghostroom-linux.tar.gz . && cd ../../../../../..
# Android
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp build/app/outputs/flutter-apk/app-release.apk ../dist/ghostroom-android.apk
fi

echo "✅ Local builds complete! Artifacts are in the 'dist' folder."
echo "⚠️ Note: iOS, macOS, and Windows builds still require their respective native environments."
