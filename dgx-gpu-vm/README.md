# DGX Spark GPU VM — Headless Backend & Model Engine (`dgx-gpu-vm`)

This folder contains everything needed to run the **Voicebox GPU Backend & Model Engine** on your **NVIDIA DGX Spark** VM (or any NVIDIA CUDA server) without cloning the full repository.

## Prerequisites on the DGX Spark VM

- Docker Engine + Docker Compose plugin
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) (pre-installed on NVIDIA DGX OS)

## Quick Start

```bash
cp .env.example .env
mkdir -p models data
docker compose up -d --build
```

## Verify GPU & Health Status

```bash
curl http://localhost:17493/health
```

Expected response:
```json
{
  "status": "healthy",
  "gpu_available": true,
  "gpu_type": "CUDA (NVIDIA GB10 ...)"
}
```

## Where Models Are Stored

- `./models` (mounted to `/home/voicebox/.cache/huggingface` inside the container): Stores all downloaded **TTS**, **Whisper ASR**, and **Qwen3 LLM** models.
- `./data` (mounted to `/app/data` inside the container): Stores voice profiles, reference audio samples, captures, SQLite database, and generated audio files.
- If you already have a shared model directory on the DGX host, edit `MODELS_HOST_DIR=/path/to/your/models` in `.env`.
