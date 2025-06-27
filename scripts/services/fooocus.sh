#!/usr/bin/env bash
# Fooocus Plus service

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

function start_fooocus() {
    echo "fooocus: starting Fooocus Plus"
    
    # Activate the uv-created virtual environment first
    source /opt/fooocus/.venv/bin/activate
    
    # Change to the Fooocus directory (required for proper operation)
    cd /opt/fooocus
    
    # Install SupportPack in background on first run
    SUPPORTPACK_MARKER="/opt/fooocus/.supportpack_installed"
    if [[ ! -f "${SUPPORTPACK_MARKER}" ]] && [[ ! -f "/opt/fooocus/.supportpack_installing" ]]; then
        echo "fooocus: starting SupportPack installation in background..."
        echo "fooocus: this is a one-time 26GB download and may take several minutes"
        
        # Create installing marker to prevent duplicate runs
        touch /opt/fooocus/.supportpack_installing
        
        # Run SupportPack installation in background
        (
            # Install huggingface-hub for downloading
            echo "fooocus: [SupportPack] installing huggingface-hub..."
            pip install "huggingface-hub>=0.29.3" --quiet
            
            # Download SupportPack.7z from HuggingFace
            echo "fooocus: [SupportPack] downloading SupportPack.7z (26GB)..."
            huggingface-cli download --local-dir /opt/fooocus DavidDragonsage/FooocusPlus SupportPack.7z
            
            # Extract SupportPack using native 7z command
            echo "fooocus: [SupportPack] extracting SupportPack.7z..."
            cd /opt/fooocus && 7z x -y SupportPack.7z
            
            # Move UserDir models to workspace if extracted there
            if [[ -d "/opt/fooocus/UserDir/models" ]]; then
                echo "fooocus: [SupportPack] moving models to workspace..."
                # Create workspace models directory if it doesn't exist
                mkdir -p ${WORKSPACE}/fooocus/models
                # Move all model subdirectories to workspace
                cp -r /opt/fooocus/UserDir/models/* ${WORKSPACE}/fooocus/models/ 2>/dev/null || true
                # Clean up UserDir
                rm -rf /opt/fooocus/UserDir
            fi
            
            # Clean up the archive to save space
            rm -f /opt/fooocus/SupportPack.7z
            
            # Clean up installing marker and create completion marker
            rm -f /opt/fooocus/.supportpack_installing
            touch "${SUPPORTPACK_MARKER}"
            echo "fooocus: [SupportPack] installation completed successfully"
        ) > ${WORKSPACE}/logs/supportpack_install.log 2>&1 &
        
        echo "fooocus: SupportPack installation running in background"
        echo "fooocus: check ${WORKSPACE}/logs/supportpack_install.log for progress"
    elif [[ -f "/opt/fooocus/.supportpack_installing" ]]; then
        echo "fooocus: SupportPack installation already in progress"
    else
        echo "fooocus: SupportPack already installed (found marker file)"
    fi
    
    # Let FooocusPlus handle its own package installations with standard pip

    # Default Fooocus Plus arguments
    # Fooocus Plus uses port 7865 by default, we'll override to 8010 to match expected port
    DEFAULT_ARGS="--listen --port 8010 --disable-in-browser --theme dark --models-root ${WORKSPACE}/fooocus/models"

    # Enable FooocusPlus built-in authentication using auth.json
    if [[ ${USERNAME} ]] && [[ ${PASSWORD} ]]; then
        echo "fooocus: enabling built-in authentication for user: ${USERNAME}"
        
        # Create auth.json file for FooocusPlus authentication
        cat > auth.json << EOF
[
  {
    "user": "${USERNAME}",
    "pass": "${PASSWORD}"
  }
]
EOF
        
        # Patch webui.py to enable authentication in gr.Blocks()
        if ! grep -q "auth=check_auth" webui.py; then
            echo "fooocus: patching webui.py to enable authentication"
            sed -i 's/common\.GRADIO_ROOT = gr\.Blocks(/common.GRADIO_ROOT = gr.Blocks(auth=check_auth if auth_enabled else None, /' webui.py
        fi
        
        # Patch webui.py to allow external access (change 127.0.0.1 to 0.0.0.0)
        if grep -q 'server_name="127.0.0.1"' webui.py; then
            echo "fooocus: enabling external access (0.0.0.0)"
            sed -i 's/server_name="127.0.0.1"/server_name="0.0.0.0"/' webui.py
        fi
    else
        echo "fooocus: starting without authentication (no USERNAME/PASSWORD set)"
        echo "fooocus: WARNING - FooocusPlus will only be accessible locally (127.0.0.1)"
    fi

    # Combine default args with any custom args
    FULL_ARGS="${DEFAULT_ARGS} ${FOOOCUS_ARGS}"

    # Determine entry point based on auto-update setting (default: true)
    if [[ "${FOOOCUS_NO_AUTO_UPDATE}" == "True" ]] || [[ "${FOOOCUS_NO_AUTO_UPDATE}" == "true" ]]; then
        ENTRY_POINT="entry_without_update.py"
        echo "fooocus: auto-update disabled, using entry_without_update.py"
    else
        ENTRY_POINT="entry_with_update.py"
        echo "fooocus: auto-update enabled, using entry_with_update.py"
    fi

    # Prepare TCMalloc for better memory performance
    prepare_tcmalloc

    # Use accelerate by default, allow opt-out
    if [[ "${NO_ACCELERATE}" != "True" ]] && command -v accelerate >/dev/null 2>&1; then
        echo "fooocus: launching with accelerate and args: ${FULL_ARGS}"
        nohup accelerate launch --num_cpu_threads_per_process=6 ${ENTRY_POINT} ${FULL_ARGS} >${WORKSPACE}/logs/fooocus.log 2>&1 &
    else
        echo "fooocus: launching with standard python and args: ${FULL_ARGS}"
        nohup python ${ENTRY_POINT} ${FULL_ARGS} >${WORKSPACE}/logs/fooocus.log 2>&1 &
    fi

    echo "fooocus: started on port 8010"
    echo "fooocus: log file at ${WORKSPACE}/logs/fooocus.log"
}

# Note: Function is called explicitly from start.sh
# No auto-execution when sourced to prevent duplicate processes