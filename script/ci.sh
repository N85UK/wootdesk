#!/usr/bin/env bash
#
# Repeatable local and CI checks for WootDesk.
#
# Runs entirely offline: no Chatwoot server, no credentials, and no signing
# identity are required.
#
# Usage:
#   script/ci.sh                Toolchain info, macOS build, iOS Simulator build, unit tests
#   script/ci.sh --with-ui-tests  Stop WootDesk, then run ad-hoc signed macOS UI tests
#
set -euo pipefail

cd "$(dirname "$0")/.."

WITH_UI_TESTS=0
for arg in "$@"; do
    case "$arg" in
        --with-ui-tests) WITH_UI_TESTS=1 ;;
        -h|--help)
            sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

PROJECT="WootDesk.xcodeproj"
SCHEME="WootDesk"
UNSIGNED=(CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO)
BUILD_ROOT="$(pwd)/build/ci"

echo "========================================="
echo " WootDesk: Continuous Integration Checks"
echo "========================================="

echo "--- Environment ---"
xcodebuild -version
swift --version
echo "-------------------"

if command -v xcodegen &> /dev/null; then
    echo "-> Regenerating the Xcode project with xcodegen..."
    xcodegen generate --spec project.yml
else
    echo "-> xcodegen not found; using the committed Xcode project."
fi

echo "-> Listing project schemes..."
xcodebuild -list -project "${PROJECT}"

echo "-> Building the macOS application..."
xcodebuild build \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination "generic/platform=macOS" \
    -configuration Debug \
    -derivedDataPath "${BUILD_ROOT}/macos" \
    "${UNSIGNED[@]}"

echo "-> Building for the iOS Simulator..."
xcodebuild build \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination "generic/platform=iOS Simulator" \
    -configuration Debug \
    -derivedDataPath "${BUILD_ROOT}/ios-simulator" \
    "${UNSIGNED[@]}"

echo "-> Running unit tests on macOS..."
xcodebuild test \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination "platform=macOS" \
    -only-testing:WootDeskTests \
    -configuration Debug \
    -derivedDataPath "${BUILD_ROOT}/unit-tests" \
    -parallel-testing-enabled NO \
    "${UNSIGNED[@]}"

if [[ "${WITH_UI_TESTS}" -eq 1 ]]; then
    if command -v automationmodetool > /dev/null 2>&1; then
        automation_status="$(automationmodetool)"
        if [[ "${automation_status}" == *"requires user authentication"* ]]; then
            echo "macOS UI automation requires one-time administrator configuration." >&2
            echo "See docs/MACOS_UI_TESTING.md before running --with-ui-tests." >&2
            exit 3
        fi
    fi

    # macOS UI tests need a signed runner: an unsigned test runner is killed
    # before it can connect. Ad-hoc signing is enough and needs no certificate.
    # A running copy with the same bundle identifier can intercept the launch.
    echo "-> Stopping any running WootDesk instance before UI tests..."
    running_pids="$(pgrep -x WootDesk || true)"
    if [[ -n "${running_pids}" ]]; then
        kill ${running_pids}
        for _ in {1..20}; do
            if ! pgrep -x WootDesk > /dev/null; then
                break
            fi
            sleep 0.1
        done
    fi
    if pgrep -x WootDesk > /dev/null; then
        echo "A running WootDesk process could not be stopped for UI testing." >&2
        exit 1
    fi

    echo "-> Running macOS UI tests (ad-hoc signed)..."
    xcodebuild test \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination "platform=macOS" \
        -only-testing:WootDeskUITests \
        -configuration Debug \
        -derivedDataPath "${BUILD_ROOT}/ui-tests" \
        -parallel-testing-enabled NO \
        CODE_SIGN_ENTITLEMENTS="WootDesk/Resources/WootDesk-Local.entitlements" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=YES \
        CODE_SIGNING_ALLOWED=YES
else
    echo "-> Skipping UI tests. Pass --with-ui-tests to include them."
fi

echo "========================================="
echo " All WootDesk CI checks passed."
echo "========================================="
