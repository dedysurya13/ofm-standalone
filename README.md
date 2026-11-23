# ofm-standalone — Our Free Model sebagai OpenAI-compatible gateway

Bungkus Docker untuk [`Ebony-Vinyl/dsh-our-free-model`](https://github.com/Ebony-Vinyl/dsh-our-free-model)
mode standalone. Hasilnya satu endpoint `http://127.0.0.1:18900/v1` yang bisa
dipakai 9Router atau klien OpenAI-compatible lain.

## Yang perlu dipahami dulu

Repo upstream **tidak menyediakan image siap pakai** dan juga tidak menerbitkan
paket npm standalone. Jadi container ini **meng-clone repo upstream saat build**,
lalu menjalankannya apa adanya. Konsekuensinya:

- Build pertama butuh network + ~330 MB
- Kalau upstream push update, lo perlu `--build` ulang untuk ikut
- Semua kode pihak ketiga (termasuk `vendor/channel-pack/pack.js`) ikut masuk
- Plugin ini punya auto-update sendiri dari `raw.githubusercontent.com` /
  `jsdelivr` — di container ini **dimatikan** lewat `OFM_DISABLE_SELF_UPDATE=1`
  supaya image tetap immutable

Kalau lo mau versi yang terkunci ke satu commit, set `OFM_REF` ke commit SHA.

## Arsitektur

```
9Router (Windows)
      │  SSH tunnel 18900
      ▼
127.0.0.1:18900  (container ofm)
      │
      ▼
opencode.ai  (jalur gratis anonim, header disamarkan)
```

Semua port bind ke `127.0.0.1` — akses dari luar wajib lewat SSH tunnel.

## Deploy

```bash
git clone https://github.com/dedysurya13/ofm-standalone.git
cd ofm-standalone
sudo docker compose up -d --build
```

Build pertama 3-5 menit (clone + install). Setelah selesai:

```bash
# ambil API key yang di-generate otomatis
sudo docker exec ofm cat /data/settings.json | python3 -c "import json,sys; print(json.load(sys.stdin)['forwardKey'])"
```

```bash
# verifikasi endpoint hidup (ganti KEY dengan hasil di atas)
curl -s http://127.0.0.1:18900/v1/models -H "Authorization: Bearer KEY" | head -40
```

```bash
# tes chat completion
curl -s http://127.0.0.1:18900/v1/chat/completions \
  -H "Authorization: Bearer KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-v4.1-flash","messages":[{"role":"user","content":"hi"}],"max_tokens":20}'
```

## Sambung ke 9Router

SSH tunnel dari Windows — tambahkan satu baris di `C:\Users\<nama>\.ssh\config`:

```
Host ofm
    HostName <IP_VPS>
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    LocalForward 18900 127.0.0.1:18900
```

```bash
# biarkan terminal terbuka
ssh -N ofm
```

Lalu di 9Router → Add Provider → OpenAI Compatible:

- **Base URL:** `http://127.0.0.1:18900/v1`
- **API Key:** isi `forwardKey` dari langkah di atas
- **Model:** lihat hasil `GET /v1/models`

## Perintah harian

```bash
# log
sudo docker logs -f ofm
```

```bash
# status + model yang tersedia
sudo docker exec ofm node -e "fetch('http://127.0.0.1:18900/health').then(r=>r.json()).then(j=>console.log(JSON.stringify(j,null,2)))"
```

```bash
# ambil ulang API key
sudo docker exec ofm cat /data/settings.json | grep -o '"forwardKey":"[^"]*"'
```

```bash
# restart
sudo docker compose restart ofm
```

## Kalau API key hilang / mau direset

Key tersimpan di volume `ofm-data`. Hapus file settings-nya, service akan
generate key baru saat start:

```bash
sudo docker compose down
sudo docker run --rm -v ofm-standalone_ofm-data:/data alpine sh -c "rm -f /data/settings.json"
sudo docker compose up -d
```

## Environment

| Variabel | Default | Keterangan |
| --- | --- | --- |
| `OFM_PORT` | `18900` | port listener |
| `OFM_HOME` | `/data` | direktori data (volume) |
| `OFM_REF` | `main` | branch/tag/commit upstream yang di-clone |
| `OFM_DISABLE_SELF_UPDATE` | `1` | matikan auto-update plugin |

## Catatan keamanan

- Port hanya di `127.0.0.1`, nggak terekspos ke internet
- Kredensial channel akun (kalau lo login Qoder/TRAE/dll) tersimpan **plaintext**
  di `/data/channel-credentials.json` — jangan taruh di host yang dipakai bareng
- Jalur gratis pakai kredensial anonim `Bearer public`, nggak ada akun lo yang
  dipertaruhkan; risikonya upstream bisa berubah kapan saja dan bikin rusak
- Image ini meng-clone `main` upstream, jadi `docker compose build` akan selalu
  ambil versi terbaru — pakai `OFM_REF` kalau mau reproducible

## Troubleshooting

```bash
# container restart terus — lihat kenapa
sudo docker logs ofm --tail 60
```

```bash
# port 18900 dipakai proses lain
sudo ss -tlnp | grep 18900
```

```bash
# upstream balas error / model kosong — tes jalur gratis langsung
sudo docker exec ofm node -e "
fetch('https://opencode.ai/inference/openai/v1/chat/completions',{
  method:'POST',
  headers:{'content-type':'application/json',authorization:'Bearer public','x-opencode-client':'cli'},
  body:JSON.stringify({model:'deepseek-v4.1-flash',messages:[{role:'user',content:'hi'}],max_tokens:10})
}).then(r=>r.text()).then(console.log)
"
```
