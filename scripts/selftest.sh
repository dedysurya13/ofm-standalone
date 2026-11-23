#!/usr/bin/env bash
# Tes endpoint OFM: health, model list, dan satu chat completion.
#   ./scripts/selftest.sh
set -uo pipefail

CONTAINER="${CONTAINER:-ofm}"
PORT="${OFM_PORT:-18900}"
BASE="http://127.0.0.1:${PORT}"
HDR="Authorization: Bearer"

echo "=== 1. health =========================================="
if ! curl -fsS --max-time 10 "$BASE/health" 2>/dev/null; then
    echo "  GAGAL: $BASE/health tidak menjawab"
    echo "  Cek: docker logs $CONTAINER --tail 40"
    exit 1
fi
echo

echo "=== 2. API key ========================================"
KEY="$(bash "$(dirname "$0")/get-key.sh" "$CONTAINER" 2>/dev/null)"
if [ -z "$KEY" ]; then
    echo "  GAGAL: forwardKey tidak ditemukan"
    exit 1
fi
echo "  ${KEY:0:8}... (${#KEY} chars)"
echo

echo "=== 3. model list ====================================="
MODELS="$(curl -fsS --max-time 20 "$BASE/v1/models" -H "$HDR $KEY" 2>/dev/null)"
if [ -z "$MODELS" ]; then
    echo "  GAGAL: /v1/models tidak menjawab"
    exit 1
fi
echo "$MODELS" | head -c 1200
echo

echo "=== 4. chat completion ================================"
MODEL="$(printf '%s' "$MODELS" | grep -oE '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
if [ -z "$MODEL" ]; then
    echo "  SKIP: tidak ada model di daftar"
    exit 0
fi
echo "  model: $MODEL"

PAYLOAD="{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"reply with the single word: ok\"}],\"max_tokens\":20}"

curl -sS --max-time 90 "$BASE/v1/chat/completions" \
    -H "$HDR $KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" | head -c 1500

echo
echo
echo "Selesai."
