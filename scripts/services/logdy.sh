#!/usr/bin/env bash
# Logdy log viewer service

function start_logdy() {
    echo "logdy: starting log viewer"

    # List all log files explicitly to ensure logdy follows all of them
    # Using wildcard at startup time only captures existing files
    LOG_FILES="${WORKSPACE}/logs/nginx.log \
${WORKSPACE}/logs/fooocus.log \
${WORKSPACE}/logs/filebrowser.log \
${WORKSPACE}/logs/ttyd.log \
${WORKSPACE}/logs/provision.log \
${WORKSPACE}/logs/supportpack_install.log"

    # Start logdy to follow all log files
    nohup /usr/local/bin/logdy follow ${LOG_FILES} --port 7030 --ui-ip=0.0.0.0 --ui-pass=$PASSWORD --no-analytics >${WORKSPACE}/logs/logdy.log 2>&1 &
    echo "logdy: started on port 7030"
    echo "logdy: log file at ${WORKSPACE}/logs/logdy.log"
    echo "logdy: following nginx, fooocus, filebrowser, ttyd, provision, and supportpack logs"
}

# Note: Function is called explicitly from start.sh
# No auto-execution when sourced to prevent duplicate processes