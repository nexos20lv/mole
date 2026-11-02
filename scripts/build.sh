#!/usr/bin/env bash
#
# Mole Build & Install Script
# Compiles the native Swift/SwiftUI binary and packages the macOS App Bundle.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_DIR}/build"
APP_NAME="Mole"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
INSTALL_DEST="/Applications/${APP_NAME}.app"

echo "🧹 [Mole] Préparation du build..."
mkdir -p "${BUILD_DIR}"
rm -rf "${APP_BUNDLE}"

# 1. Compilation du binaire Swift
echo "⚡️ [Mole] Compilation de ${APP_NAME} (Swift / SwiftUI Native)..."
swiftc -O \
    -parse-as-library \
    -target arm64-apple-macos14.0 \
    -framework SwiftUI \
    -framework AppKit \
    -o "${BUILD_DIR}/${APP_NAME}" \
    "${REPO_DIR}/Sources/App.swift"

# 2. Structure du Bundle macOS
echo "📦 [Mole] Création du bundle .app..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

mv "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${REPO_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

if [ -f "${REPO_DIR}/Resources/mole.icns" ]; then
    cp "${REPO_DIR}/Resources/mole.icns" "${APP_BUNDLE}/Contents/Resources/mole.icns"
fi

if [ -f "${REPO_DIR}/Resources/mole-logo.png" ]; then
    cp "${REPO_DIR}/Resources/mole-logo.png" "${APP_BUNDLE}/Contents/Resources/mole-logo.png"
fi

# 3. Signature ad-hoc
echo "🔐 [Mole] Signature du binaire macOS..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ [Mole] Build terminé avec succès dans : ${APP_BUNDLE}"

# 4. Installation optionnelle
if [[ "${1:-}" == "--install" ]] || [[ "${INSTALL:-0}" == "1" ]]; then
    echo "🚀 [Mole] Installation dans /Applications/${APP_NAME}.app..."
    rm -rf "${INSTALL_DEST}"
    cp -R "${APP_BUNDLE}" "${INSTALL_DEST}"
    touch "${INSTALL_DEST}"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${INSTALL_DEST}" 2>/dev/null || true
    echo "✨ [Mole] Installé et enregistré avec succès !"
fi
