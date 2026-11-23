#!/usr/bin/env bash
# Entrypoint: jalankan standalone service OFM, teruskan log ke stdout.
set -uo pipefail

: "${OFM_HOME:=/data}"
: "${OFM_PORT:=18900}"

mkdir -p "$OFM_HOME"

echo "[ofm] data dir : $OFM_HOME"
echo "[ofm] port     : $OFM_PORT"

# Auto-update plugin dimatikan: image harus immutable, update lewat rebuild.
export OFM_DISABLE_SELF_UPDATE="${OFM_DISABLE_SELF_UPDATE:-1}"

# API key di-generate sendiri oleh service dan disimpan di settings.json.
# Cetak setelah service hidup supaya kelihatan di log (bukan nilai rahasia
# baru kalau sudah ada — hanya dibaca ulang).
if [ -f "$OFM_HOME/settings.json" ]; then
    echo "[ofm] settings.json sudah ada, memakai forwardKey yang tersimpan"
else
    echo "[ofm] settings.json belum ada, key akan di-generate saat start"
fi

cd /opt/ofm || { echo "[ofm] FATAL: /opt/ofm tidak ada"; exit 1; }

exec node packages/standalone/cli.mjs --port "$OFM_PORT" --data-dir "$OFM_HOME"
