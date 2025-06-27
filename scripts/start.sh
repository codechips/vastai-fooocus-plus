#!/usr/bin/env bash
# Main orchestrator for VastAI Fooocus Plus container services

# Simple process manager for Fooocus Plus and supporting services
# Based on vastai-fooocus pattern with modular service architecture

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$SCRIPT_DIR/services"

# Source utilities
source "$SERVICES_DIR/utils.sh"

# Source service scripts
source "$SERVICES_DIR/nginx.sh"
source "$SERVICES_DIR/fooocus.sh"
source "$SERVICES_DIR/filebrowser.sh"
source "$SERVICES_DIR/ttyd.sh"
source "$SERVICES_DIR/logdy.sh"
source "$SERVICES_DIR/provisioning.sh"

# Main execution
echo "Starting VastAI Fooocus Plus container..."

# Setup workspace
setup_workspace

# Run external provisioning first if enabled
run_provisioning

# Start services
start_nginx
start_filebrowser
start_ttyd
start_logdy
start_fooocus

# Show information
show_info

# Keep container running
echo ""
echo "Container is running. Press Ctrl+C to stop."
sleep infinity
