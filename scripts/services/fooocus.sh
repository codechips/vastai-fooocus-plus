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
    
    # Install SupportPack on first run (following Linux install script pattern)
    SUPPORTPACK_MARKER="/opt/fooocus/.supportpack_installed"
    if [[ ! -f "${SUPPORTPACK_MARKER}" ]]; then
        echo "fooocus: installing SupportPack on first run..."
        echo "fooocus: this is a one-time 26GB download and may take several minutes"
        
        # Install required tools for SupportPack extraction (using fast uv installer)
        echo "fooocus: installing SupportPack tools with uv (faster than pip)"
        uv pip install py7zr==1.0.0 "huggingface-hub>=0.29.3"
        
        # Pre-install gradio_client to prevent dependency issues during startup
        echo "fooocus: pre-installing gradio_client to prevent import errors"
        uv pip install "gradio_client>=0.5.0,<0.6.0"
        
        # Download SupportPack.7z from HuggingFace
        echo "fooocus: downloading SupportPack.7z from HuggingFace..."
        huggingface-cli download --local-dir /opt/fooocus DavidDragonsage/FooocusPlus SupportPack.7z
        
        # Extract SupportPack to current directory
        echo "fooocus: extracting SupportPack.7z..."
        py7zr x --verbose /opt/fooocus/SupportPack.7z /opt/fooocus/
        
        # Clean up the archive to save space
        rm -f /opt/fooocus/SupportPack.7z
        
        # Create marker file to indicate SupportPack is installed
        touch "${SUPPORTPACK_MARKER}"
        echo "fooocus: SupportPack installation completed"
    else
        echo "fooocus: SupportPack already installed (found marker file)"
    fi
    
    # Always ensure gradio_client is installed to prevent import errors
    # This fixes the "ModuleNotFoundError: No module named 'gradio_client'" issue
    echo "fooocus: ensuring gradio_client is available (using fast uv installer)"
    uv pip install "gradio_client>=0.5.0,<0.6.0" --quiet
    
    # Patch FooocusPlus to use fast uv installer instead of slow pip
    echo "fooocus: patching launch_util.py to use uv instead of pip for faster installs"
    if ! grep -q "uv pip" modules/launch_util.py; then
        # Replace 'python -m pip' with 'uv pip' for much faster package installation
        sed -i 's/"{python}" -m pip/uv pip/g' modules/launch_util.py
        echo "fooocus: successfully patched launch_util.py to use uv (5-10x faster)"
    else
        echo "fooocus: launch_util.py already patched to use uv"
    fi

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
        nohup accelerate launch --num_cpu_threads_per_process=6 ${ENTRY_POINT} ${FULL_ARGS} >/workspace/logs/fooocus.log 2>&1 &
    else
        echo "fooocus: launching with standard python and args: ${FULL_ARGS}"
        nohup python ${ENTRY_POINT} ${FULL_ARGS} >/workspace/logs/fooocus.log 2>&1 &
    fi

    echo "fooocus: started on port 8010"
    echo "fooocus: log file at /workspace/logs/fooocus.log"
}

# Note: Function is called explicitly from start.sh
# No auto-execution when sourced to prevent duplicate processes