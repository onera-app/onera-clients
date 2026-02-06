#!/bin/bash
#
# ci_pre_xcodebuild.sh
# Xcode Cloud - Runs before xcodebuild starts
#
# Extracts the version from the git tag (e.g. v1.2.3 -> 1.2.3)
# and updates MARKETING_VERSION in the Xcode project.
# Uses CI_BUILD_NUMBER (auto-incremented by Xcode Cloud) for the build number.
#
# Also extracts release notes from CHANGELOG.md for TestFlight.
#

set -euo pipefail

echo "=== ci_pre_xcodebuild: Version management ==="

# --- Extract version from tag ---

if [ -n "${CI_TAG:-}" ]; then
    # Strip the 'v' prefix: v1.2.3 -> 1.2.3
    VERSION="${CI_TAG#v}"
    echo "Tag detected: ${CI_TAG}"
    echo "Marketing version: ${VERSION}"
else
    # Not a tag build - use default
    VERSION="1.0.0"
    echo "No tag detected, using default version: ${VERSION}"
fi

# Validate version format (x.y.z)
if ! echo "${VERSION}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "WARNING: Version '${VERSION}' doesn't match x.y.z format"
    echo "Falling back to 1.0.0"
    VERSION="1.0.0"
fi

BUILD_NUMBER="${CI_BUILD_NUMBER:-1}"
echo "Build number: ${BUILD_NUMBER}"

# --- Update Xcode project ---

PROJECT_DIR="${CI_WORKSPACE}/Onera"
PBXPROJ="${PROJECT_DIR}/Onera.xcodeproj/project.pbxproj"

if [ ! -f "${PBXPROJ}" ]; then
    echo "ERROR: project.pbxproj not found at ${PBXPROJ}"
    exit 1
fi

echo ""
echo "Updating project.pbxproj..."

# Update MARKETING_VERSION for all targets
sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = ${VERSION};/g" "${PBXPROJ}"

# Update CURRENT_PROJECT_VERSION for all targets
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};/g" "${PBXPROJ}"

echo "  MARKETING_VERSION = ${VERSION}"
echo "  CURRENT_PROJECT_VERSION = ${BUILD_NUMBER}"

# --- Extract release notes from CHANGELOG.md ---

CHANGELOG="${CI_WORKSPACE}/CHANGELOG.md"
TESTFLIGHT_NOTES="${CI_WORKSPACE}/Onera/ci_scripts/TestFlightNotes.txt"

if [ -f "${CHANGELOG}" ]; then
    echo ""
    echo "Extracting release notes for v${VERSION} from CHANGELOG.md..."
    
    # Extract the section between ## [x.y.z] and the next ## [
    # Uses awk to capture everything between the version header and the next header
    NOTES=$(awk "/^## \\[${VERSION}\\]/{found=1; next} /^## \\[/{if(found) exit} found{print}" "${CHANGELOG}")
    
    if [ -n "${NOTES}" ]; then
        echo "${NOTES}" > "${TESTFLIGHT_NOTES}"
        echo "  Release notes extracted ($(echo "${NOTES}" | wc -l | tr -d ' ') lines)"
    else
        echo "  No release notes found for version ${VERSION}"
        # Fall back to default release notes
        METADATA_NOTES="${CI_WORKSPACE}/metadata/en-US/release_notes/default.txt"
        if [ -f "${METADATA_NOTES}" ]; then
            cp "${METADATA_NOTES}" "${TESTFLIGHT_NOTES}"
            echo "  Using default release notes from metadata/"
        else
            echo "Bug fixes and performance improvements." > "${TESTFLIGHT_NOTES}"
            echo "  Using generic release notes"
        fi
    fi
else
    echo "  CHANGELOG.md not found, using generic release notes"
    echo "Bug fixes and performance improvements." > "${TESTFLIGHT_NOTES}"
fi

# --- Summary ---

echo ""
echo "=== ci_pre_xcodebuild: Summary ==="
echo "  Version:      ${VERSION}"
echo "  Build:        ${BUILD_NUMBER}"
echo "  Bundle ID:    $(grep 'PRODUCT_BUNDLE_IDENTIFIER' "${CI_WORKSPACE}/Onera/Onera/Production.xcconfig" 2>/dev/null | head -1 | awk -F'= ' '{print $2}' || echo 'unknown')"
echo "  Tag:          ${CI_TAG:-none}"
echo "=== Done ==="
