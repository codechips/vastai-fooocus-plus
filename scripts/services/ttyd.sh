#!/usr/bin/env bash
# TTYd web terminal service

function start_ttyd() {
    echo "ttyd: starting web terminal"

    # Set up basic auth if password is provided
    if [[ ${PASSWORD} ]] && [[ ${PASSWORD} != "admin" ]]; then
        AUTH_ARGS="-c ${USERNAME}:${PASSWORD}"
    else
        AUTH_ARGS=""
    fi

    # Set start directory (configurable via TTYD_START_DIR, defaults to $WORKSPACE)
    TTYD_START_DIR="${TTYD_START_DIR:-${WORKSPACE}}"
    echo "ttyd: start directory set to ${TTYD_START_DIR}"
    
    # Use -W flag to enable writable terminal (fixes readonly issue)
    nohup /usr/local/bin/ttyd ${AUTH_ARGS} -W -p 7020 bash -c "cd '${TTYD_START_DIR}' && bash" >${WORKSPACE}/logs/ttyd.log 2>&1 &
    echo "ttyd: started on port 7020 (writable mode)"
    echo "ttyd: log file at ${WORKSPACE}/logs/ttyd.log"
}

# Note: Function is called explicitly from start.sh
# No auto-execution when sourced to prevent duplicate processes