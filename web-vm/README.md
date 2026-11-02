# Web UI VM — Voice Studio Frontend (`web-vm`)

This folder contains everything needed to run the **Voice Studio Web UI** in a lightweight Docker container on a VM **with no GPU**.

## How It Works

1. Builds the React Voice Studio SPA (`app/` + `web/`) using `oven/bun:1`.
2. Serves the static Web UI via `nginx:1.27-alpine` on port `17600` (configurable via `WEB_PORT` in `.env`).
3. Reverse-proxies `/api/*` requests (including real-time Server-Sent Events for model downloads and TTS generation) directly to `DGX_BACKEND_URL` on your NVIDIA DGX Spark GPU VM.

## Quick Start

1. Create your `.env` file and set `DGX_BACKEND_URL` to the IP address of your DGX Spark VM:
   ```bash
   cp .env.example .env
   nano .env
   ```
   Example `.env`:
   ```env
   DGX_BACKEND_URL=http://192.168.1.100:17493
   WEB_PORT=17600
   FRONTEND_SERVER_URL=/api
   ```
2. Build and start the container:
   ```bash
   docker compose up -d --build
   ```
3. Open `http://<WEB-VM-IP>:17600` in your browser.
