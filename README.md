# Vast.ai Fooocus Plus Docker Image

Simplified single Docker image for running Fooocus Plus on Vast.ai with integrated web-based management tools and automated model provisioning.

## Features

**All-in-one Docker image** with:
- **Fooocus Plus** (port 8010): AI image generation interface
- **Filebrowser** (port 7010): File management interface
- **ttyd** (port 7020): Web-based terminal (writable)
- **logdy** (port 7030): Log viewer
- **Automated Model Provisioning**: Download models from HuggingFace, CivitAI, and direct URLs
- **PyTorch 2.1.0 + CUDA 12.1**: Optimized for stability
- **Simple process management**: No complex orchestration

## Quick Start

### For Vast.ai Users

1. Create a new instance with:
   ```
   Docker Image: ghcr.io/codechips/vastai-fooocus-plus:latest
   ```

2. Configure environment variables:
   ```bash
   -e USERNAME=your_username -e PASSWORD=your_password -e OPEN_BUTTON_PORT=8010
   ```

   **Optional model provisioning** (see [Model Provisioning](#model-provisioning) section):
   ```bash
   -e PROVISION_URL=https://your-server.com/config.toml
   -e HF_TOKEN=hf_your_huggingface_token
   -e CIVITAI_TOKEN=your_civitai_token
   ```

3. Map ports:
   ```bash
   -p 8010:8010 -p 7010:7010 -p 7020:7020 -p 7030:7030
   ```

4. Launch with "Entrypoint" mode for best compatibility

### Access Your Services

- **Fooocus Plus**: Port 8010 (main interface, protected with Gradio auth)
- **File Manager**: Port 7010 (manage models and outputs, protected with auth)
- **Terminal**: Port 7020 (command line access, writable, protected with auth)
- **Logs**: Port 7030 (monitor all application logs)

## Default Credentials

- Username: `admin`
- Password: `admin`

## Model Provisioning

The container includes an automated model provisioning system that can download models from multiple sources during startup.

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PROVISION_URL` | URL to TOML configuration file for automatic provisioning | None | No |
| `WORKSPACE` | Target directory for models and data | `/workspace` | No |
| `HF_TOKEN` | HuggingFace API token for gated models | None | No |
| `CIVITAI_TOKEN` | CivitAI API token for some models | None | No |
| `USERNAME` | Authentication username for all services | `admin` | No |
| `PASSWORD` | Authentication password for all services | `admin` | No |
| `OPEN_BUTTON_PORT` | Port for Vast.ai "Open" button | `8010` | No |
| `FOOOCUS_ARGS` | Additional arguments for Fooocus Plus | Empty | No |
| `FOOOCUS_NO_AUTO_UPDATE` | Disable auto-update on startup (set to "True" to disable) | Empty | No |
| `NO_ACCELERATE` | Disable accelerate optimization (enabled by default) | Empty | No |
| `NO_TCMALLOC` | Disable TCMalloc memory optimization | Empty | No |

### Quick Provisioning Setup

1. **Create a TOML configuration file** (see [examples](examples/)):
   ```toml
   # Basic configuration example
   [models.checkpoints.sdxl-base]
   source = "huggingface"
   repo = "stabilityai/stable-diffusion-xl-base-1.0"
   file = "sd_xl_base_1.0.safetensors"

   [models.lora.detail-tweaker]
   source = "civitai"
   model_id = "58390"
   ```

2. **Host the configuration file** (GitHub, Google Drive, S3, HTTP server, etc.)

3. **Launch container with provisioning**:
   ```bash
   docker run -d \
     -p 8010:8010 -p 7010:7010 -p 7020:7020 -p 7030:7030 \
     -e USERNAME=admin -e PASSWORD=admin \
     -e PROVISION_URL=https://drive.google.com/file/d/YOUR_FILE_ID/view \
     -e HF_TOKEN=hf_your_token_here \
     -e CIVITAI_TOKEN=your_civitai_token \
     ghcr.io/codechips/vastai-fooocus-plus:latest
   ```

### Manual Provisioning

You can also run the provisioning script manually from inside the container:

```bash
# Access container terminal (via ttyd web interface or docker exec)
cd /opt/bin

# Provision from local file
./provision/provision.py /workspace/config.toml

# Provision from URL
./provision/provision.py https://example.com/config.toml

# Dry run (validate without downloading)
./provision/provision.py config.toml --dry-run

# Override workspace directory
./provision/provision.py config.toml --workspace /custom/path

# Get help
./provision/provision.py --help
```

### Supported Model Sources

#### 1. HuggingFace Hub
```toml
[models.checkpoints.model-name]
source = "huggingface"
repo = "username/repository"
file = "model.safetensors"
gated = false  # Set to true for gated models (requires HF_TOKEN)
```

#### 2. CivitAI
```toml
[models.lora.model-name]
source = "civitai"
model_id = "12345"
filename = "custom_name.safetensors"  # Optional
```

#### 3. Direct URLs (including Google Drive)
```toml
[models.vae.model-name]
source = "url"
url = "https://example.com/model.safetensors"
filename = "model.safetensors"
headers = { "Authorization" = "Bearer token" }  # Optional
```

#### 4. Google Drive URLs
**Supported URL formats:**
```toml
# Google Drive sharing link
[models.checkpoints.gdrive-model]
source = "url"
url = "https://drive.google.com/file/d/1ABC123DEF456/view?usp=sharing"
filename = "custom-name.safetensors"

# Direct Google Drive download (auto-converted)
[models.lora.another-model]  
source = "url"
url = "https://drive.google.com/uc?id=1ABC123DEF456"
```

**Features:**
- **Automatic conversion** from sharing links to direct download URLs
- **Virus scan bypass** - handles Google's "can't scan large files" warnings
- **Works for both** model files and provision config files (`PROVISION_URL`)
- **Example provision config**: `PROVISION_URL=https://drive.google.com/file/d/YOUR_ID/view`

#### 5. Simple URL Format
```toml
[models.lora]
simple-model = "https://example.com/model.safetensors"
```

#### 6. CLIP Text Encoders
```toml
[models.text_encoder.clip_l]
source = "huggingface"
repo = "comfyanonymous/flux_text_encoders"
file = "clip_l.safetensors"

[models.text_encoder.t5xxl_fp8]
source = "huggingface"
repo = "comfyanonymous/flux_text_encoders"
file = "t5xxl_fp8_e4m3fn.safetensors"

[models.text_encoder.openclip_vit_l14]
source = "huggingface"
repo = "zer0int/CLIP-GmP-ViT-L-14"
file = "ViT-L-14-BEST-smooth-GmP-HF-format.safetensors"
```

#### 7. FLUX VAE
```toml
# Required for FLUX models
[models.vae.flux-vae]
source = "huggingface"
repo = "black-forest-labs/FLUX.1-dev"
file = "ae.safetensors"
```

### Model Categories and Directories

| Category | Directory | Description |
|----------|-----------|-------------|
| `checkpoints` | `fooocus/models/checkpoints/` | Main model files |
| `lora` | `fooocus/models/loras/` | LoRA adaptation files |
| `vae` | `fooocus/models/vae/` | Variational Auto-Encoder models |
| `controlnet` | `fooocus/models/controlnet/` | ControlNet models |
| `esrgan` | `fooocus/models/upscale_models/` | Upscaling models |
| `embeddings` | `fooocus/models/embeddings/` | Text embeddings |
| `hypernetworks` | `fooocus/models/hypernetworks/` | Hypernetwork models |
| `text_encoder` | `fooocus/models/text_encoder/` | CLIP and text encoder models |
| `clip` | `fooocus/models/text_encoder/` | Alias for text_encoder |

### Example Configurations

- [**Minimal Example**](examples/test-provision-minimal.toml): Small test files for validation
- [**Full Example**](examples/test-provision-full.toml): Comprehensive configuration with all features
- [**FLUX Example**](examples/flux-provision.toml): Complete FLUX.1-dev setup with VAE and text encoders
- [**Main Example**](examples/provision-config.toml): Production-ready configuration template

### Local Testing

Test the provisioning system locally:

```bash
# Run the test setup script
./test_provision_local.sh

# This creates a test environment at /tmp/vastai-fooocus-test
# and provides commands to test different scenarios
```

### Troubleshooting

**Common Issues:**

1. **Authentication Errors**: Ensure `HF_TOKEN` and `CIVITAI_TOKEN` are set correctly
2. **Gated Models**: Visit the HuggingFace model page and accept terms of service
3. **Network Issues**: Check if URLs are accessible and not blocked
4. **Disk Space**: Ensure adequate storage for model downloads
5. **TOML Syntax**: Validate configuration with `--dry-run` option

**Logs**: Check provisioning logs at `/workspace/logs/provision.log` or via the logdy interface (port 7030).

## Performance Optimization

### Accelerate Support (Enabled by Default)

The container uses HuggingFace Accelerate by default for optimized multi-core performance:

**Benefits:**
- **Multi-core optimization**: Uses `--num_cpu_threads_per_process=6` for better CPU utilization
- **Memory efficiency**: Improved memory management for large models
- **Faster loading**: Optimized model loading and inference
- **Automatic fallback**: Uses standard Python if accelerate is unavailable

**Control:**
```bash
# Disable accelerate if needed (not recommended)
-e NO_ACCELERATE=True
```

**Usage:**
- **Enabled by default**: No configuration needed for optimal performance
- **Automatic detection**: Only activates if accelerate is available
- **Safe fallback**: Uses standard Python launch if accelerate fails
- **Particularly beneficial**: On multi-core systems (most Vast.ai instances)

### TCMalloc Memory Optimization

The container automatically detects and uses TCMalloc for improved memory performance:

**Features:**
- **Automatic detection**: Finds and configures TCMalloc libraries at startup
- **glibc compatibility**: Handles different glibc versions (pre/post 2.34)
- **Memory efficiency**: Significantly reduces memory fragmentation
- **CPU performance**: Better memory allocation performance
- **Safe fallback**: Continues without TCMalloc if unavailable

**Control:**
- **Disable**: Set `NO_TCMALLOC=1` to skip TCMalloc setup
- **Manual override**: Set `LD_PRELOAD` to use custom memory allocator
- **Automatic**: Enabled by default on Linux systems

**Supported libraries:**
- `libtcmalloc-minimal4` (pre-installed in container)
- `libtcmalloc.so` variants
- Compatible with Ubuntu 22.04 glibc

## Directory Structure

```
vastai-fooocus-plus/
├── Dockerfile                      # Single image with all components
├── scripts/
│   ├── start.sh                   # Main orchestrator script
│   ├── services/                  # Modular service scripts
│   │   ├── utils.sh              # Shared utilities (TCMalloc, workspace)
│   │   ├── fooocus.sh            # Fooocus Plus service
│   │   ├── filebrowser.sh        # File browser service
│   │   ├── ttyd.sh               # Web terminal service
│   │   ├── logdy.sh              # Log viewer service
│   │   └── provisioning.sh       # Model provisioning service
│   └── provision/                 # Model provisioning system
│       ├── provision.py           # Main provisioning script
│       ├── config/                # Configuration parsing
│       ├── downloaders/           # Download implementations
│       ├── utils/                 # Utilities and logging
│       └── validators/            # Token validation
├── config/
│   ├── filebrowser/               # Filebrowser configuration
│   └── fooocus/                   # Fooocus Plus configuration (if any)
├── examples/                      # Provisioning configuration examples
│   ├── provision-config.toml      # Production template
│   ├── test-provision-minimal.toml # Minimal test config
│   └── test-provision-full.toml   # Full feature example
├── test_provision_local.sh        # Local testing script
├── .github/workflows/             # CI/CD workflows
└── .mise.toml                     # Task runner configuration
```

## Local Development

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [Mise](https://mise.jdx.dev/) task runner

### Quick Start
```bash
# Build and test everything
mise run dev

# Or step by step:
mise run build    # Build image
mise run test     # Start test container
mise run status   # Check service status

# Test provisioning system locally
./test_provision_local.sh
```

### Available Mise Tasks

#### Building
```bash
mise run build          # Build image
mise run build-no-cache # Build without cache (for debugging)
mise run build-prod     # Build production image for linux/amd64
```

#### Testing
```bash
mise run test           # Start test container
mise run test-services  # Test services with curl
mise run dev            # Full development workflow
```

#### Management
```bash
mise run status         # Check container and service status
mise run logs           # Follow container logs
mise run shell          # Get shell access to container
mise run stop           # Stop test container
mise run clean          # Clean up everything
```

### Manual Docker Commands
If you prefer not to use Mise:
```bash
# Build image
docker build -t vastai-fooocus-plus:local .

# Run container
docker run -d --name vastai-test \
  -p 8010:8010 -p 7010:7010 -p 7020:7020 -p 7030:7030 \
  -e USERNAME=admin -e PASSWORD=admin \
  vastai-fooocus-plus:local
```

## Log Monitoring

The logdy interface (port 7030) provides real-time monitoring of:

- **Fooocus Plus**: Complete Fooocus Plus logs including model loading, generation progress, and errors
- **Filebrowser**: Application logs and access logs
- **ttyd**: Terminal session logs
- **Logdy**: Log viewer service logs

All logs are easily searchable through the logdy web interface.

## Security Features

- **Unified authentication** across all services:
  - Fooocus Plus: Gradio built-in authentication
  - Filebrowser: Native authentication
  - ttyd terminal: Basic authentication
- **Configurable credentials** via environment variables (USERNAME/PASSWORD)
- **Simple, secure access** to all management tools

## Compatibility

- **CUDA**: 12.1 (with 12.2 base)
- **PyTorch**: 2.1.0 (with CUDA 12.1 support)
- **Python**: 3.10 (Ubuntu 22.04 default)
- **GPU**: NVIDIA GPUs with CUDA support
- **Platform**: Vast.ai, local Docker environments
- **Architecture**: x86_64 and ARM64



## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `mise run dev`
5. Submit a pull request

## License

This project is open source. Please check individual component licenses for specific terms.
