FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu

ENV LANG=C.UTF-8
ARG INSTALL_ZSH=true
ARG TARGETARCH

# Install system packages
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wget \
    unzip \
    curl \
    git \
    build-essential \
    libgmp-dev \
    default-jre \
    gnupg \
    ca-certificates \
    python3 \
    python3-pip \
 && rm -rf /var/lib/apt/lists/*

# Python ML packages
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    torch \
    torchvision \
    tqdm \
    scikit-learn \
    h5py \
    pyyaml \
    pandas

USER vscode