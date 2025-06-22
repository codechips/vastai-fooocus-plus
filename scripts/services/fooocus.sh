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

    # Default Fooocus Plus arguments
    # Fooocus Plus uses port 7865 by default, we'll override to 8010 to match expected port
    DEFAULT_ARGS="--listen --port 8010 --disable-in-browser --theme dark --models-root ${WORKSPACE}/fooocus/models"

    # Add Gradio authentication using environment variables
    if [[ ${USERNAME} ]] && [[ ${PASSWORD} ]]; then
        AUTH_ARGS="--gradio-auth ${USERNAME}:${PASSWORD}"
        echo "fooocus: enabling Gradio authentication for user: ${USERNAME}"
    else
        AUTH_ARGS=""
        echo "fooocus: starting without authentication (no USERNAME/PASSWORD set)"
    fi

    # Combine default args with auth and any custom args
    FULL_ARGS="${DEFAULT_ARGS} ${AUTH_ARGS} ${FOOOCUS_ARGS}"

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