#!/usr/bin/env bash
#
# Creates signed WootDesk release archives and App Store packages.
#
# This script never uploads. Uploading requires an explicit current
# authorisation naming the build, which is recorded against the release story
# rather than assumed by tooling.
#
# Usage:
#   script/release_archive.sh --team <TEAM_ID> [--platform ios|macos|all]
#   script/release_archive.sh --preflight-only --team <TEAM_ID>
#
# The preflight checks the signing assets before spending time on a build, and
# reports the exact missing capability rather than a generic signing failure.
#
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="WootDesk.xcodeproj"
SCHEME="WootDesk"
BUNDLE_ID="dev.n85.wootdesk"
ARCHIVE_ROOT="$(pwd)/build/release"
TEAM_ID="${DEVELOPMENT_TEAM:-}"
PLATFORM="all"
PREFLIGHT_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --team) TEAM_ID="$2"; shift 2 ;;
        --platform) PLATFORM="$2"; shift 2 ;;
        --preflight-only) PREFLIGHT_ONLY=1; shift ;;
        -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [[ -z "${TEAM_ID}" ]]; then
    echo "A development team is required. Pass --team <TEAM_ID> or set DEVELOPMENT_TEAM." >&2
    echo "The team identifier is deliberately not committed, so a clean clone builds unsigned." >&2
    exit 2
fi

fail() {
    echo "" >&2
    echo "PREFLIGHT FAILED: $1" >&2
    shift
    for line in "$@"; do echo "  $line" >&2; done
    echo "" >&2
    exit 3
}

# The app declares the Push Notifications capability. A distribution profile
# without the aps-environment entitlement cannot sign it, and automatic signing
# silently falls back to a development profile, which produces an archive that
# App Store Connect rejects. The preflight catches that here instead.
require_push_capable_profile() {
    local wanted_platform="$1"
    local profile_dir="${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles"
    local found_any=0
    local found_push=0
    local found_names=""

    [[ -d "${profile_dir}" ]] || fail "No provisioning profiles are installed." \
        "Install the ${wanted_platform} App Store distribution profile for ${BUNDLE_ID}."

    local decoded
    decoded="$(mktemp)"
    for profile in "${profile_dir}"/*; do
        [[ -f "${profile}" ]] || continue
        security cms -D -i "${profile}" > "${decoded}" 2>/dev/null || continue
        # iOS profiles use "application-identifier"; macOS profiles use
        # "com.apple.application-identifier". `|| true` keeps a non-matching
        # profile from ending the run under `set -o pipefail`.
        local app_id
        app_id="$(plutil -p "${decoded}" 2>/dev/null | grep -iE '"(com\.apple\.)?application-identifier"' | head -1 | sed 's/.*=> "//;s/"//' || true)"
        case "${app_id}" in *"${BUNDLE_ID}") ;; *) continue ;; esac

        # An App Store distribution profile lists no provisioned devices and is
        # not an enterprise profile. `get-task-allow` is not a reliable
        # discriminator here, because a development profile can carry it as
        # false while still being a development profile.
        if plutil -p "${decoded}" 2>/dev/null | grep -q "ProvisionedDevices"; then
            continue
        fi
        if plutil -p "${decoded}" 2>/dev/null | grep -q "ProvisionsAllDevices"; then
            continue
        fi
        # A macOS profile for a given platform should not be offered as an iOS
        # one and the reverse, so the file extension selects the platform.
        case "${wanted_platform}:${profile##*.}" in
            iOS:mobileprovision|macOS:provisionprofile) ;;
            *) continue ;;
        esac
        found_any=1
        local name
        name="$(plutil -extract Name raw "${decoded}" 2>/dev/null || echo "unnamed")"
        found_names="${found_names}${name}; "
        if plutil -p "${decoded}" 2>/dev/null | grep -qi '"aps-environment"'; then
            found_push=1
        fi
    done
    rm -f "${decoded}"

    if [[ "${found_any}" -eq 0 ]]; then
        fail "No ${wanted_platform} distribution provisioning profile is installed for ${BUNDLE_ID}." \
            "Create an App Store distribution profile for ${BUNDLE_ID} with Push Notifications enabled," \
            "download it, and run this script again."
    fi

    if [[ "${found_push}" -eq 0 ]]; then
        fail "The installed ${wanted_platform} distribution profile does not include the Push Notifications capability." \
            "Installed distribution profiles for ${BUNDLE_ID}: ${found_names}" \
            "WootDesk declares aps-environment, so signing will fall back to a development" \
            "profile and produce an archive App Store Connect rejects." \
            "" \
            "These profiles are Xcode-managed, so they are refreshed by Xcode rather than" \
            "downloaded from the developer portal. That needs a signed-in Apple Developer" \
            "account: open Xcode, Settings, Accounts and add the account for this team," \
            "then run this script again." \
            "" \
            "If it still fails, confirm Push Notifications on the App ID at" \
            "developer.apple.com/account/resources/identifiers."
    fi
}

echo "-> Checking signing identities..."
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Distribution"; then
    fail "No Apple Distribution signing identity with an accessible private key was found." \
        "Install the distribution certificate and its private key in the login keychain."
fi
echo "   Apple Distribution identity present."

case "${PLATFORM}" in
    ios|all) echo "-> Checking the iOS distribution profile..."; require_push_capable_profile "iOS" ;;
esac
case "${PLATFORM}" in
    macos|all) echo "-> Checking the macOS distribution profile..."; require_push_capable_profile "macOS" ;;
esac
echo "   Distribution profiles satisfy the declared capabilities."

if [[ "${PREFLIGHT_ONLY}" -eq 1 ]]; then
    echo ""
    echo "Preflight passed. Re-run without --preflight-only to create the archives."
    exit 0
fi

mkdir -p "${ARCHIVE_ROOT}"

export_options() {
    local destination_plist="$1"
    cat > "${destination_plist}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST
}

archive_platform() {
    local label="$1"
    local destination="$2"
    local archive_path="${ARCHIVE_ROOT}/WootDesk-${label}.xcarchive"
    local export_path="${ARCHIVE_ROOT}/WootDesk-${label}-export"
    local options_plist="${ARCHIVE_ROOT}/ExportOptions-${label}.plist"

    echo ""
    echo "-> Archiving ${label}..."
    rm -rf "${archive_path}" "${export_path}"
    xcodebuild archive \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination "${destination}" \
        -configuration Release \
        -archivePath "${archive_path}" \
        -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="${TEAM_ID}"

    echo "-> Verifying the ${label} archive was signed for distribution..."
    local app
    app="$(find "${archive_path}/Products" -maxdepth 3 -name "WootDesk.app" | head -1)"
    [[ -n "${app}" ]] || fail "The ${label} archive contains no WootDesk.app."

    local entitlements
    entitlements="$(codesign -d --entitlements :- "${app}" 2>/dev/null | plutil -p - 2>/dev/null || true)"
    if echo "${entitlements}" | grep -q '"get-task-allow" => 1'; then
        fail "The ${label} archive is signed for development, not distribution." \
            "get-task-allow is present, so App Store Connect will reject it." \
            "This usually means automatic signing fell back to a development profile."
    fi
    if echo "${entitlements}" | grep -qi '"aps-environment" => "development"'; then
        fail "The ${label} archive carries the development push environment." \
            "A distributed build must use the production aps-environment."
    fi
    echo "   ${label} archive is distribution signed."

    echo "-> Exporting the ${label} App Store package..."
    export_options "${options_plist}"
    xcodebuild -exportArchive \
        -archivePath "${archive_path}" \
        -exportOptionsPlist "${options_plist}" \
        -exportPath "${export_path}" \
        -allowProvisioningUpdates
    echo "   Exported to ${export_path}"
}

case "${PLATFORM}" in
    ios) archive_platform "iOS" "generic/platform=iOS" ;;
    macos) archive_platform "macOS" "generic/platform=macOS" ;;
    all)
        archive_platform "iOS" "generic/platform=iOS"
        archive_platform "macOS" "generic/platform=macOS"
        ;;
    *) echo "Unknown platform: ${PLATFORM}" >&2; exit 2 ;;
esac

cat <<'DONE'

=========================================
 Archives created and exported.

 This script does not upload. Uploading requires an explicit current
 authorisation naming this build, recorded against the release story, plus
 App Store Connect credentials held by the release owner.
=========================================
DONE
