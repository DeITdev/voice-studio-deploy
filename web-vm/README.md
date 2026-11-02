# Web UI VM — VoiceStudio Frontend (`web-vm`)

This folder is **100% self-contained** and runs the **VoiceStudio (`debpalash/voicestudio` v0.5.7) Web UI** in a lightweight Docker container on a VM **with no GPU**.

## How It Works

1. Builds the official VoiceStudio React 19 SPA (`electron/` workspace via `vite.web.config.ts`) using `oven/bun:1.4.2-alpine`.
2. Serves the static Web UI via `nginx:1.27-alpine` on port `17600` (configurable via `WEB_PORT` in `.env`).
3. Injects `window.__OMNIVOICE_API_BASE__ = "/api"` (with its matching SHA-256 Content-Security-Policy hash) into `index.html` at container startup.
4. Reverse-proxies `/api/*` (HTTP, SSE streams, and WebSockets `/ws/events`, `/ws/transcribe`, `/ws/tts`) plus `/audio/*`, `/voice_audio/*`, `/demo_audio/*`, and `/v1/*` directly to `DGX_BACKEND_URL` (port `3900`) on your NVIDIA DGX Spark GPU VM.

## Quick Start

1. Create your `.env` file and set `DGX_BACKEND_URL` to the IP address of your DGX Spark VM:
   ```bash
   cp .env.example .env
   nano .env
   ```
   Example `.env`:
   ```env
   DGX_BACKEND_URL=http://192.168.1.100:3900
   WEB_PORT=17600
   FRONTEND_API_BASE=/api
   ```
2. Build and start the container:
   ```bash
   docker compose up -d --build
   ```
3. Open `http://<WEB-VM-IP>:17600` in your browser and sign in with the `OMNIVOICE_API_KEY` configured on your DGX Spark VM.
