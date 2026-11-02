# VoiceStudio Split-VM Deployment Package (`voice-studio-deploy`)

This repository is **100% self-contained** for deploying **VoiceStudio** ([`debpalash/voicestudio`](https://github.com/debpalash/VoiceStudio) `v0.5.7`) across two separate VMs. You do **not** need to clone the full VoiceStudio monorepo onto either VM—simply copy the corresponding folder to each machine:

| Folder | Target Machine | What It Runs |
| :--- | :--- | :--- |
| [`dgx-gpu-vm/`](./dgx-gpu-vm/) | **VM 2: NVIDIA DGX Spark GPU VM** | Headless VoiceStudio FastAPI Backend (port `3900`) + PyTorch 2.8.0 CUDA (`cu129` on ARM64 DGX Spark / `cu128` on x86_64). Downloads and executes all TTS (OmniVoice, CosyVoice, etc.), Whisper ASR, dubbing, and translation models on the DGX GPU. |
| [`web-vm/`](./web-vm/) | **VM 1: Web UI VM (No GPU)** | Lightweight VoiceStudio Web UI (React 19 SPA built from `electron/vite.web.config.ts` + Nginx reverse proxy on port `17600`). Contains zero models and requires no GPU or Python. Connects to the DGX Spark VM over HTTP & WebSocket. |

---

## Step 1 — Deploy the VoiceStudio Backend & Model Engine on the DGX Spark GPU VM

1. Copy **only** the `dgx-gpu-vm/` folder to your DGX Spark VM:
   ```bash
   scp -r dgx-gpu-vm user@<DGX-SPARK-IP>:~/voicestudio-dgx
   ```
2. SSH into your DGX Spark VM, generate your `OMNIVOICE_API_KEY`, and start the container:
   ```bash
   cd ~/voicestudio-dgx
   cp .env.example .env
   # Generate a random administrator API key and save it into .env:
   API_KEY="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
   sed -i "s/change-me-to-a-long-random-secret-key/${API_KEY}/" .env
   echo "Your OMNIVOICE_API_KEY is: ${API_KEY}"

   mkdir -p omnivoice_data models
   docker compose up -d --build
   ```
3. Verify the DGX GPU is detected and the backend is healthy:
   ```bash
   curl http://localhost:3900/health
   ```
   You should see:
   ```json
   {"status":"ok","device":"cuda","version":"0.5.7"}
   ```

---

## Step 2 — Deploy the VoiceStudio Web UI on the Non-GPU VM

1. Copy **only** the `web-vm/` folder to your Web UI VM:
   ```bash
   scp -r web-vm user@<WEB-VM-IP>:~/voicestudio-web
   ```
2. SSH into your Web UI VM, set `DGX_BACKEND_URL` in `.env` to point to your DGX Spark VM IP (port `3900`), and start the container:
   ```bash
   cd ~/voicestudio-web
   cp .env.example .env
   # Edit .env and set: DGX_BACKEND_URL=http://<DGX-SPARK-IP>:3900
   docker compose up -d --build
   ```
3. Open `http://<WEB-VM-IP>:17600` in your browser:
   - Enter the `OMNIVOICE_API_KEY` from Step 1 when prompted.
   - Check **Settings → Performance & Device** to confirm the DGX Spark GPU is active.
   - Go to **Settings → Models** to install TTS, ASR, and dubbing models—all weights download directly into `~/voicestudio-dgx/models` on your **DGX Spark VM** and run on the DGX GPU.
