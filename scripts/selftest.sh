#!/usr/bin/env bash
# Tes endpoint OFM: siap? -> model list -> satu chat completion.
#   ./scripts/selftest.sh
set -uo pipefail

CONTAINER="${CONTAINER:-ofm}"
PORT="${OFM_PORT:-18900}"
BASE="http://127.0.0.1:${PORT}"
HDR="Authorization: Bearer"

# ---------------------------------------------------------------- 1. key ----
echo "=== 1. API key ========================================"
KEY="$(bash "$(dirname "$0")/get-key.sh" "$CONTAINER" 2>/dev/null)"
if [ -z "$KEY" ]; then
    echo "  GAGAL: forwardKey tidak ditemukan di settings.json"
    echo "  Cek: docker logs $CONTAINER --tail 40"
    exit 1
fi
echo "  ${KEY:0:8}... (${#KEY} chars)"

# --------------------------------------------------------------- 2. ready ---
# OFM tidak punya /health. Probe /v1/models: kalau 200, server hidup DAN
# key valid sekaligus. Kalau 401 -> server hidup tapi key salah.
echo "=== 2. server ========================================="
CODE="$(curl -s -o /tmp/.ofm_probe.$$ -w '%{http_code}' --max-time 20 \
        "$BASE/v1/models" -H "$HDR $KEY" 2>/dev/null)"
CODE="${CODE:-000}"

case "$CODE" in
    200) echo "  OK: /v1/models menjawab 200" ;;
    401|403)
        echo "  GAGAL: HTTP $CODE — server hidup, tapi key ditolak"
        echo "  Key terbaca: ${KEY:0:8}... (${#KEY} chars)"
        echo "  Cek ulang: cat <(docker exec $CONTAINER cat /data/settings.json)"
        rm -f /tmp/.ofm_probe.$$
        exit 1 ;;
    000)
        echo "  GAGAL: tidak bisa konek ke $BASE"
        echo "  Container hidup?  docker ps --filter name=$CONTAINER"
        echo "  Port terbuka?     ss -ltnp | grep $PORT"
        echo "  Log:              docker logs $CONTAINER --tail 40"
        rm -f /tmp/.ofm_probe.$$
        exit 1 ;;
    *)
        echo "  GAGAL: HTTP $CODE dari /v1/models"
        head -c 600 /tmp/.ofm_probe.$$ 2>/dev/null; echo
        rm -f /tmp/.ofm_probe.$$
        exit 1 ;;
esac

MODELS="$(cat /tmp/.ofm_probe.$$ 2>/dev/null)"
rm -f /tmp/.ofm_probe.$$

# --------------------------------------------------------------- 3. models --
echo "=== 3. model list ====================================="
echo "$MODELS" | head -c 1200
echo

# --------------------------------------------------------------- 4. chat ----
echo "=== 4. chat completion ================================"
MODEL="$(printf '%s' "$MODELS" | grep -oE '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
if [ -z "$MODEL" ]; then
    echo "  SKIP: tidak ada model di daftar"
    exit 0
fi
echo "  model: $MODEL"

PAYLOAD="{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"reply with the single word: ok\"}],\"max_tokens\":20}"

RESP="$(curl -sS --max-time 120 "$BASE/v1/chat/completions" \
    -H "$HDR $KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>&1)"
echo "$RESP" | head -c 1500

echo
if printf '%s' "$RESP" | grep -q '"choices"'; then
    echo
    echo "HASIL: OK — endpoint chat jalan."
else
    echo
    echo "HASIL: GAGAL — tidak ada \"choices\" di respons."
    echo "  Kalau isinya 401/429 dari upstream: channel akun belum login"
    echo "  atau kuota habis. Buka halaman login:"
    echo "  http://127.0.0.1:${PORT}/  (link #login=... ada di docker logs $CONTAINER)"
    exit 1
fi
