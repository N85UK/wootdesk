#!/usr/bin/env bash
#
# Runs the dedicated invented-data Chatwoot server used for WootDesk
# compatibility acceptance.
#
# Usage:
#   script/compat_env.sh up       Create .env if absent, start the stack
#   script/compat_env.sh seed     Load the invented records and print the IDs
#   script/compat_env.sh status   Show container and reachability state
#   script/compat_env.sh reset    Destroy all data and volumes
#   script/compat_env.sh down     Stop the stack, keep the data
#   script/compat_env.sh trust    Print how to trust the local Caddy CA
#
# This stack holds invented records only. Never point it at a production
# Chatwoot database or object store, and never seed it from real data.
#
set -euo pipefail

cd "$(dirname "$0")/.."

COMPOSE=(docker compose -f compat/docker-compose.yml --env-file compat/.env)
ENV_FILE="compat/.env"
TOKEN_FILE="compat/.token"

ensure_env() {
    [[ -f "${ENV_FILE}" ]] && return 0

    echo "-> Creating ${ENV_FILE} with freshly generated local secrets..."
    local secret_key_base postgres_password redis_password
    secret_key_base="$(openssl rand -hex 64)"
    postgres_password="$(openssl rand -hex 24)"
    redis_password="$(openssl rand -hex 24)"

    sed \
        -e "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=${secret_key_base}|" \
        -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${postgres_password}|" \
        -e "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=${redis_password}|" \
        -e "s|^REDIS_URL=.*|REDIS_URL=redis://:${redis_password}@redis:6379|" \
        compat/.env.example > "${ENV_FILE}"
    chmod 600 "${ENV_FILE}"
    echo "   Generated. These secrets are local to this throwaway server."
}

case "${1:-}" in
    up)
        ensure_env
        echo "-> Starting the compatibility stack..."
        "${COMPOSE[@]}" up -d
        echo ""
        echo "Chatwoot is starting. First boot runs migrations and can take several minutes."
        echo "Watch progress with: docker compose -f compat/docker-compose.yml logs -f rails"
        echo "Then run: script/compat_env.sh seed"
        ;;
    seed)
        [[ -f "${ENV_FILE}" ]] || { echo "Run 'script/compat_env.sh up' first." >&2; exit 2; }
        echo "-> Loading invented records..."
        "${COMPOSE[@]}" cp compat/seed_invented_data.rb rails:/app/seed_invented_data.rb
        "${COMPOSE[@]}" exec -T rails bundle exec rails runner /app/seed_invented_data.rb | tee /tmp/compat-seed.out
        echo "-> Copying the access token out to ${TOKEN_FILE}..."
        "${COMPOSE[@]}" exec -T rails cat /app/storage/wootdesk-compat-token > "${TOKEN_FILE}"
        chmod 600 "${TOKEN_FILE}"
        echo ""
        echo "Trust the Caddy CA first, or every check fails with tlsFailure:"
        echo "  script/compat_env.sh trust"
        echo ""
        echo "Then run the compatibility checks through the script, which"
        echo "forwards the settings to the test process correctly:"
        echo "  WOOTDESK_LIVE_BASE_URL=https://wootdesk-compat.localhost:8443 \\"
        echo "  WOOTDESK_LIVE_TOKEN_FILE=$(pwd)/${TOKEN_FILE} \\"
        echo "  WOOTDESK_LIVE_ACCOUNT_ID=<ACCOUNT_ID from above> \\"
        echo "  WOOTDESK_LIVE_CONVERSATION_ID=<CONVERSATION_ID from above> \\"
        echo "  script/live_compatibility.sh --allow-writes --confirm-invented-data"
        ;;
    status)
        "${COMPOSE[@]}" ps
        echo ""
        echo "-> Reachability:"
        curl -sS -o /dev/null -w "   HTTPS %{http_code} in %{time_total}s\n" \
            "https://wootdesk-compat.localhost:${COMPAT_HTTPS_PORT:-8443}/api" \
            || echo "   Not reachable yet, or the local CA is not trusted. See 'trust'."
        ;;
    trust)
        cat <<'TRUST'
The stack serves HTTPS from Caddy's local certificate authority. WootDesk
requires system-trusted certificates, so trust that CA once:

  docker compose -f compat/docker-compose.yml cp caddy:/data/caddy/pki/authorities/local/root.crt /tmp/compat-root.crt
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/compat-root.crt

Remove it when the compatibility run is finished:

  sudo security delete-certificate -c "Caddy Local Authority" /Library/Keychains/System.keychain
TRUST
        ;;
    reset)
        echo "-> Destroying the compatibility stack and all of its data..."
        "${COMPOSE[@]}" down -v
        rm -f "${TOKEN_FILE}"
        echo "   Done. Run 'up' then 'seed' for a clean server."
        ;;
    down)
        "${COMPOSE[@]}" down
        ;;
    *)
        sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
