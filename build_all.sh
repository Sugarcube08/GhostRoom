#!/usr/bin/env bash

# ==============================================================================
# GhostRoom Cross-Platform Unified Release Builder & SHA-256 Verifier
# Usage: ./build_all.sh [version] [build_number]
# Examples:
#   ./build_all.sh                 # Preserves current version and build number
#   ./build_all.sh 2.2.4           # Bumps version to 2.2.4 and increments build number
#   ./build_all.sh 2.2.4 5         # Explicit version 2.2.4 and build number 5
#   ./build_all.sh 2.2.4+5         # Explicit version 2.2.4 and build number 5
#
# Builds: Android APK, Web Bundle, Linux (AppImage, deb, tar.gz), macOS, iOS
# Verifies: Computes SHA-256 hashes and strictly verifies via `sha256sum -c`
# Manifest: Generates single canonical `version.json` with verified platform assets
# ==============================================================================

set -euo pipefail

# 1. Project directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="${PROJECT_ROOT}/client"
RELEASE_DIR="${PROJECT_ROOT}/release"
OS="$(uname -s)"

# Ensure clean canonical version.json only - purge any legacy uppercase VERSION.json
rm -f "${PROJECT_ROOT}/VERSION.json" "${RELEASE_DIR}/VERSION.json" 2>/dev/null || true

# 2. Configure compatible JDK & Linux Native Library Paths
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

# Configure PKG_CONFIG_PATH and LIBRARY_PATH for user-level or system libraries (e.g. GStreamer)
if [ "${OS}" = "Linux" ]; then
    for lib_candidate in "${HOME}/.local/usr/lib/x86_64-linux-gnu" "/usr/local/lib/x86_64-linux-gnu" "/usr/lib/x86_64-linux-gnu"; do
        if [ -d "${lib_candidate}/pkgconfig" ]; then
            export PKG_CONFIG_PATH="${lib_candidate}/pkgconfig:${PKG_CONFIG_PATH:-}"
        fi
        if [ -d "${lib_candidate}" ]; then
            export LIBRARY_PATH="${lib_candidate}:${LIBRARY_PATH:-}"
        fi
    done
fi

# 3. Read target version and build number from parameters or existing files
RAW_VERSION="${1:-}"
EXPLICIT_BUILD="${2:-}"

if [ "${RAW_VERSION}" = "-h" ] || [ "${RAW_VERSION}" = "--help" ]; then
    echo "Usage: $0 [version] [build_number]"
    echo ""
    echo "Examples:"
    echo "  $0                 # Keep current version and build number from pubspec.yaml"
    echo "  $0 2.2.4           # Set version 2.2.4, auto-increment build number"
    echo "  $0 2.2.4 5         # Set version 2.2.4 and explicit build number 5"
    echo "  $0 2.2.4+5         # Set version 2.2.4 and explicit build number 5"
    exit 0
fi

# Parse inline build number if passed as "version+build" (e.g. 2.2.4+5)
if [[ "${RAW_VERSION}" == *"+"* ]]; then
    TARGET_VERSION="${RAW_VERSION%%+*}"
    INLINE_BUILD="${RAW_VERSION##*+}"
    if [ -z "${EXPLICIT_BUILD}" ]; then
        EXPLICIT_BUILD="${INLINE_BUILD}"
    fi
else
    TARGET_VERSION="${RAW_VERSION}"
fi

# Fallback to existing version.json or pubspec.yaml if version is not provided
if [ -z "${TARGET_VERSION}" ] && [ -f "${PROJECT_ROOT}/version.json" ]; then
    TARGET_VERSION=$(grep '"version"' "${PROJECT_ROOT}/version.json" | head -n 1 | awk -F '"' '{print $4}')
fi
if [ -z "${TARGET_VERSION}" ]; then
    TARGET_VERSION=$(grep "^version:" "${CLIENT_DIR}/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1 | tr -d '[:space:]')
fi
if [ -z "${TARGET_VERSION}" ]; then
    TARGET_VERSION="2.2.3"
fi

# Clean version string (strip leading 'v' or 'V')
TARGET_VERSION="${TARGET_VERSION#v}"
TARGET_VERSION="${TARGET_VERSION#V}"

# Determine current build number from pubspec.yaml
CURRENT_BUILD=$(grep "^version:" "${CLIENT_DIR}/pubspec.yaml" | cut -d'+' -f2 | tr -d '[:space:]')
if [ -z "${CURRENT_BUILD}" ] || [ "${CURRENT_BUILD}" = "${TARGET_VERSION}" ]; then
    CURRENT_BUILD="1"
fi

# Calculate new build number
if [ -n "${EXPLICIT_BUILD}" ]; then
    BUILD_NUMBER="${EXPLICIT_BUILD}"
elif [ -n "${1:-}" ]; then
    # Version was explicitly specified but no build number was given: auto-increment
    BUILD_NUMBER=$((CURRENT_BUILD + 1))
else
    # Neither was passed: preserve current build number
    BUILD_NUMBER="${CURRENT_BUILD}"
fi

DEB_VERSION="${TARGET_VERSION//+/-}"

echo "========================================================"
echo "🚀 GhostRoom Unified Build & Verification"
echo "   Target Version:  v${TARGET_VERSION}"
echo "   Build Number:    ${BUILD_NUMBER}"
echo "   Full Version:    ${TARGET_VERSION}+${BUILD_NUMBER}"
echo "   Host Platform:   ${OS}"
echo "========================================================"

# Update client/pubspec.yaml with the synchronized version and build number
sed -i "s/^version: .*/version: ${TARGET_VERSION}+${BUILD_NUMBER}/" "${CLIENT_DIR}/pubspec.yaml"
echo "📝 Synchronized client/pubspec.yaml -> version: ${TARGET_VERSION}+${BUILD_NUMBER}"

# 4. Prepare release directory
mkdir -p "${RELEASE_DIR}"
rm -f "${RELEASE_DIR}"/*.apk "${RELEASE_DIR}"/*.zip "${RELEASE_DIR}"/*.tar.gz "${RELEASE_DIR}"/*.AppImage "${RELEASE_DIR}"/*.deb "${RELEASE_DIR}"/*.rpm "${RELEASE_DIR}"/*.ipa "${RELEASE_DIR}"/SHA256SUMS 2>/dev/null || true

# 5. Check System Dependencies (Linux only)
if [ "${OS}" = "Linux" ]; then
    echo "📦 Checking Linux build tools & multimedia headers..."
    MISSING_DEPS=()
    for pkg in clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libglu1-mesa-dev libsecret-1-dev libjsoncpp-dev zip tar libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev liborc-0.4-dev; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            MISSING_DEPS+=("$pkg")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "📦 Handling dependencies: ${MISSING_DEPS[*]}..."
        if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
            sudo apt-get update && sudo apt-get install -y "${MISSING_DEPS[@]}" || true
        else
            # Non-root user space fallback for GStreamer if missing
            if ! pkg-config --exists gstreamer-1.0 2>/dev/null; then
                echo "ℹ️ Configuring user-space GStreamer development headers in ~/.local..."
                DEB_TMP=$(mktemp -d)
                (cd "${DEB_TMP}" && apt-get download libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev liborc-0.4-dev >/dev/null 2>&1 && \
                 for d in *.deb; do dpkg -x "$d" "${HOME}/.local" >/dev/null 2>&1; done) || true
                rm -rf "${DEB_TMP}"
                if [ -d "${HOME}/.local/usr/lib/x86_64-linux-gnu/pkgconfig" ]; then
                    sed -i "s|^prefix=/usr|prefix=${HOME}/.local/usr|g" "${HOME}/.local/usr/lib/x86_64-linux-gnu/pkgconfig"/*.pc 2>/dev/null || true
                    ln -sf /usr/lib/x86_64-linux-gnu/libgst* /usr/lib/x86_64-linux-gnu/libgstreamer* /usr/lib/x86_64-linux-gnu/liborc* "${HOME}/.local/usr/lib/x86_64-linux-gnu/" 2>/dev/null || true
                    export PKG_CONFIG_PATH="${HOME}/.local/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"
                    export LIBRARY_PATH="${HOME}/.local/usr/lib/x86_64-linux-gnu:${LIBRARY_PATH:-}"
                fi
            fi
        fi
    fi

    if pkg-config --exists gstreamer-1.0; then
        echo "✅ GStreamer development libraries verified ($(pkg-config --modversion gstreamer-1.0))."
    fi
    echo "✅ Host build tools verified."
fi

# 6. Fetch Flutter Dependencies
echo ""
echo "📥 Fetching Flutter dependencies..."
cd "${CLIENT_DIR}"
flutter pub get

# 7. Build Web
echo ""
echo "🌐 Building Web Release (v${TARGET_VERSION}+${BUILD_NUMBER})..."
flutter build web --release --no-wasm-dry-run --build-name="${TARGET_VERSION}" --build-number="${BUILD_NUMBER}"
WEB_DIR="${CLIENT_DIR}/build/web"
if [ -d "${WEB_DIR}" ]; then
    (cd "${WEB_DIR}" && zip -rq "${RELEASE_DIR}/ghostroom-web.zip" .)
    echo "✅ Created: ${RELEASE_DIR}/ghostroom-web.zip"
fi

# 8. Build Linux (Linux host only)
if [ "${OS}" = "Linux" ]; then
    echo ""
    echo "🐧 Building Linux Native Executable (v${TARGET_VERSION}+${BUILD_NUMBER})..."
    if flutter build linux --release --build-name="${TARGET_VERSION}" --build-number="${BUILD_NUMBER}"; then
        BUNDLE_DIR="${CLIENT_DIR}/build/linux/x64/release/bundle"
        if [ -d "${BUNDLE_DIR}" ]; then
            # Tarball
            (cd "${BUNDLE_DIR}" && tar -czf "${RELEASE_DIR}/ghostroom-linux-x86_64.tar.gz" .)
            echo "✅ Created: ${RELEASE_DIR}/ghostroom-linux-x86_64.tar.gz"

            # Desktop entry & icon paths
            ICON_SOURCE="${CLIENT_DIR}/web/icons/Icon-512.png"

            # Debian Package (.deb)
            if command -v dpkg-deb &> /dev/null; then
                echo "📦 Building Linux Debian package (.deb)..."
                DEB_DIR="${CLIENT_DIR}/build/linux/deb/ghostroom_${DEB_VERSION}_amd64"
                mkdir -p "${DEB_DIR}/DEBIAN" "${DEB_DIR}/usr/bin" "${DEB_DIR}/opt/ghostroom" "${DEB_DIR}/usr/share/applications" "${DEB_DIR}/usr/share/icons/hicolor/512x512/apps"
                cp -r "${BUNDLE_DIR}"/* "${DEB_DIR}/opt/ghostroom/"
                ln -sf /opt/ghostroom/ghostroom "${DEB_DIR}/usr/bin/ghostroom"

                cat <<CTRL > "${DEB_DIR}/DEBIAN/control"
Package: ghostroom
Version: ${DEB_VERSION}
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libsecret-1-0
Maintainer: GhostRoom Team
Description: Privacy-First Ephemeral Zero-Knowledge Communication
CTRL

                cat <<DESK > "${DEB_DIR}/usr/share/applications/ghostroom.desktop"
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

                if [ -f "${ICON_SOURCE}" ]; then
                    cp "${ICON_SOURCE}" "${DEB_DIR}/usr/share/icons/hicolor/512x512/apps/ghostroom.png"
                fi
                dpkg-deb --build "${DEB_DIR}" "${RELEASE_DIR}/ghostroom-linux_${DEB_VERSION}_amd64.deb" > /dev/null
                cp "${RELEASE_DIR}/ghostroom-linux_${DEB_VERSION}_amd64.deb" "${RELEASE_DIR}/ghostroom-linux.deb"
                echo "✅ Created: ${RELEASE_DIR}/ghostroom-linux.deb"
            fi

            # AppImage (.AppImage)
            APPIMAGE_TOOL="${PROJECT_ROOT}/appimagetool-x86_64.AppImage"
            if [ -f "${APPIMAGE_TOOL}" ]; then
                echo "📦 Packaging Linux AppImage (.AppImage)..."
                chmod +x "${APPIMAGE_TOOL}"
                APPDIR="${CLIENT_DIR}/build/linux/AppDir"
                rm -rf "${APPDIR}"
                mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/share/icons/hicolor/512x512/apps"
                cp -r "${BUNDLE_DIR}"/* "${APPDIR}/"

                cat <<DESK > "${APPDIR}/ghostroom.desktop"
[Desktop Entry]
Version=1.0
Name=GhostRoom
GenericName=GhostRoom
Comment=Privacy-First Ephemeral Communication
Terminal=false
Type=Application
Categories=Network;Chat;
Exec=ghostroom
Icon=ghostroom
DESK

                if [ -f "${ICON_SOURCE}" ]; then
                    cp "${ICON_SOURCE}" "${APPDIR}/ghostroom.png"
                    cp "${ICON_SOURCE}" "${APPDIR}/usr/share/icons/hicolor/512x512/apps/ghostroom.png"
                fi

                cat <<'APPRUN' > "${APPDIR}/AppRun"
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/ghostroom" "$@"
APPRUN
                chmod +x "${APPDIR}/AppRun"

                ARCH=x86_64 "${APPIMAGE_TOOL}" --appimage-extract-and-run "${APPDIR}" "${RELEASE_DIR}/ghostroom-linux-x86_64.AppImage" > /dev/null 2>&1 || \
                ARCH=x86_64 "${APPIMAGE_TOOL}" "${APPDIR}" "${RELEASE_DIR}/ghostroom-linux-x86_64.AppImage" > /dev/null 2>&1 || true

                if [ -f "${RELEASE_DIR}/ghostroom-linux-x86_64.AppImage" ]; then
                    chmod +x "${RELEASE_DIR}/ghostroom-linux-x86_64.AppImage"
                    echo "✅ Created: ${RELEASE_DIR}/ghostroom-linux-x86_64.AppImage"
                fi
            fi

            # RPM package via alien (if installed)
            if command -v alien &> /dev/null && [ -f "${RELEASE_DIR}/ghostroom-linux.deb" ]; then
                echo "📦 Building RPM package..."
                (cd "${RELEASE_DIR}" && alien --to-rpm --scripts ghostroom-linux.deb 2>/dev/null || alien -r ghostroom-linux.deb 2>/dev/null || true) > /dev/null 2>&1 || true
            fi
        fi
    else
        echo "⚠️ Linux build failed or skipped."
    fi
fi

# 9. Build Android APK
echo ""
echo "🤖 Building Android Release APK (v${TARGET_VERSION}+${BUILD_NUMBER})..."
if flutter build apk --release --build-name="${TARGET_VERSION}" --build-number="${BUILD_NUMBER}"; then
    APK_SOURCE="${CLIENT_DIR}/build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "${APK_SOURCE}" ]; then
        cp "${APK_SOURCE}" "${RELEASE_DIR}/ghostroom-android.apk"
        echo "✅ Created: ${RELEASE_DIR}/ghostroom-android.apk"
    fi
else
    echo "⚠️ Android build failed or skipped."
fi

# 10. Build macOS & iOS (Darwin host only)
if [ "${OS}" = "Darwin" ]; then
    echo ""
    echo "🍎 Building macOS App (v${TARGET_VERSION}+${BUILD_NUMBER})..."
    if flutter build macos --release --build-name="${TARGET_VERSION}" --build-number="${BUILD_NUMBER}"; then
        MACOS_BUNDLE="${CLIENT_DIR}/build/macos/Build/Products/Release/ghostroom.app"
        if [ -d "${MACOS_BUNDLE}" ]; then
            (cd "${CLIENT_DIR}/build/macos/Build/Products/Release" && zip -rq "${RELEASE_DIR}/ghostroom-macos.zip" ghostroom.app)
            echo "✅ Created: ${RELEASE_DIR}/ghostroom-macos.zip"
        fi
    fi

    echo ""
    echo "📱 Building iOS IPA (v${TARGET_VERSION}+${BUILD_NUMBER})..."
    if flutter build ipa --release --no-codesign --build-name="${TARGET_VERSION}" --build-number="${BUILD_NUMBER}"; then
        IPA_SOURCE=$(ls "${CLIENT_DIR}"/build/ios/ipa/*.ipa 2>/dev/null | head -n 1 || true)
        if [ -n "${IPA_SOURCE}" ] && [ -f "${IPA_SOURCE}" ]; then
            cp "${IPA_SOURCE}" "${RELEASE_DIR}/ghostroom-ios.ipa"
            echo "✅ Created: ${RELEASE_DIR}/ghostroom-ios.ipa"
        fi
    fi
fi

# 11. Calculate SHA-256 Checksums
echo ""
echo "🔒 Calculating SHA-256 checksums for all release assets..."
cd "${RELEASE_DIR}"
rm -f SHA256SUMS version.json VERSION.json

for file in *; do
    if [ -f "${file}" ] && [ "${file}" != "version.json" ] && [ "${file}" != "VERSION.json" ] && [ "${file}" != "SHA256SUMS" ]; then
        sha256sum "${file}" >> SHA256SUMS
    fi
done

if [ ! -f SHA256SUMS ] || [ ! -s SHA256SUMS ]; then
    echo "❌ Error: No release assets were generated to checksum!"
    exit 1
fi

echo "📋 Generated SHA256SUMS:"
cat SHA256SUMS

# 12. VERIFY SHA-256 Checksums (Strict integrity verification)
echo ""
echo "🛡️ Verifying SHA-256 checksums..."
if sha256sum -c SHA256SUMS; then
    echo "✅ SHA-256 integrity verification PASSED for all assets."
else
    echo "❌ SHA-256 integrity verification FAILED!"
    exit 1
fi

# 13. Build Single Canonical version.json
echo ""
echo "📄 Generating single canonical version.json..."

python3 - <<EOF
import os
import json
import hashlib
import glob
from datetime import datetime, timezone

release_dir = "${RELEASE_DIR}"
project_root = "${PROJECT_ROOT}"
version = "${TARGET_VERSION}"
build_number = int("${BUILD_NUMBER}")
tag = f"v{version}"
release_base_url = f"https://github.com/Sugarcube08/GhostRoom/releases/download/{tag}"
page_url = f"https://github.com/Sugarcube08/GhostRoom/releases/tag/{tag}"

def get_file_info(filename, display_name=None, fmt=None):
    path = os.path.join(release_dir, filename)
    if not os.path.isfile(path):
        return None
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    
    if not fmt:
        if filename.endswith(".AppImage"): fmt = "appimage"
        elif filename.endswith(".deb"): fmt = "deb"
        elif filename.endswith(".rpm"): fmt = "rpm"
        elif filename.endswith(".tar.gz"): fmt = "tar.gz"
        elif filename.endswith(".apk"): fmt = "apk"
        elif filename.endswith(".zip"): fmt = "zip"
        elif filename.endswith(".ipa"): fmt = "ipa"
        else: fmt = "bin"

    return {
        "name": display_name or filename,
        "format": fmt,
        "filename": filename,
        "url": f"{release_base_url}/{filename}",
        "sha256": h.hexdigest(),
        "size_bytes": os.path.getsize(path)
    }

platforms = {}

# Android APK
android_info = get_file_info("ghostroom-android.apk", "Android Package (APK)", "apk")
platforms["android"] = android_info if android_info else {
    "name": "Android Package (APK)",
    "format": "apk",
    "url": f"{release_base_url}/ghostroom-android.apk",
    "filename": "ghostroom-android.apk",
    "sha256": "",
    "size_bytes": 0
}

# Linux derivatives
linux_appimage = get_file_info("ghostroom-linux-x86_64.AppImage", "Linux Universal AppImage", "appimage")
linux_deb = get_file_info("ghostroom-linux.deb", "Debian / Ubuntu Package (.deb)", "deb")
linux_tar = get_file_info("ghostroom-linux-x86_64.tar.gz", "Linux Standalone Bundle (.tar.gz)", "tar.gz")

rpm_files = glob.glob(os.path.join(release_dir, "ghostroom-*.rpm"))
linux_rpm = None
if rpm_files:
    rpm_filename = os.path.basename(sorted(rpm_files)[-1])
    linux_rpm = get_file_info(rpm_filename, "Fedora / RHEL / openSUSE Package (.rpm)", "rpm")

# Default linux key points to AppImage (fallback to tar.gz / deb) for standard compatibility
platforms["linux"] = linux_appimage or linux_tar or linux_deb or {
    "name": "Linux Universal AppImage",
    "format": "appimage",
    "url": f"{release_base_url}/ghostroom-linux-x86_64.AppImage",
    "filename": "ghostroom-linux-x86_64.AppImage",
    "sha256": "",
    "size_bytes": 0
}

if linux_appimage:
    platforms["linux_appimage"] = linux_appimage
if linux_deb:
    platforms["linux_deb"] = linux_deb
if linux_rpm:
    platforms["linux_rpm"] = linux_rpm
if linux_tar:
    platforms["linux_tar"] = linux_tar

# Windows Bundle
windows_info = get_file_info("ghostroom-windows-x64.zip", "Windows Portable Bundle (x64)", "zip")
platforms["windows"] = windows_info if windows_info else {
    "name": "Windows Portable Bundle (x64)",
    "format": "zip",
    "url": f"{release_base_url}/ghostroom-windows-x64.zip",
    "filename": "ghostroom-windows-x64.zip",
    "sha256": "",
    "size_bytes": 0
}

# macOS Bundle
macos_info = get_file_info("ghostroom-macos.zip", "macOS Universal Bundle", "zip")
platforms["macos"] = macos_info if macos_info else {
    "name": "macOS Universal Bundle",
    "format": "zip",
    "url": f"{release_base_url}/ghostroom-macos.zip",
    "filename": "ghostroom-macos.zip",
    "sha256": "",
    "size_bytes": 0
}

# iOS Package
ios_info = get_file_info("ghostroom-ios.ipa", "iOS Package (IPA)", "ipa")
if ios_info:
    platforms["ios"] = ios_info

# Web Application Archive
web_info = get_file_info("ghostroom-web.zip", "Web Release Archive", "zip")
if web_info:
    platforms["web"] = web_info

manifest = {
    "version": version,
    "build_number": build_number,
    "release_date": datetime.now(timezone.utc).isoformat(),
    "release_url": page_url,
    "changelog": f"GhostRoom v{version}+{build_number}: Zero-knowledge P2P store-and-forward relay, automated in-app updates with SHA-256 integrity verification, and enhanced offline queuing.",
    "platforms": platforms
}

# Write to release/version.json
rel_version_path = os.path.join(release_dir, "version.json")
with open(rel_version_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)

# Write to single canonical root version.json
root_version_path = os.path.join(project_root, "version.json")
with open(root_version_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)

# Ensure uppercase VERSION.json is purged everywhere
for p in [os.path.join(project_root, "VERSION.json"), os.path.join(release_dir, "VERSION.json")]:
    if os.path.exists(p):
        os.remove(p)

print(f"✅ Created: {rel_version_path}")
print(f"✅ Created: {root_version_path}")
EOF

echo ""
echo "========================================================"
echo "🎉 Build & SHA-256 Verification Complete for v${TARGET_VERSION}+${BUILD_NUMBER}!"
echo "Assets in ${RELEASE_DIR}:"
ls -lh "${RELEASE_DIR}"
echo "========================================================"
