FROM node:22-bookworm-slim

ARG OFM_REPO=https://github.com/Ebony-Vinyl/dsh-our-free-model.git
ARG OFM_REF=main

ENV DEBIAN_FRONTEND=noninteractive
ENV OFM_HOME=/data
ENV OFM_PORT=18900
ENV NODE_ENV=production

# git untuk clone upstream; ca-certificates + curl untuk probe
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates curl tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/ofm

# Clone upstream. Repo besar (~330 MB) — layer ini di-cache selama OFM_REF
# tidak berubah, jadi rebuild berikutnya cepat.
RUN git clone --depth 1 --branch "${OFM_REF}" "${OFM_REPO}" . \
    && rm -rf .git

# Upstream declares zero dependencies, but keep the step so a future
# package.json with deps still installs cleanly.
RUN if [ -f package.json ]; then npm install --omit=dev --no-audit --no-fund || true; fi

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/data"]
EXPOSE 18900

HEALTHCHECK --interval=60s --timeout=15s --start-period=120s --retries=3 \
    CMD curl -fsS --max-time 10 "http://127.0.0.1:${OFM_PORT}/health" >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
