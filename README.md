# Voicebox Split-VM Deployment Package (`deploy-split-vm`)

This directory is **100% self-contained**. You do **not** need to clone the full Voicebox repository onto either of your VMs—simply copy the corresponding folder to each VM:

| Folder | Target Machine | What It Runs |
| :--- | :--- | :--- |
| [`dgx-gpu-vm/`](./dgx-gpu-vm/) | **VM 2: NVIDIA DGX Spark GPU VM** | Headless FastAPI Backend + PyTorch CUDA (`cu128`). Downloads and executes all TTS, Whisper ASR, and Dictation/LLM models on the DGX GPU. |
| [`web-vm/`](./web-vm/) | **VM 1: Web UI VM (No GPU)** | Lightweight Voice Studio Web UI (React SPA + Nginx). Contains zero models and requires no GPU or Python. Connects to the DGX Spark VM over HTTP. |

---

## Step 1 — Deploy the Model & Inference Backend on the DGX Spark GPU VM

1. Copy **only** the `dgx-gpu-vm/` folder to your DGX Spark VM:
   ```bash
   scp -r deploy-split-vm/dgx-gpu-vm user@<DGX-SPARK-IP>:~/voicebox-dgx
   ```
2. SSH into your DGX Spark VM and start the container:
   ```bash
   cd ~/voicebox-dgx
   cp .env.example .env
   mkdir -p models data
   docker compose up -d --build
   ```
3. Verify the DGX GPU is detected:
   ```bash
   curl http://localhost:17493/health
   ```
   You should see `"status": "healthy"`, `"gpu_available": true`, and `"gpu_type": "CUDA (...)"`.

---

## Step 2 — Deploy the Voice Studio Web UI on the Non-GPU VM

1. Copy **only** the `web-vm/` folder to your Web UI VM:
   ```bash
   scp -r deploy-split-vm/web-vm user@<WEB-VM-IP>:~/voicebox-web
   ```
2. SSH into your Web UI VM, set `DGX_BACKEND_URL` in `.env` to point to your DGX Spark VM IP, and start the container:
   ```bash
   cd ~/voicebox-web
   cp .env.example .env
   # Edit .env and set: DGX_BACKEND_URL=http://<DGX-SPARK-IP>:17493
   docker compose up -d --build
   ```
3. Open `http://<WEB-VM-IP>:17600` in your browser:
   - Go to **Settings → General** to confirm the status badge shows **Connected**.
   - Go to **Models** and click **Download** on any TTS, Whisper ASR, or Qwen3 LLM model—the models will download directly into `~/voicebox-dgx/models` on your **DGX Spark VM** and run on the DGX GPU.
