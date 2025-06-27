# Stage 1: Base
FROM nvidia/cuda:12.2.2-base-ubuntu22.04

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive

# Set shell with pipefail for safety
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=on \
    SHELL=/bin/bash \
    PYTHONPATH=/opt/fooocus/venv/lib/python3.10/site-packages

# Install system dependencies and uv in one layer, then clean up
# hadolint ignore=DL3008
RUN apt-get update && \
    # Install runtime dependencies (no Python packages - uv will handle Python)
    apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    python3-dev \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    libglfw3 \
    libgles2 \
    libtcmalloc-minimal4 \
    bc \
    nginx-light \
    tmux \
    nano \
    vim \
    htop \
    # Additional dependencies for Fooocus Plus features
    ffmpeg \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libglib2.0-0 \
    libgomp1 \
    # pygit2 dependencies
    libgit2-1.1 \
    libgit2-dev \
    pkg-config \
    # 7zip for SupportPack extraction
    p7zip-full \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# Install ttyd and logdy (architecture-aware)
RUN if [ "$(uname -m)" = "x86_64" ]; then \
        curl -L --progress-bar https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.x86_64 -o /usr/local/bin/ttyd && \
        curl -L --progress-bar https://github.com/logdyhq/logdy-core/releases/download/v0.13.0/logdy_linux_amd64 -o /usr/local/bin/logdy; \
    else \
        curl -L --progress-bar https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.aarch64 -o /usr/local/bin/ttyd && \
        curl -L --progress-bar https://github.com/logdyhq/logdy-core/releases/download/v0.13.0/logdy_linux_arm64 -o /usr/local/bin/logdy; \
    fi && \
    chmod +x /usr/local/bin/ttyd /usr/local/bin/logdy

# Install filebrowser and set up directories
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash && \
    mkdir -p /workspace/logs /opt/fooocus /root/.config

# Clone Fooocus Plus (version-dependent layer)
WORKDIR /opt
RUN git clone https://github.com/DavidDragonsage/FooocusPlus.git fooocus

WORKDIR /opt/fooocus

# Create Python environment with standard venv
# hadolint ignore=SC2015,DL3013
RUN python3 -m venv .venv && \
    # Activate the virtual environment
    . .venv/bin/activate && \
    # Follow FooocusPlus installation pattern (based on Linux install script)
    # 1. Upgrade pip and install base tools with setuptools constraint
    pip install --upgrade pip==25.1.1 && \
    pip install "setuptools<70" wheel==0.45.1 packaging==25.0 && \
    # 2. Install PyTorch (architecture-specific with pinned versions)
    if [ "$(uname -m)" = "x86_64" ]; then \
        pip install torch==2.1.0+cu121 torchvision==0.16.0+cu121 torchaudio==2.1.0+cu121 --index-url https://download.pytorch.org/whl/cu121; \
    else \
        pip install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2; \
    fi && \
    # 3. Install core dependencies first (as per install script)
    # hadolint ignore=DL3013
    pip install "pygit2>=1.18.0" torchruntime==1.18.1 requests cmake packaging==24.1 && \
    # 4. Install requirements_patch.txt first (critical for FooocusPlus)
    if [ -f requirements_patch.txt ]; then \
        pip install -r requirements_patch.txt; \
    fi && \
    # 5. Install main requirements (but skip conflicting setuptools version)
    if [ -f requirements_versions.txt ]; then \
        grep -v "^setuptools==" requirements_versions.txt > /tmp/requirements_filtered.txt && \
        pip install -r /tmp/requirements_filtered.txt; \
    elif [ -f requirements.txt ]; then \
        pip install -r requirements.txt; \
    fi && \
    # Verify PyTorch installation (with activated venv)
    python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}')" && \
    # Test startup on x86_64 only (with activated venv)
    if [ "$(uname -m)" = "x86_64" ]; then \
        timeout 300 python entry_without_update.py \
        --port 11404 --disable-in-browser --theme dark || echo "Startup test completed"; \
    else \
        echo "Skipping startup test on ARM architecture"; \
    fi && \
    # Clean up unnecessary build dependencies (keep libgit2-1.1 for pygit2 runtime)
    apt-get remove -y build-essential libgit2-dev pkg-config && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    find /opt/fooocus/.venv -name "*.pyc" -delete && \
    find /opt/fooocus/.venv -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Create required directories
RUN mkdir -p /opt/bin /opt/provision /opt/nginx/html /opt/config

# Copy configuration files and scripts (frequently changing layer)
COPY config/filebrowser/filebrowser.json /root/.filebrowser.json
COPY config/nginx/sites-available/default /etc/nginx/sites-available/default
COPY scripts/start.sh /opt/bin/start.sh
COPY scripts/services/ /opt/bin/services/
COPY scripts/provision/ /opt/provision/

# Copy HTML templates directly to nginx directory
COPY config/nginx/html/ /opt/nginx/html/

# Configure filebrowser, set permissions, and final cleanup
# hadolint ignore=SC2015
RUN chmod +x /opt/bin/start.sh /opt/bin/services/*.sh /opt/provision/provision.py && \
    date -u +"%Y-%m-%dT%H:%M:%SZ" > /root/BUILDTIME.txt && \
    filebrowser config init && \
    filebrowser users add admin admin --perm.admin && \
    # Final cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Remove any remaining build artifacts
    find /opt -name "*.pyc" -delete && \
    find /opt -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Set environment variables
ENV USERNAME=admin \
    PASSWORD=fooocus \
    WORKSPACE=/workspace \
    FOOOCUS_ARGS="" \
    FOOOCUS_NO_AUTO_UPDATE="" \
    NO_ACCELERATE="" \
    OPEN_BUTTON_PORT=80

# Expose ports
EXPOSE 80 8010 7010 7020 7030

# Set working directory
WORKDIR /workspace

# Entrypoint
ENTRYPOINT ["/opt/bin/start.sh"]
