#!/usr/bin/env bash
# Filebrowser service

function start_filebrowser() {
    echo "filebrowser: starting"
    cd /root

    # Update password if provided
    if [[ ${PASSWORD} ]] && [[ ${PASSWORD} != "admin" ]]; then
        echo "filebrowser: updating admin password"
        /usr/local/bin/filebrowser users update admin -p ${PASSWORD}
    fi

    # Start filebrowser in background
    nohup /usr/local/bin/filebrowser >${WORKSPACE}/logs/filebrowser.log 2>&1 &
    echo "filebrowser: started on port 7010"
    echo "filebrowser: log file at ${WORKSPACE}/logs/filebrowser.log"
}

# Note: Function is called explicitly from start.sh
# No auto-execution when sourced to prevent duplicate processes