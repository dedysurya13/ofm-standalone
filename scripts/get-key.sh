#!/usr/bin/env bash
# Ambil API key (forwardKey) dari volume OFM.
#   ./scripts/get-key.sh
set -uo pipefail

CONTAINER="${1:-ofm}"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "container '$CONTAINER' tidak jalan. Jalankan: docker compose up -d" >&2
    exit 1
fi

KEY="$(docker exec "$CONTAINER" sh -c 'grep -o "\"forwardKey\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" /data/settings.json 2>/dev/null | sed -E "s/.*\"([^\"]*)\"$/\1/"')"

if [ -z "$KEY" ]; then
    echo "forwardKey belum ada. Cek log: docker logs $CONTAINER --tail 40" >&2
    exit 1
fi

echo "$KEY"
