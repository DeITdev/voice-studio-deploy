# DGX Spark GPU VM — VoiceStudio Headless Backend & Model Engine (`dgx-gpu-vm`)

This folder is **100% self-contained** and runs the **VoiceStudio (`debpalash/voicestudio` v0.5.7) GPU Backend & Model Engine** on your **NVIDIA DGX Spark** VM (or any x86_64 NVIDIA CUDA server).

## Prerequisites on the DGX Spark VM

- Docker Engine + Docker Compose plugin
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) (pre-installed on NVIDIA DGX OS)

## Quick Start

1. Copy `.env.example` to `.env` and set a random `OMNIVOICE_API_KEY`:
   ```bash
   cp .env.example .env
   # Generate and set OMNIVOICE_API_KEY in .env:
   sed -i "s/change-me-to-a-long-random-secret-key/$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')/" .env
   ```
2. Create the persistent host directories and start the container:
   ```bash
   mkdir -p omnivoice_data models
   docker compose up -d --build
   ```

> **Note for NVIDIA DGX Spark (`linux/arm64` / GB10):**
> The `Dockerfile` automatically detects `TARGETARCH=arm64` and builds the official `cuda-arm64-base` stage (`ubuntu:24.04` + PyTorch 2.8.0 `cu129` wheels). On `aarch64`, use `pytorch-whisper` for GPU ASR transcription (since NVIDIA does not publish `aarch64` cuDNN 8 wheels for CTranslate2).

## Verify GPU & Health Status

```bash
curl http://localhost:3900/health
```

Expected response once startup completes:
```json
{
  "status": "ok",
  "device": "cuda",
  "version": "0.5.7"
}
```
During initial boot/migration, you can also check startup progress at:
```bash
curl http://localhost:3900/startup/progress
```

## Where Data & Models Are Stored

- `./omnivoice_data` (mounted to `/app/omnivoice_data`): Stores the SQLite database, voice profiles, projects, settings, and generated audio files.
- `./models` (mounted to `/app/omnivoice_data/huggingface`): Stores all downloaded Hugging Face TTS, ASR, and dubbing models.
