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
    tree \
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
    && rm -rf /var/lib/apt/lists/* \
    # Install uv for fast venv creation (but use pip for package installations)
    && curl -LsSf https://astral.sh/uv/install.sh | bash \
    && mv /root/.local/bin/uv /usr/local/bin/uv


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
RUN git clone https://github.com/codechips/FooocusPlus.git fooocus

WORKDIR /opt/fooocus

# Create Python environment with uv (fast)
# hadolint ignore=SC2015,DL3013
RUN uv venv --seed --python 3.10 .venv && \
    source .venv/bin/activate && \
    # Install essential system packages needed for pip to function
    pip install --upgrade pip==25.1.1 && \
    pip install setuptools wheel packaging pygit2

# Pre-install all FooocusPlus requirements at build time
# hadolint ignore=DL3013
RUN source .venv/bin/activate && \
    # Verify requirements files exist
    ls -la requirements*.txt && \
    echo "Pre-installing FooocusPlus requirements..." && \
    pip install -r requirements.txt && \
    pip install -r requirements_system.txt && \
    echo "✓ All packages pre-installed at build time"

# Clean up build dependencies and cache
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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

# Copy provision configurations
COPY config/provision/ /opt/config/provision/

# Configure filebrowser, set permissions, and final cleanup
# hadolint ignore=SC2015
RUN chmod +x /opt/bin/start.sh /opt/bin/services/*.sh /opt/provision/provision.py && \
    # Capture build metadata
    date -u +"%Y-%m-%dT%H:%M:%SZ" > /root/BUILDTIME.txt && \
    git rev-parse HEAD > /root/BUILD_SHA.txt 2>/dev/null || echo "unknown" > /root/BUILD_SHA.txt && \
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
    FOOOCUS_AUTO_UPDATE="" \
    SKIP_REQUIREMENTS_INSTALL=True \
    SKIP_TORCH_MANAGEMENT=True \
    NO_ACCELERATE="" \
    OPEN_BUTTON_PORT=80

# Expose ports
EXPOSE 80 8010 7010 7020 7030

# Set working directory
WORKDIR /workspace

# Entrypoint
ENTRYPOINT ["/opt/bin/start.sh"]
