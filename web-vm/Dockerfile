# ============================================================
# Voicebox Web Studio UI (Frontend-Only Container)
# Runs on the Non-GPU App VM and connects to the DGX Spark GPU VM
# ============================================================

# === Stage 1: Build React SPA ===
FROM oven/bun:1 AS frontend-builder

WORKDIR /build

COPY package.json bun.lock CHANGELOG.md ./
COPY app/ ./app/
COPY web/ ./web/

# Normalize line endings and strip desktop (tauri) workspace for web-only build
RUN sed -i 's/\r$//' package.json && \
    sed -i '/"tauri"/d' package.json && \
    sed -i -z 's/,\n  ]/\n  ]/' package.json

RUN bun install --no-save
RUN cd web && bunx --bun vite build


# === Stage 2: Lightweight Nginx Web & Reverse Proxy Runtime ===
FROM nginx:1.27-alpine

RUN apk add --no-cache curl gettext

# Copy built static SPA assets
COPY --from=frontend-builder /build/web/dist /usr/share/nginx/html

# Copy Nginx reverse-proxy template (rendered by entrypoint.sh after sanitizing DGX_BACKEND_URL)
COPY nginx.conf.template /etc/nginx/voicebox.conf.template

# Copy startup hook that writes /usr/share/nginx/html/config.js and /etc/nginx/conf.d/default.conf
COPY --chmod=755 entrypoint.sh /docker-entrypoint.d/40-voicebox-config.sh
RUN sed -i 's/\r$//' /docker-entrypoint.d/40-voicebox-config.sh /etc/nginx/voicebox.conf.template

ENV DGX_BACKEND_URL=http://127.0.0.1:17493
ENV FRONTEND_SERVER_URL=/api

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -fsS http://127.0.0.1:80/ >/dev/null || exit 1
