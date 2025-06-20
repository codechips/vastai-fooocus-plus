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

    # Use -W flag to enable writable terminal (fixes readonly issue)
    nohup /usr/local/bin/ttyd ${AUTH_ARGS} -W -p 7020 bash >/workspace/logs/ttyd.log 2>&1 &
    echo "ttyd: started on port 7020 (writable mode)"
    echo "ttyd: log file at /workspace/logs/ttyd.log"
}

# Main execution if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    start_ttyd
fi