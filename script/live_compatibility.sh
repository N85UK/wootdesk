#!/usr/bin/env bash
#
# Runs opt-in compatibility tests against an isolated Chatwoot server that
# contains invented data only. Values are read without being echoed.
#
# Usage:
#   script/live_compatibility.sh
#   script/live_compatibility.sh --allow-writes --confirm-invented-data
#
set -euo pipefail

cd "$(dirname "$0")/.."

ALLOW_WRITES=0
CONFIRM_INVENTED_DATA=0
CREATED_TOKEN_FILE=""

cleanup_token_file() {
    if [[ -n "${CREATED_TOKEN_FILE}" && -f "${CREATED_TOKEN_FILE}" ]]; then
        rm -f -- "${CREATED_TOKEN_FILE}"
    fi
}

trap cleanup_token_file EXIT
for arg in "$@"; do
    case "$arg" in
        --allow-writes) ALLOW_WRITES=1 ;;
        --confirm-invented-data) CONFIRM_INVENTED_DATA=1 ;;
        -h|--help)
            sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

if [[ "${ALLOW_WRITES}" -ne "${CONFIRM_INVENTED_DATA}" ]]; then
    echo "Mutating checks require both --allow-writes and --confirm-invented-data." >&2
    exit 2
fi

read_required_value() {
    local variable_name="$1"
    local prompt="$2"
    local current_value="${!variable_name:-}"

    if [[ -n "${current_value}" ]]; then
        return
    fi
    if [[ ! -t 0 ]]; then
        echo "${variable_name} is required in non-interactive mode." >&2
        exit 2
    fi

    read -r -p "${prompt}: " current_value
    if [[ -z "${current_value}" ]]; then
        echo "${variable_name} cannot be empty." >&2
        exit 2
    fi
    export "${variable_name}=${current_value}"
}

read_required_value WOOTDESK_LIVE_BASE_URL "Dedicated Chatwoot HTTPS address"
read_required_value WOOTDESK_LIVE_ACCOUNT_ID "Invented-data account ID"
read_required_value WOOTDESK_LIVE_CONVERSATION_ID "Invented-data conversation ID"

if [[ -n "${WOOTDESK_LIVE_TOKEN_FILE:-}" ]]; then
    if [[ ! -f "${WOOTDESK_LIVE_TOKEN_FILE}" || ! -r "${WOOTDESK_LIVE_TOKEN_FILE}" ]]; then
        echo "WOOTDESK_LIVE_TOKEN_FILE must identify a readable file." >&2
        exit 2
    fi
else
    token_value="${WOOTDESK_LIVE_TOKEN:-}"
    if [[ -z "${token_value}" ]]; then
        if [[ ! -t 0 ]]; then
            echo "WOOTDESK_LIVE_TOKEN_FILE is required in non-interactive mode." >&2
            exit 2
        fi
        read -r -s -p "Dedicated test agent token: " token_value
        echo
    fi
    if [[ -z "${token_value}" ]]; then
        echo "The dedicated test agent token cannot be empty." >&2
        exit 2
    fi

    CREATED_TOKEN_FILE="$(mktemp "${TMPDIR:-/tmp}/wootdesk-live-token.XXXXXX")"
    chmod 600 "${CREATED_TOKEN_FILE}"
    printf '%s' "${token_value}" > "${CREATED_TOKEN_FILE}"
    export WOOTDESK_LIVE_TOKEN_FILE="${CREATED_TOKEN_FILE}"
    token_value=""
fi

unset WOOTDESK_LIVE_TOKEN

export WOOTDESK_LIVE_TESTS=1
export WOOTDESK_LIVE_ALLOW_WRITES="${ALLOW_WRITES}"
export WOOTDESK_LIVE_CONFIRM_INVENTED_DATA="${CONFIRM_INVENTED_DATA}"

# xcodebuild does not hand its own environment to the test process. Only
# variables prefixed with TEST_RUNNER_ are forwarded, with the prefix stripped.
# Exporting the bare names alone leaves WOOTDESK_LIVE_TESTS unset inside the
# tests, so all three skip themselves and this script still exits 0, which
# reads as a passing compatibility run that never contacted the server.
for live_variable in \
    WOOTDESK_LIVE_TESTS \
    WOOTDESK_LIVE_BASE_URL \
    WOOTDESK_LIVE_TOKEN_FILE \
    WOOTDESK_LIVE_ACCOUNT_ID \
    WOOTDESK_LIVE_CONVERSATION_ID \
    WOOTDESK_LIVE_ALLOW_WRITES \
    WOOTDESK_LIVE_CONFIRM_INVENTED_DATA
do
    export "TEST_RUNNER_${live_variable}=${!live_variable}"
done

if command -v xcodegen > /dev/null 2>&1; then
    xcodegen generate --spec project.yml
fi

xcodebuild test \
    -project WootDesk.xcodeproj \
    -scheme WootDesk \
    -destination "platform=macOS" \
    -only-testing:WootDeskTests/ChatwootLiveCompatibilityTests \
    -configuration Debug \
    -derivedDataPath "$(pwd)/build/live-compatibility" \
    -parallel-testing-enabled NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

exit 0
