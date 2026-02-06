#!/bin/bash
#
# update_release_notes.sh
# Automates App Store release: sets "What's New", attaches build, submits for review
#
# Requires these Xcode Cloud environment variables:
#   ASC_KEY_ID        - App Store Connect API Key ID
#   ASC_ISSUER_ID     - App Store Connect API Issuer ID
#   ASC_API_KEY_B64   - Base64-encoded .p8 private key contents
#   ASC_APP_ID        - App Store Connect App ID (6758128954 for Onera)
#
# Flow:
#   1. Extract release notes from CHANGELOG.md (done by ci_pre_xcodebuild.sh)
#   2. Find or create the App Store version
#   3. Set "What's New" text
#   4. Wait for build to be processed by App Store Connect
#   5. Attach build to the version
#   6. Submit for App Review
#
# Called from ci_post_xcodebuild.sh after a successful build.
#

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Validate required env vars ---

REQUIRED_VARS=("ASC_KEY_ID" "ASC_ISSUER_ID" "ASC_API_KEY_B64" "ASC_APP_ID")
MISSING=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        MISSING+=("$var")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "[release_notes] Skipping - missing env vars: ${MISSING[*]}"
    echo "[release_notes] Set these in Xcode Cloud > Workflow > Environment Variables"
    exit 0  # Don't fail the build
fi

# --- Read release notes ---

RELEASE_NOTES_FILE="${SCRIPT_DIR}/TestFlightNotes.txt"
if [ ! -f "${RELEASE_NOTES_FILE}" ]; then
    echo "[release_notes] No TestFlightNotes.txt found, skipping"
    exit 0
fi

RELEASE_NOTES=$(cat "${RELEASE_NOTES_FILE}")
if [ -z "${RELEASE_NOTES}" ]; then
    echo "[release_notes] Release notes empty, skipping"
    exit 0
fi

echo "[release_notes] Will set What's New to:"
echo "---"
echo "${RELEASE_NOTES}"
echo "---"

# --- Decode the API key ---

ASC_API_KEY=$(echo "${ASC_API_KEY_B64}" | base64 --decode)

# --- Generate JWT ---
# App Store Connect API uses ES256 JWTs
# We generate it using openssl (available on Xcode Cloud macOS)

generate_jwt() {
    local key_id="$1"
    local issuer_id="$2"
    local private_key="$3"
    
    # Header
    local header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$key_id")
    local header_b64=$(printf '%s' "$header" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    
    # Payload - expires in 20 minutes
    local now=$(date +%s)
    local exp=$((now + 1200))
    local payload=$(printf '{"iss":"%s","iat":%d,"exp":%d,"aud":"appstoreconnect-v1"}' "$issuer_id" "$now" "$exp")
    local payload_b64=$(printf '%s' "$payload" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    
    # Sign
    local signing_input="${header_b64}.${payload_b64}"
    
    # Write private key to temp file
    local key_file=$(mktemp)
    echo "$private_key" > "$key_file"
    
    # ES256 signature: sign with ECDSA using SHA-256, then convert DER to raw r||s
    local der_sig=$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$key_file" -binary 2>/dev/null)
    rm -f "$key_file"
    
    # Convert DER signature to raw 64-byte r||s format
    # DER: 30 <len> 02 <rlen> <r> 02 <slen> <s>
    local raw_sig=$(printf '%s' "$der_sig" | python3 -c "
import sys
der = sys.stdin.buffer.read()
# Parse DER SEQUENCE
assert der[0] == 0x30
idx = 2
# Parse r INTEGER
assert der[idx] == 0x02
rlen = der[idx+1]
r = der[idx+2:idx+2+rlen]
idx = idx + 2 + rlen
# Parse s INTEGER
assert der[idx] == 0x02
slen = der[idx+1]
s = der[idx+2:idx+2+slen]
# Pad/trim to 32 bytes each
r = r[-32:].rjust(32, b'\\x00')
s = s[-32:].rjust(32, b'\\x00')
sys.stdout.buffer.write(r + s)
")
    
    local sig_b64=$(printf '%s' "$raw_sig" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    
    echo "${signing_input}.${sig_b64}"
}

JWT=$(generate_jwt "$ASC_KEY_ID" "$ASC_ISSUER_ID" "$ASC_API_KEY")

if [ -z "$JWT" ]; then
    echo "[release_notes] ERROR: Failed to generate JWT"
    exit 0  # Don't fail the build
fi

echo "[release_notes] JWT generated successfully"

ASC_BASE="https://api.appstoreconnect.apple.com/v1"
AUTH_HEADER="Authorization: Bearer ${JWT}"

# --- Get the version from CI ---

VERSION="${CI_TAG:-}"
VERSION="${VERSION#v}"  # Strip 'v' prefix

if [ -z "$VERSION" ]; then
    echo "[release_notes] No CI_TAG set, cannot determine version"
    exit 0
fi

echo "[release_notes] Looking for app version: ${VERSION}"

# --- Find the App Store Version ---
# Look for version in READY_FOR_SALE, PREPARE_FOR_SUBMISSION, or WAITING_FOR_REVIEW state

APP_VERSIONS_RESPONSE=$(curl -s -H "$AUTH_HEADER" \
    "${ASC_BASE}/apps/${ASC_APP_ID}/appStoreVersions?filter[platform]=IOS&limit=5")

# Find the version ID that matches our version string
VERSION_ID=$(echo "$APP_VERSIONS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
target = '${VERSION}'
for item in data.get('data', []):
    attrs = item.get('attributes', {})
    if attrs.get('versionString') == target:
        print(item['id'])
        break
" 2>/dev/null)

if [ -z "$VERSION_ID" ]; then
    echo "[release_notes] Version ${VERSION} not found in App Store Connect"
    echo "[release_notes] Available versions:"
    echo "$APP_VERSIONS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('data', []):
    attrs = item.get('attributes', {})
    print(f\"  {attrs.get('versionString', '?')} ({attrs.get('appStoreState', '?')}) - id: {item['id']}\")
" 2>/dev/null || echo "  (could not parse response)"
    
    # Try to create the version if it doesn't exist
    echo "[release_notes] Attempting to create version ${VERSION}..."
    CREATE_RESPONSE=$(curl -s -X POST -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d "{
            \"data\": {
                \"type\": \"appStoreVersions\",
                \"attributes\": {
                    \"versionString\": \"${VERSION}\",
                    \"platform\": \"IOS\"
                },
                \"relationships\": {
                    \"app\": {
                        \"data\": {
                            \"type\": \"apps\",
                            \"id\": \"${ASC_APP_ID}\"
                        }
                    }
                }
            }
        }" \
        "${ASC_BASE}/appStoreVersions")
    
    VERSION_ID=$(echo "$CREATE_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('data', {}).get('id', ''))
" 2>/dev/null)
    
    if [ -z "$VERSION_ID" ]; then
        echo "[release_notes] Could not create version. Response:"
        echo "$CREATE_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$CREATE_RESPONSE"
        exit 0
    fi
    echo "[release_notes] Created version ${VERSION} with ID: ${VERSION_ID}"
fi

echo "[release_notes] Found version ID: ${VERSION_ID}"

# --- Get the localization for en-US ---

LOCALIZATIONS_RESPONSE=$(curl -s -H "$AUTH_HEADER" \
    "${ASC_BASE}/appStoreVersions/${VERSION_ID}/appStoreVersionLocalizations")

LOCALIZATION_ID=$(echo "$LOCALIZATIONS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('data', []):
    attrs = item.get('attributes', {})
    if attrs.get('locale') == 'en-US':
        print(item['id'])
        break
" 2>/dev/null)

if [ -z "$LOCALIZATION_ID" ]; then
    echo "[release_notes] No en-US localization found, creating one..."
    
    # Escape release notes for JSON
    ESCAPED_NOTES=$(python3 -c "import json; print(json.dumps('${RELEASE_NOTES}'))" 2>/dev/null | sed 's/^"//;s/"$//')
    
    CREATE_LOC_RESPONSE=$(curl -s -X POST -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d "{
            \"data\": {
                \"type\": \"appStoreVersionLocalizations\",
                \"attributes\": {
                    \"locale\": \"en-US\",
                    \"whatsNew\": \"${ESCAPED_NOTES}\"
                },
                \"relationships\": {
                    \"appStoreVersion\": {
                        \"data\": {
                            \"type\": \"appStoreVersions\",
                            \"id\": \"${VERSION_ID}\"
                        }
                    }
                }
            }
        }" \
        "${ASC_BASE}/appStoreVersionLocalizations")
    
    echo "[release_notes] Created en-US localization with What's New"
    exit 0
fi

echo "[release_notes] Found en-US localization ID: ${LOCALIZATION_ID}"

# --- Update the What's New text ---

# Escape release notes for JSON using python3 (handles newlines, quotes, etc.)
ESCAPED_NOTES=$(python3 -c "
import json, sys
notes = open('${RELEASE_NOTES_FILE}').read().strip()
# Print just the escaped string content (without outer quotes)
print(json.dumps(notes)[1:-1])
")

UPDATE_RESPONSE=$(curl -s -X PATCH -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{
        \"data\": {
            \"type\": \"appStoreVersionLocalizations\",
            \"id\": \"${LOCALIZATION_ID}\",
            \"attributes\": {
                \"whatsNew\": \"${ESCAPED_NOTES}\"
            }
        }
    }" \
    "${ASC_BASE}/appStoreVersionLocalizations/${LOCALIZATION_ID}")

# Check for errors
ERROR_CHECK=$(echo "$UPDATE_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
errors = data.get('errors', [])
if errors:
    for e in errors:
        print(f\"ERROR: {e.get('title', '')} - {e.get('detail', '')}\")
else:
    print('SUCCESS')
" 2>/dev/null)

if echo "$ERROR_CHECK" | grep -q "SUCCESS"; then
    echo "[release_notes] Successfully updated What's New for version ${VERSION}"
else
    echo "[release_notes] Failed to update What's New:"
    echo "$ERROR_CHECK"
fi

# --- Auto-submit: Attach build and submit for review ---
#
# Xcode Cloud uploads the build to App Store Connect automatically.
# We need to:
#   1. Wait for the build to finish processing
#   2. Find the build by version + build number
#   3. Attach it to the App Store version
#   4. Submit for review
#

BUILD_NUMBER="${CI_BUILD_NUMBER:-}"
if [ -z "$BUILD_NUMBER" ]; then
    echo "[auto-submit] No CI_BUILD_NUMBER, skipping auto-submit"
    exit 0
fi

echo ""
echo "=== Auto-submit: Attaching build and submitting for review ==="

# --- Wait for build to be processed ---
# Xcode Cloud uploads the build after ci_post_xcodebuild, so the build
# may not be fully processed yet. We poll until it appears.

echo "[auto-submit] Waiting for build ${VERSION} (${BUILD_NUMBER}) to be processed..."

BUILD_ID=""
MAX_ATTEMPTS=30  # 30 * 30s = 15 minutes max wait
ATTEMPT=0

while [ -z "$BUILD_ID" ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    BUILDS_RESPONSE=$(curl -s -H "$AUTH_HEADER" \
        "${ASC_BASE}/builds?filter[app]=${ASC_APP_ID}&filter[version]=${BUILD_NUMBER}&filter[preReleaseVersion.version]=${VERSION}&limit=1")
    
    BUILD_ID=$(echo "$BUILDS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('data', []):
    attrs = item.get('attributes', {})
    state = attrs.get('processingState', '')
    if state in ('VALID', 'PROCESSING'):
        if state == 'VALID':
            print(item['id'])
        # If PROCESSING, keep waiting
        break
" 2>/dev/null)
    
    if [ -z "$BUILD_ID" ]; then
        if [ $ATTEMPT -eq 1 ] || [ $((ATTEMPT % 5)) -eq 0 ]; then
            echo "[auto-submit] Build not ready yet (attempt ${ATTEMPT}/${MAX_ATTEMPTS}), waiting 30s..."
        fi
        sleep 30
    fi
done

if [ -z "$BUILD_ID" ]; then
    echo "[auto-submit] Build not found after ${MAX_ATTEMPTS} attempts, skipping auto-submit"
    echo "[auto-submit] You'll need to manually select the build and submit in App Store Connect"
    exit 0
fi

echo "[auto-submit] Build found: ${BUILD_ID}"

# --- Attach build to the App Store version ---

echo "[auto-submit] Attaching build to version ${VERSION}..."

ATTACH_RESPONSE=$(curl -s -X PATCH -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{
        \"data\": {
            \"type\": \"appStoreVersions\",
            \"id\": \"${VERSION_ID}\",
            \"relationships\": {
                \"build\": {
                    \"data\": {
                        \"type\": \"builds\",
                        \"id\": \"${BUILD_ID}\"
                    }
                }
            }
        }
    }" \
    "${ASC_BASE}/appStoreVersions/${VERSION_ID}")

ATTACH_ERROR=$(echo "$ATTACH_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
errors = data.get('errors', [])
if errors:
    for e in errors:
        print(f\"ERROR: {e.get('title', '')} - {e.get('detail', '')}\")
else:
    print('SUCCESS')
" 2>/dev/null)

if ! echo "$ATTACH_ERROR" | grep -q "SUCCESS"; then
    echo "[auto-submit] Failed to attach build:"
    echo "$ATTACH_ERROR"
    echo "[auto-submit] You may need to manually select the build in App Store Connect"
    exit 0
fi

echo "[auto-submit] Build attached successfully"

# --- Submit for App Review ---

echo "[auto-submit] Submitting for App Review..."

SUBMIT_RESPONSE=$(curl -s -X POST -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{
        \"data\": {
            \"type\": \"appStoreVersionSubmissions\",
            \"relationships\": {
                \"appStoreVersion\": {
                    \"data\": {
                        \"type\": \"appStoreVersions\",
                        \"id\": \"${VERSION_ID}\"
                    }
                }
            }
        }
    }" \
    "${ASC_BASE}/appStoreVersionSubmissions")

SUBMIT_ERROR=$(echo "$SUBMIT_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
errors = data.get('errors', [])
if errors:
    for e in errors:
        print(f\"ERROR: {e.get('title', '')} - {e.get('detail', '')}\")
else:
    print('SUCCESS')
" 2>/dev/null)

if echo "$SUBMIT_ERROR" | grep -q "SUCCESS"; then
    echo "[auto-submit] Successfully submitted version ${VERSION} (build ${BUILD_NUMBER}) for App Review!"
else
    echo "[auto-submit] Failed to submit for review:"
    echo "$SUBMIT_ERROR"
    echo "[auto-submit] The build is attached to the version - you can manually submit in App Store Connect"
fi
