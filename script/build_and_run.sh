#!/usr/bin/env bash
#
# Build and run WootDesk on macOS.
#
# Usage:
#   script/build_and_run.sh              Build and launch the app
#   script/build_and_run.sh --verify     Build, launch, and verify the app stays running
#   script/build_and_run.sh --no-launch  Build only
#   script/build_and_run.sh --debug      Build, then open the app executable in lldb
#   script/build_and_run.sh --logs       Build, launch, and stream process logs
#   script/build_and_run.sh --telemetry  Build, launch, and stream WootDesk subsystem logs
#
set -euo pipefail

cd "$(dirname "$0")/.."

VERIFY=0
LAUNCH=1
DEBUG=0
LOGS=0
TELEMETRY=0

for arg in "$@"; do
    case "$arg" in
        --verify) VERIFY=1 ;;
        --no-launch) LAUNCH=0 ;;
        --debug) DEBUG=1 ;;
        --logs) LOGS=1 ;;
        --telemetry) TELEMETRY=1 ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

echo "========================================="
echo " WootDesk: Build and Run (macOS)"
echo "========================================="

echo "-> Stopping any running WootDesk instance..."
killall WootDesk 2>/dev/null || true

if command -v xcodegen &> /dev/null; then
    echo "-> Regenerating the Xcode project with xcodegen..."
    xcodegen generate --spec project.yml
else
    echo "-> xcodegen not found; using the committed Xcode project."
fi

BUILD_DIR="$(pwd)/build/macos"
mkdir -p "${BUILD_DIR}"

# Ad-hoc signing is used so that the App Sandbox entitlements are actually applied
# to the local build. A fully unsigned build silently drops them.
echo "-> Building WootDesk for macOS..."
xcodebuild build \
    -project WootDesk.xcodeproj \
    -scheme WootDesk \
    -destination "platform=macOS" \
    -configuration Debug \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES

APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/Debug/WootDesk.app"
APP_BINARY="${APP_PATH}/Contents/MacOS/WootDesk"

if [[ ! -d "${APP_PATH}" ]]; then
    echo "Error: built application not found at ${APP_PATH}" >&2
    exit 1
fi

echo "-> Build succeeded: ${APP_PATH}"

if [[ "${LAUNCH}" -eq 0 ]]; then
    echo "-> Skipping launch (--no-launch)."
    exit 0
fi

if [[ "${DEBUG}" -eq 1 ]]; then
    echo "-> Opening WootDesk in lldb..."
    exec lldb -- "${APP_BINARY}"
fi

echo "-> Launching WootDesk..."
open "${APP_PATH}"

if [[ "${LOGS}" -eq 1 ]]; then
    echo "-> Streaming WootDesk process logs..."
    exec /usr/bin/log stream --info --style compact --predicate 'process == "WootDesk"'
fi

if [[ "${TELEMETRY}" -eq 1 ]]; then
    echo "-> Streaming WootDesk subsystem logs..."
    exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "dev.n85.wootdesk"'
fi

if [[ "${VERIFY}" -eq 1 ]]; then
    echo "-> Verifying the app is running..."
    for _ in $(seq 1 10); do
        if pgrep -x WootDesk > /dev/null; then
            echo "   WootDesk is running (pid $(pgrep -x WootDesk | head -1))."
            echo "-> Verifying the sandbox entitlements were applied..."
            codesign -d --entitlements - "${APP_PATH}" 2>&1 | grep -q "app-sandbox" \
                && echo "   App Sandbox entitlement present." \
                || { echo "   Error: App Sandbox entitlement missing." >&2; exit 1; }
            echo "-> Verification passed."
            exit 0
        fi
        sleep 1
    done
    echo "Error: WootDesk did not stay running after launch." >&2
    exit 1
fi

echo "-> WootDesk launched."
