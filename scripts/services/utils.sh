#!/usr/bin/env bash
# Shared utilities for VastAI Fooocus Plus services

function prepare_tcmalloc() {
    if [[ "${OSTYPE}" == "linux"* ]] && [[ -z "${NO_TCMALLOC}" ]] && [[ -z "${LD_PRELOAD}" ]]; then
        # Check glibc version
        LIBC_VER=$(echo $(ldd --version | awk 'NR==1 {print $NF}') | grep -oP '\d+\.\d+')
        echo "tcmalloc: glibc version is $LIBC_VER"
        libc_vernum=$(echo $LIBC_VER)
        # Since 2.34 libpthread is integrated into libc.so
        libc_v234=2.34
        # Define Tcmalloc Libs arrays
        TCMALLOC_LIBS=("libtcmalloc(_minimal|)\.so\.\d" "libtcmalloc\.so\.\d")
        # Traversal array
        for lib in "${TCMALLOC_LIBS[@]}"
        do
            # Determine which type of tcmalloc library the library supports
            TCMALLOC="$(PATH=/sbin:/usr/sbin:$PATH ldconfig -p | grep -P $lib | head -n 1)"
            TC_INFO=(${TCMALLOC//=>/})
            if [[ ! -z "${TC_INFO}" ]]; then
                echo "tcmalloc: checking ${TC_INFO}"
                # Determine if the library is linked to libpthread and resolve undefined symbol: pthread_key_create
                if (( $(echo "$libc_vernum < $libc_v234" | bc -l) )); then
                    # glibc < 2.34 pthread_key_create into libpthread.so. check linking libpthread.so...
                    if ldd ${TC_INFO[2]} | grep -q 'libpthread'; then
                        echo "tcmalloc: ${TC_INFO} is linked with libpthread, setting LD_PRELOAD=${TC_INFO[2]}"
                        # set fullpath LD_PRELOAD (To be on the safe side)
                        export LD_PRELOAD="${TC_INFO[2]}"
                        break
                    else
                        echo "tcmalloc: ${TC_INFO} is not linked with libpthread, will trigger undefined symbol error"
                    fi
                else
                    # Version 2.34 of libc.so (glibc) includes the pthread library IN GLIBC
                    echo "tcmalloc: ${TC_INFO} is linked with libc.so, setting LD_PRELOAD=${TC_INFO[2]}"
                    # set fullpath LD_PRELOAD (To be on the safe side)
                    export LD_PRELOAD="${TC_INFO[2]}"
                    break
                fi
            fi
        done
        if [[ -z "${LD_PRELOAD}" ]]; then
            echo "tcmalloc: cannot locate TCMalloc library (improves CPU memory usage)"
        else
            echo "tcmalloc: enabled with ${LD_PRELOAD}"
        fi
    fi
}

function setup_workspace() {
    echo "Setting up workspace..."

    # Create log directory
    mkdir -p ${WORKSPACE}/logs

    # Create Fooocus model directories if they don't exist
    mkdir -p ${WORKSPACE}/fooocus/models/checkpoints
    mkdir -p ${WORKSPACE}/fooocus/models/loras
    mkdir -p ${WORKSPACE}/fooocus/models/vae
    mkdir -p ${WORKSPACE}/fooocus/models/embeddings
    mkdir -p ${WORKSPACE}/fooocus/models/hypernetworks
    mkdir -p ${WORKSPACE}/fooocus/models/controlnet
    mkdir -p ${WORKSPACE}/fooocus/models/upscale_models
    mkdir -p ${WORKSPACE}/fooocus/models/inpaint
    mkdir -p ${WORKSPACE}/fooocus/models/clip
    mkdir -p ${WORKSPACE}/fooocus/models/clip_vision
    mkdir -p ${WORKSPACE}/fooocus/models/diffusers
    mkdir -p ${WORKSPACE}/fooocus/models/unet
    mkdir -p ${WORKSPACE}/fooocus/models/prompt_expansion
    mkdir -p ${WORKSPACE}/fooocus/models/llms
    mkdir -p ${WORKSPACE}/fooocus/models/safety_checker
    mkdir -p ${WORKSPACE}/fooocus/outputs

    # Note: Models directory handled by --models-root argument in fooocus.sh
    # Output directory will be created by Fooocus when needed
}

function wait_for_service() {
    local service_name="$1"
    local port="$2"
    local max_attempts="${3:-30}"
    local attempt=0

    echo "Waiting for $service_name to start on port $port..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null "http://localhost:$port" 2>/dev/null; then
            echo "$service_name is ready on port $port"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    echo "Warning: $service_name did not start within $max_attempts seconds"
    return 1
}

function show_info() {
    echo ""
    echo "========================================="
    echo "VastAI Fooocus Plus Container Started"
    echo "========================================="
    echo ""
    echo "Services:"
    echo "  - Landing Page: http://localhost:80 (service directory)"
    echo "  - Fooocus Plus: http://localhost:8010"
    echo "  - Filebrowser: http://localhost:7010"
    echo "  - Web Terminal: http://localhost:7020"
    echo "  - Log Viewer: http://localhost:7030"
    echo ""
    echo "Default credentials: ${USERNAME}/${PASSWORD}"
    echo ""
    echo "Logs:"
    echo "  - Nginx: ${WORKSPACE}/logs/nginx.log"
    echo "  - Fooocus Plus: ${WORKSPACE}/logs/fooocus.log"
    echo "  - Filebrowser: ${WORKSPACE}/logs/filebrowser.log"
    echo "  - TTYd: ${WORKSPACE}/logs/ttyd.log"
    echo "  - Logdy: ${WORKSPACE}/logs/logdy.log"
    echo "  - Provisioning: ${WORKSPACE}/logs/provision.log"
    echo ""
    echo "Environment Variables:"
    echo "  - PROVISION_URL: ${PROVISION_URL:-not set}"
    echo "  - HF_TOKEN: ${HF_TOKEN:+present}"
    echo "  - CIVITAI_TOKEN: ${CIVITAI_TOKEN:+present}"
    echo "  - ACCELERATE: ${ACCELERATE:-not set}"
    echo "  - NO_TCMALLOC: ${NO_TCMALLOC:-not set}"
    echo ""
    echo "========================================="
}