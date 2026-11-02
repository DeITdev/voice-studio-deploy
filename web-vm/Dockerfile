# ============================================================
# VoiceStudio Web UI (Frontend-Only Container)
# Based on official debpalash/voicestudio deploy/Dockerfile frontend stage
# Runs on the Non-GPU Web VM and connects to the DGX Spark GPU VM (port 3900)
# ============================================================

# === Stage 1: Build VoiceStudio React 19 SPA ===
FROM oven/bun:1.4.2-alpine AS frontend-builder
WORKDIR /app

# Monorepo — bun workspace with lockfile at root
COPY package.json bun.lock ./
COPY electron/package.json ./electron/
COPY patches/ ./patches/
COPY config/ ./config/

RUN bun install --frozen-lockfile

# Build the maintained VoiceStudio renderer as the browser UI (-> /app/frontend/dist)
COPY frontend/ ./frontend/
COPY electron/ ./electron/
RUN bun run --cwd electron build:web


# === Stage 2: Lightweight Nginx Web & Reverse Proxy Runtime ===
FROM nginx:1.27-alpine

RUN apk add --no-cache curl gettext openssl

# Copy built static SPA assets
COPY --from=frontend-builder /app/frontend/dist /usr/share/nginx/html
RUN cp /usr/share/nginx/html/index.html /usr/share/nginx/html/index.html.orig

# Copy Nginx reverse-proxy template (rendered by entrypoint.sh after sanitizing DGX_BACKEND_URL)
COPY nginx.conf.template /etc/nginx/voicestudio.conf.template

# Copy startup hook that injects window.__OMNIVOICE_API_BASE__ + CSP sha256 into index.html
COPY --chmod=755 entrypoint.sh /docker-entrypoint.d/40-voicestudio-config.sh
RUN sed -i 's/\r$//' /docker-entrypoint.d/40-voicestudio-config.sh /etc/nginx/voicestudio.conf.template

ENV DGX_BACKEND_URL=http://127.0.0.1:3900
ENV FRONTEND_API_BASE=/api

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -fsS http://127.0.0.1:80/ >/dev/null || exit 1
