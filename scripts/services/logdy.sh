#!/usr/bin/env bash
# Logdy log viewer service

function start_logdy() {
    echo "logdy: starting log viewer"

    # Start logdy to follow all log files
    nohup /usr/local/bin/logdy follow /workspace/logs/*.log --port 7030 --ui-ip=0.0.0.0 --ui-pass=$PASSWORD --no-analytics >/workspace/logs/logdy.log 2>&1 &
    echo "logdy: started on port 7030"
    echo "logdy: log file at /workspace/logs/logdy.log"
}

# Main execution if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    start_logdy
fi