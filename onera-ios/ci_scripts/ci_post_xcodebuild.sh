#!/bin/bash
#
# ci_post_xcodebuild.sh
# Xcode Cloud - Runs after xcodebuild completes
#
# Post-build validation and artifact logging.
#

set -eo pipefail

echo "=== ci_post_xcodebuild: Post-build ==="

# Resolve paths relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Log build result ---

if [ "${CI_XCODEBUILD_EXIT_CODE:-0}" -ne 0 ]; then
    echo "ERROR: Build failed with exit code ${CI_XCODEBUILD_EXIT_CODE}"
    exit 1
fi

echo "Build succeeded."

# --- Log archive info ---

if [ -n "${CI_ARCHIVE_PATH:-}" ] && [ -d "${CI_ARCHIVE_PATH}" ]; then
    echo ""
    echo "Archive: ${CI_ARCHIVE_PATH}"
    
    # Log the app bundle size
    APP_PATH=$(find "${CI_ARCHIVE_PATH}" -name "*.app" -maxdepth 3 | head -1)
    if [ -n "${APP_PATH}" ]; then
        APP_SIZE=$(du -sh "${APP_PATH}" | awk '{print $1}')
        echo "  App size: ${APP_SIZE}"
    fi
    
    # Log Info.plist version
    PLIST="${APP_PATH}/Info.plist"
    if [ -f "${PLIST}" ]; then
        BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${PLIST}" 2>/dev/null || echo "unknown")
        BUILD_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PLIST}" 2>/dev/null || echo "unknown")
        BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "${PLIST}" 2>/dev/null || echo "unknown")
        echo "  Bundle ID: ${BUNDLE_ID}"
        echo "  Version: ${BUNDLE_VERSION} (${BUILD_VERSION})"
    fi
fi

# --- Log TestFlight notes ---

TESTFLIGHT_NOTES="${SCRIPT_DIR}/TestFlightNotes.txt"
if [ -f "${TESTFLIGHT_NOTES}" ]; then
    echo ""
    echo "TestFlight release notes:"
    echo "---"
    cat "${TESTFLIGHT_NOTES}"
    echo "---"
fi

echo ""
echo "=== ci_post_xcodebuild: Done ==="
