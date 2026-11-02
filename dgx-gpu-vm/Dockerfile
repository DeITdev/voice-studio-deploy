# ============================================================
# Voicebox Headless GPU Backend & Model Engine (NVIDIA DGX Spark)
# Runs ONLY the FastAPI Model & Inference Server (no Web UI bundled)
# Supports NVIDIA DGX Spark (ARM64 Grace Blackwell GB10) & x86_64 CUDA GPUs
# ============================================================

ARG PYTORCH_VARIANT=cuda
ARG CUDA_VERSION=cu128
ARG ROCM_VERSION=6.3

# === Stage 1: Build Python & CUDA dependencies ===
FROM python:3.12-slim AS backend-builder

ARG PYTORCH_VARIANT=cuda
ARG CUDA_VERSION=cu128
ARG ROCM_VERSION=6.3

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    cmake \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --upgrade pip

COPY backend/requirements.txt .

# Install GPU-accelerated PyTorch first so subsequent packages resolve against it.
# On NVIDIA DGX Spark (aarch64 + GB10 Blackwell), cu128 provides native ARM64 CUDA wheels.
RUN if [ "$PYTORCH_VARIANT" = "cuda" ]; then \
      pip install --no-cache-dir --prefix=/install \
        --index-url "https://download.pytorch.org/whl/${CUDA_VERSION}" \
        torch torchaudio && \
      printf '[global]\nindex-url = https://download.pytorch.org/whl/%s\nextra-index-url = https://pypi.org/simple\n' "$CUDA_VERSION" > /etc/pip.conf; \
    elif [ "$PYTORCH_VARIANT" = "rocm" ]; then \
      pip install --no-cache-dir --prefix=/install \
        --index-url "https://download.pytorch.org/whl/rocm${ROCM_VERSION}" \
        torch torchaudio && \
      printf '[global]\nindex-url = https://download.pytorch.org/whl/rocm%s\nextra-index-url = https://pypi.org/simple\n' "$ROCM_VERSION" > /etc/pip.conf; \
    fi

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
RUN pip install --no-cache-dir --prefix=/install --no-deps chatterbox-tts
RUN pip install --no-cache-dir --prefix=/install --no-deps hume-tada
RUN pip install --no-cache-dir --prefix=/install --no-deps omnivoice
RUN pip install --no-cache-dir --prefix=/install \
    git+https://github.com/QwenLM/Qwen3-TTS.git


# === Stage 2: Headless Backend Runtime ===
FROM python:3.12-slim

RUN groupadd -r voicebox && \
    useradd -r -g voicebox -m -s /bin/bash voicebox

RUN mkdir -p /home/voicebox/.cache/huggingface \
    && chown -R voicebox:voicebox /home/voicebox/.cache

WORKDIR /app

# Runtime dependencies:
# - ffmpeg & sox: audio decoding/normalization (Required by Qwen-TTS, Whisper, etc.)
# - gcc & g++: required by Triton JIT compiler on CUDA GPUs (including DGX Spark GB10)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    sox \
    gcc \
    g++ \
    curl \
    gosu \
    && rm -rf /var/lib/apt/lists/*

COPY --from=backend-builder /install /usr/local
COPY --chown=voicebox:voicebox backend/ /app/backend/

RUN mkdir -p /app/data/generations /app/data/profiles /app/data/captures /app/data/cache \
    && chown -R voicebox:voicebox /app/data

EXPOSE 17493

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD curl -f http://localhost:17493/health || exit 1

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "17493"]
