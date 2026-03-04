FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu

ENV LANG=C.UTF-8
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

# install sv2v
RUN cd /opt \
 && wget https://github.com/zachjs/sv2v/releases/download/v0.0.13/sv2v-Linux.zip \
 && unzip sv2v-Linux.zip \
 && mv sv2v-Linux sv2v \
 && ln -s /opt/sv2v/sv2v /usr/local/bin/sv2v \
 && rm sv2v-Linux.zip

ENV PATH="/opt/sv2v/bin:${PATH}"

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