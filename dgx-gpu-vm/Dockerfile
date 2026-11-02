# ============================================================
# VoiceStudio Headless GPU Backend & Model Engine (NVIDIA DGX Spark)
# Based on official debpalash/voicestudio deploy/Dockerfile
# Runs ONLY the FastAPI Model & Inference Server (port 3900)
# Automatically selects:
#   - linux/arm64 (NVIDIA DGX Spark GB10 / GH200 / GB200) -> cuda-arm64-base (Ubuntu 24.04 + PyTorch 2.8.0 cu129)
#   - linux/amd64 (x86_64 NVIDIA CUDA GPUs)               -> cuda-amd64-base (pytorch:2.8.0-cuda12.8-cudnn9-runtime)
# ============================================================

ARG TARGETARCH=arm64
ARG BASE_IMAGE=cuda-${TARGETARCH}-base

# ==========================================
# amd64 NVIDIA CUDA base (x86_64 servers)
# ==========================================
FROM pytorch/pytorch:2.8.0-cuda12.8-cudnn9-runtime AS cuda-amd64-base

# ==========================================
# arm64 NVIDIA CUDA base (NVIDIA DGX Spark / GB10, GH200, GB200)
# ==========================================
# PyTorch's cu128 index has no aarch64 2.8.0 build; cu129 has all three wheels
# for cp312 and bundles CUDA + cuDNN 9 libraries natively for linux/arm64.
FROM ubuntu:24.04 AS cuda-arm64-base
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-dev \
    python3-pip \
    pkg-config \
    cmake \
    libopus-dev \
    && rm -rf /var/lib/apt/lists/*
RUN python3 -m pip install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/cu129 \
    torch==2.8.0+cu129 torchaudio==2.8.0 torchvision==0.23.0

# ==========================================
# Runtime Stage: Python & PyTorch Backend
# ==========================================
FROM ${BASE_IMAGE} AS runtime
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV OMNIVOICE_DATA_DIR=/app/omnivoice_data
ENV HF_HOME=/app/omnivoice_data/huggingface
ENV PYTHONPATH=/app/backend
# Headless server deployment: relax the desktop-only loopback origin gate
# so the remote Web UI VM and Docker NAT can reach /system/* and /api/settings/*.
ENV OMNIVOICE_SERVER_MODE=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    libsndfile1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV UV_BREAK_SYSTEM_PACKAGES=1

RUN python3 -m pip install --no-cache-dir uv

COPY pyproject.toml uv.lock README.md ./
COPY deploy/torch-constraints.txt ./deploy/torch-constraints.txt
COPY deploy/uv-overrides.txt ./deploy/uv-overrides.txt
COPY omnivoice/ ./omnivoice/

RUN uv pip install --python "$(command -v python3)" --no-cache \
    --constraint deploy/torch-constraints.txt \
    --override deploy/uv-overrides.txt .

# Guard: verify security overrides from deploy/uv-overrides.txt
RUN python3 -c "from importlib.metadata import version; from packaging.requirements import Requirement; \
    reqs = [Requirement(l.strip()) for l in open('deploy/uv-overrides.txt') if l.strip() and not l.lstrip().startswith('#')]; \
    bad = [f'{r.name} {version(r.name)} does not satisfy {r}' for r in reqs if not r.specifier.contains(version(r.name), prereleases=True)]; \
    assert not bad, bad; \
    print('uv overrides applied:', ', '.join(f'{r.name} {version(r.name)}' for r in reqs))"

# Guard: verify GPU PyTorch & torchvision C++ ops were not clobbered
ARG GPU_FLAVOR=cuda
RUN python3 -c "import os, torch, torchaudio, torchvision; \
    flavor = os.environ['GPU_FLAVOR']; \
    accel = torch.version.hip if flavor == 'rocm' else torch.version.cuda; \
    print(f'torch={torch.__version__} torchaudio={torchaudio.__version__} torchvision={torchvision.__version__} {flavor}={accel}'); \
    assert accel, f'base image {flavor} torch was clobbered (now {torch.__version__})'; \
    import torchvision.ops; torchvision.ops.nms; \
    print('torchvision C++ ops resolve against this torch')"

# cuDNN 8 side-load for CTranslate2 (WhisperX, faster-whisper) on x86_64 CUDA.
# Skipped on aarch64 (DGX Spark / GH200) where nvidia-cudnn-cu12==8.9.7.29 has no wheel.
RUN if [ "$GPU_FLAVOR" = "cuda" ] && [ "$(uname -m)" != "aarch64" ]; then \
        target="$(python3 -c "import sys; print(f'{sys.prefix}/lib/python{sys.version_info.major}.{sys.version_info.minor}/site-packages/cudnn8_compat')")" \
        && uv pip install --python "$(command -v python3)" --no-cache --no-deps \
            --target "$target" nvidia-cudnn-cu12==8.9.7.29 \
        && CUDNN8_TARGET="$target" python3 -c "import glob, os; t = os.environ['CUDNN8_TARGET']; found = [f for f in glob.glob(t + '/nvidia/cudnn/lib/*') if '.so.8' in f]; assert found, 'cuDNN 8 libraries missing from ' + t; print(f'cuDNN 8 compat: {len(found)} libraries in ' + t)"; \
    else \
        echo "cuDNN 8 compat skipped (GPU_FLAVOR=$GPU_FLAVOR, arch=$(uname -m))"; \
    fi

COPY backend/ ./backend/
COPY config/ ./config/
COPY alembic.ini ./

EXPOSE 3900

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=5 \
    CMD ["python3", "backend/docker_entrypoint.py", "--health-check"]

VOLUME ["/app/omnivoice_data"]

ENV OMNIVOICE_BIND_HOST=0.0.0.0
ARG BUILD_COMMIT=unknown
ENV OMNIVOICE_BUILD_COMMIT=${BUILD_COMMIT}
ENTRYPOINT ["python3", "backend/docker_entrypoint.py"]
