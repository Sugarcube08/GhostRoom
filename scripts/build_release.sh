#!/usr/bin/env bash

# ==============================================================================
# GhostRoom Release Build & Asset Packaging Script
# Builds release assets, moves to release/, calculates SHA256, and builds version.json
# ==============================================================================

set -euo pipefail

# Determine Project Root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RELEASE_DIR="${PROJECT_ROOT}/release"
CLIENT_DIR="${PROJECT_ROOT}/client"

cd "${PROJECT_ROOT}"

echo "========================================================"
echo "  GhostRoom Automated Release Asset Builder"
echo "========================================================"

# Configure JDK compatible with Android Gradle Plugin (prefer JDK 17 / 21 over JDK 26)
if [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
elif [ -d "/usr/lib/jvm/java-1.17.0-openjdk-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-1.17.0-openjdk-amd64"
elif [ -d "/usr/lib/jvm/java-1.21.0-openjdk-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-1.21.0-openjdk-amd64"
fi

if [ -n "${JAVA_HOME:-}" ]; then
    export PATH="${JAVA_HOME}/bin:${PATH}"
    echo "☕ Configured JAVA_HOME: ${JAVA_HOME}"
fi

# 1. Determine Target Version
TARGET_VERSION="${1:-}"
if [ -z "${TARGET_VERSION}" ]; then
    TARGET_VERSION=$(grep "^version:" "${CLIENT_DIR}/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1 | tr -d '[:space:]')
fi

if [ -z "${TARGET_VERSION}" ]; then
    TARGET_VERSION="2.2.3"
fi

# Clean version (no 'v' prefix)
TARGET_VERSION="${TARGET_VERSION#v}"

echo "📌 Target Release Version: v${TARGET_VERSION}"

# Update pubspec.yaml version if specified explicitly
if [ -n "${1:-}" ]; then
    CURRENT_BUILD=$(grep "^version:" "${CLIENT_DIR}/pubspec.yaml" | cut -d'+' -f2 | tr -d '[:space:]')
    if [ -z "${CURRENT_BUILD}" ] || [ "${CURRENT_BUILD}" = "${TARGET_VERSION}" ]; then
        CURRENT_BUILD="1"
    fi
    NEW_BUILD=$((CURRENT_BUILD + 1))
    sed -i "s/^version: .*/version: ${TARGET_VERSION}+${NEW_BUILD}/" "${CLIENT_DIR}/pubspec.yaml"
    echo "📝 Updated client/pubspec.yaml to version: ${TARGET_VERSION}+${NEW_BUILD}"
fi

# 2. Prepare release directory
mkdir -p "${RELEASE_DIR}"
rm -f "${RELEASE_DIR}"/*.apk "${RELEASE_DIR}"/*.zip "${RELEASE_DIR}"/*.tar.gz "${RELEASE_DIR}"/*.AppImage "${RELEASE_DIR}"/*.deb "${RELEASE_DIR}"/SHA256SUMS 2>/dev/null || true

# 3. Build Client Dependencies
echo ""
echo "📦 Resolving Flutter dependencies..."
cd "${CLIENT_DIR}"
flutter pub get

# 4. Build Android Release APK
echo ""
echo "🤖 Building Android Release APK..."
if flutter build apk --release; then
    APK_SOURCE="${CLIENT_DIR}/build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "${APK_SOURCE}" ]; then
        cp "${APK_SOURCE}" "${RELEASE_DIR}/ghostroom-android.apk"
        echo "✅ Created: ${RELEASE_DIR}/ghostroom-android.apk"
    else
        echo "⚠️ app-release.apk not found at ${APK_SOURCE}"
    fi
else
    echo "⚠️ Android build skipped or failed."
fi

# 5. Build Web Release
echo ""
echo "🌐 Building Web Release..."
if flutter build web --release; then
    WEB_DIR="${CLIENT_DIR}/build/web"
    if [ -d "${WEB_DIR}" ]; then
        (cd "${WEB_DIR}" && zip -rq "${RELEASE_DIR}/ghostroom-web.zip" .)
        echo "✅ Created: ${RELEASE_DIR}/ghostroom-web.zip"
    fi
else
    echo "⚠️ Web build skipped or failed."
fi

# 6. Build Linux (if supported on this host)
OS="$(uname -s)"
if [ "${OS}" = "Linux" ]; then
    echo ""
    echo "🐧 Checking Linux desktop build..."
    if flutter build linux --release 2>/dev/null; then
        LINUX_BUNDLE="${CLIENT_DIR}/build/linux/x64/release/bundle"
        if [ -d "${LINUX_BUNDLE}" ]; then
            (cd "${LINUX_BUNDLE}" && tar -czf "${RELEASE_DIR}/ghostroom-linux-x86_64.tar.gz" .)
            echo "✅ Created: ${RELEASE_DIR}/ghostroom-linux-x86_64.tar.gz"
        fi
    else
        echo "ℹ️ Linux desktop native compiler (clang/gtk3) not configured on host. Skipping Linux native bundle."
    fi
fi

# 7. Compute SHA-256 Checksums
echo ""
echo "🔒 Calculating SHA256 checksums..."
cd "${RELEASE_DIR}"
rm -f SHA256SUMS

for file in *; do
    if [ -f "${file}" ] && [ "${file}" != "version.json" ] && [ "${file}" != "SHA256SUMS" ]; then
        sha256sum "${file}" >> SHA256SUMS
    fi
done

if [ -f SHA256SUMS ]; then
    cat SHA256SUMS
fi

# 8. Auto-build version.json using Python
echo ""
echo "📄 Generating release/version.json..."

python3 - <<EOF
import os
import json
import hashlib
from datetime import datetime, timezone

release_dir = "${RELEASE_DIR}"
version = "${TARGET_VERSION}"
tag = f"v{version}"
release_base_url = f"https://github.com/Sugarcube08/GhostRoom/releases/download/{tag}"
page_url = f"https://github.com/Sugarcube08/GhostRoom/releases/tag/{tag}"

platforms = {}

def get_file_info(filename):
    path = os.path.join(release_dir, filename)
    if not os.path.isfile(path):
        return None
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return {
        "url": f"{release_base_url}/{filename}",
        "filename": filename,
        "sha256": h.hexdigest(),
        "size_bytes": os.path.getsize(path)
    }

# Android
android_info = get_file_info("ghostroom-android.apk")
if android_info:
    platforms["android"] = android_info
else:
    # Default fallback entry
    platforms["android"] = {
        "url": f"{release_base_url}/ghostroom-android.apk",
        "filename": "ghostroom-android.apk",
        "sha256": "",
        "size_bytes": 0
    }

# Linux
linux_appimage = get_file_info("ghostroom-linux-x86_64.AppImage")
linux_tar = get_file_info("ghostroom-linux-x86_64.tar.gz")
if linux_appimage:
    platforms["linux"] = linux_appimage
elif linux_tar:
    platforms["linux"] = linux_tar
else:
    platforms["linux"] = {
        "url": f"{release_base_url}/ghostroom-linux-x86_64.AppImage",
        "filename": "ghostroom-linux-x86_64.AppImage",
        "sha256": "",
        "size_bytes": 0
    }

# Windows fallback
windows_info = get_file_info("ghostroom-windows-x64.zip")
if windows_info:
    platforms["windows"] = windows_info
else:
    platforms["windows"] = {
        "url": f"{release_base_url}/ghostroom-windows-x64.zip",
        "filename": "ghostroom-windows-x64.zip",
        "sha256": "",
        "size_bytes": 0
    }

# macOS fallback
macos_info = get_file_info("ghostroom-macos.zip")
if macos_info:
    platforms["macos"] = macos_info
else:
    platforms["macos"] = {
        "url": f"{release_base_url}/ghostroom-macos.zip",
        "filename": "ghostroom-macos.zip",
        "sha256": "",
        "size_bytes": 0
    }

# Web
web_info = get_file_info("ghostroom-web.zip")
if web_info:
    platforms["web"] = web_info

manifest = {
    "version": version,
    "release_date": datetime.now(timezone.utc).isoformat(),
    "release_url": page_url,
    "changelog": f"GhostRoom v{version}: Zero-knowledge P2P store-and-forward relay, automated in-app updates with SHA-256 integrity verification, and enhanced offline queuing.",
    "platforms": platforms
}

version_json_path = os.path.join(release_dir, "version.json")
with open(version_json_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)

# Also update project root version.json and VERSION.json
root_version_json = os.path.join("${PROJECT_ROOT}", "version.json")
root_VERSION_json = os.path.join("${PROJECT_ROOT}", "VERSION.json")
with open(root_version_json, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)
with open(root_VERSION_json, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)

print(f"✅ Generated {version_json_path}")
print(f"✅ Updated {root_version_json}")
print(f"✅ Updated {root_VERSION_json}")
EOF

echo ""
echo "========================================================"
echo "🎉 Release Build Complete! Artifacts in ${RELEASE_DIR}:"
ls -lh "${RELEASE_DIR}"
echo "========================================================"
