#!/bin/bash
# Local testing script for Fooocus Plus provisioning system

set -e

echo "======================================"
echo "Fooocus Plus Provisioning Test Setup"
echo "======================================"
echo

# Create test workspace
TEST_DIR="/tmp/vastai-fooocus-test"
echo "Creating test workspace at $TEST_DIR..."
rm -rf "$TEST_DIR" 2>/dev/null || true
mkdir -p "$TEST_DIR"

# Create Fooocus directory structure
echo "Creating Fooocus model directories..."
mkdir -p "$TEST_DIR/fooocus/models/checkpoints"
mkdir -p "$TEST_DIR/fooocus/models/loras"
mkdir -p "$TEST_DIR/fooocus/models/vae"
mkdir -p "$TEST_DIR/fooocus/models/embeddings"
mkdir -p "$TEST_DIR/fooocus/models/hypernetworks"
mkdir -p "$TEST_DIR/fooocus/models/controlnet"
mkdir -p "$TEST_DIR/fooocus/models/upscale_models"
mkdir -p "$TEST_DIR/fooocus/models/inpaint"
mkdir -p "$TEST_DIR/fooocus/models/clip"
mkdir -p "$TEST_DIR/fooocus/models/clip_vision"
mkdir -p "$TEST_DIR/fooocus/models/diffusers"
mkdir -p "$TEST_DIR/fooocus/models/unet"
mkdir -p "$TEST_DIR/fooocus/models/prompt_expansion"
mkdir -p "$TEST_DIR/fooocus/models/llms"
mkdir -p "$TEST_DIR/fooocus/models/safety_checker"
mkdir -p "$TEST_DIR/logs"

echo
echo "Test workspace created successfully!"
echo

# Set environment variables
export WORKSPACE="$TEST_DIR"
export HF_TOKEN="${HF_TOKEN:-}"
export CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"

echo "Environment variables:"
echo "  WORKSPACE: $WORKSPACE"
echo "  HF_TOKEN: ${HF_TOKEN:+[set]}"
echo "  CIVITAI_TOKEN: ${CIVITAI_TOKEN:+[set]}"
echo

echo "======================================"
echo "Test Commands"
echo "======================================"
echo
echo "1. Test with minimal configuration:"
echo "   ./scripts/provision/provision.py examples/test-provision-minimal.toml"
echo
echo "2. Test with full configuration:"
echo "   ./scripts/provision/provision.py examples/test-provision-full.toml"
echo
echo "3. Test dry run (no downloads):"
echo "   ./scripts/provision/provision.py examples/test-provision-minimal.toml --dry-run"
echo
echo "4. Test with custom workspace:"
echo "   ./scripts/provision/provision.py examples/test-provision-minimal.toml --workspace /custom/path"
echo
echo "5. Clean up test workspace:"
echo "   rm -rf $TEST_DIR"
echo
echo "======================================"

# Make the script executable
chmod +x scripts/provision/provision.py 2>/dev/null || true

echo
echo "Ready for testing!"