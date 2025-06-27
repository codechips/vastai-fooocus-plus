#!/usr/bin/env bash
# Fooocus Plus service

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

function provision_models() {
    # Internal model provisioning - downloads essential FooocusPlus models
    # This is separate from external provisioning (PROVISION_URL) which runs earlier
    local PROVISION_MARKER="/opt/fooocus/.models_provisioned"
    
    if [[ ! -f "${PROVISION_MARKER}" ]] && [[ ! -f "/opt/fooocus/.models_provisioning" ]]; then
        echo "fooocus: starting internal model provisioning via parallel downloads..."
        echo "fooocus: downloading all essential FooocusPlus models"

        # Create provisioning marker to prevent duplicate runs
        touch /opt/fooocus/.models_provisioning

        # Run model provisioning in background
        (
            # Navigate to provision directory
            cd /opt/provision || exit 1
            
            echo "fooocus: [Provisioning] downloading models in parallel..."
            
            # Download essential models first
            if uv run provision.py --config "${WORKSPACE}/provision/essential.toml"; then
                echo "fooocus: [Provisioning] essential models downloaded successfully"
            else
                echo "fooocus: [Provisioning] WARNING: essential models download failed"
            fi
            
            # Download all models in parallel
            if uv run provision.py --config "${WORKSPACE}/provision/models.toml"; then
                echo "fooocus: [Provisioning] all models downloaded successfully"
                
                # List what was downloaded
                echo "fooocus: [Provisioning] downloaded models:"
                tree -L 3 ${WORKSPACE}/fooocus/models/ 2>/dev/null | head -50 || ls -la ${WORKSPACE}/fooocus/models/
                
                # Clean up provisioning marker and create completion marker
                rm -f /opt/fooocus/.models_provisioning
                touch "${PROVISION_MARKER}"
                echo "fooocus: [Provisioning] parallel download completed successfully"
            else
                echo "fooocus: [Provisioning] ERROR: model downloads failed!"
                rm -f /opt/fooocus/.models_provisioning
                exit 1
            fi
            
        ) > ${WORKSPACE}/logs/provisioning.log 2>&1 &

        echo "fooocus: model provisioning running in background (parallel downloads)"
        echo "fooocus: check ${WORKSPACE}/logs/provisioning.log for progress"
    elif [[ -f "/opt/fooocus/.models_provisioning" ]]; then
        echo "fooocus: model provisioning already in progress"
    else
        echo "fooocus: models already provisioned (found marker file)"
    fi
}

function start_fooocus() {
    echo "fooocus: starting Fooocus Plus with pre-provisioned models"

    # Activate the uv-created virtual environment first
    source /opt/fooocus/.venv/bin/activate

    # Change to the Fooocus directory (required for proper operation)
    cd /opt/fooocus

    # Step 1: Install system build dependencies for Python package compilation
    echo "fooocus: preparing build dependencies for FooocusPlus package compilation..."
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
        build-essential \
        python3-dev
    echo "fooocus: build dependencies installed - FooocusPlus will handle all Python packages"
    echo "fooocus: (libgit2-dev, pkg-config, pygit2, and packaging already installed at build time)"
    
    echo "fooocus: package patches will be applied after FooocusPlus completes its installation"

    # Step 2: Copy provision configs to workspace for user visibility and control
    echo "fooocus: setting up provision configs in workspace..."
    if [ ! -d "${WORKSPACE}/provision" ]; then
        mkdir -p "${WORKSPACE}/provision"
        cp -r /opt/config/provision/* "${WORKSPACE}/provision/"
        echo "fooocus: provision configs copied to ${WORKSPACE}/provision/"
        echo "fooocus: users can edit configs at ${WORKSPACE}/provision/*.toml"
    else
        echo "fooocus: provision configs already exist in workspace"
    fi

    # Step 3: Pre-provision all models BEFORE starting FooocusPlus
    echo "fooocus: provisioning models before FooocusPlus startup..."
    if [ -f "/opt/provision/provision.py" ]; then
        cd /opt/provision
        
        # Download essential models first (prevents CLIP startup errors)
        echo "fooocus: downloading essential models..."
        uv run provision.py --config "${WORKSPACE}/provision/essential.toml" || echo "Warning: Essential model download failed"
        
        # Run model provisioning (download all models in parallel)
        provision_models
        
        cd /opt/fooocus
    else
        echo "fooocus: provision script not found, skipping model download"
    fi

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

    # Clean up build dependencies after FooocusPlus starts (background task)
    echo "fooocus: starting background cleanup and dependency patching..."
    (
        # Wait for FooocusPlus to complete package installation (check log for completion)
        while ! grep -q "All requirements met" ${WORKSPACE}/logs/fooocus.log 2>/dev/null; do
            sleep 10
        done
        sleep 30  # Extra wait to ensure installation is complete
        
        echo "fooocus: FooocusPlus package installation completed"
        echo "fooocus: dependency patches no longer needed (fixed upstream in FooocusPlus fork)"
        
        echo "fooocus: cleaning up build dependencies..."
        apt-get remove -y build-essential python3-dev
        echo "fooocus: (keeping libgit2-dev, pkg-config for pygit2 compatibility)"
        apt-get autoremove -y
        apt-get clean
        rm -rf /var/lib/apt/lists/*
        echo "fooocus: build dependencies cleanup completed"
    ) >${WORKSPACE}/logs/fooocus_cleanup.log 2>&1 &

    echo "fooocus: started on port 8010"
    echo "fooocus: log file at ${WORKSPACE}/logs/fooocus.log"
    echo "fooocus: cleanup log at ${WORKSPACE}/logs/fooocus_cleanup.log"
}

# Note: Function is called explicitly from start.sh
# No auto-execution when sourced to prevent duplicate processes
