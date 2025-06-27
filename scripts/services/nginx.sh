#!/usr/bin/env bash
# Nginx service with dynamic landing page

function start_nginx() {
    echo "nginx: starting web server"

    # Ensure workspace log directory exists
    mkdir -p ${WORKSPACE}/logs

    # Get external IP and port mappings from Vast.ai environment
    EXTERNAL_IP="${PUBLIC_IPADDR:-localhost}"
    FOOOCUS_PORT="${VAST_TCP_PORT_8010:-8010}"
    FILES_PORT="${VAST_TCP_PORT_7010:-7010}"
    TERMINAL_PORT="${VAST_TCP_PORT_7020:-7020}"
    LOGS_PORT="${VAST_TCP_PORT_7030:-7030}"

    echo "nginx: configuring for IP ${EXTERNAL_IP}"
    echo "nginx: ports - fooocus:${FOOOCUS_PORT}, files:${FILES_PORT}, terminal:${TERMINAL_PORT}, logs:${LOGS_PORT}"

    # Process nginx site configuration variables (config already copied during build)
    echo "nginx: processing nginx site configuration variables"
    sed -i "s|{{WORKSPACE}}|${WORKSPACE}|g" /etc/nginx/sites-available/default

    # Just process the template variables
    echo "nginx: processing HTML template variables"

    # Replace template variables in index.html
    sed -i "s/{{EXTERNAL_IP}}/${EXTERNAL_IP}/g" /opt/nginx/html/index.html
    sed -i "s/{{FILES_PORT}}/${FILES_PORT}/g" /opt/nginx/html/index.html
    sed -i "s/{{TERMINAL_PORT}}/${TERMINAL_PORT}/g" /opt/nginx/html/index.html
    sed -i "s/{{LOGS_PORT}}/${LOGS_PORT}/g" /opt/nginx/html/index.html

    # Replace template variables in fooocus.html
    sed -i "s/{{FOOOCUS_PORT}}/${FOOOCUS_PORT}/g" /opt/nginx/html/fooocus.html

    # Add build information to HTML templates
    echo "nginx: adding build information to HTML templates"
    BUILD_DATE=$(cat /root/BUILDTIME.txt 2>/dev/null || echo "unknown")
    BUILD_SHA=$(cat /root/BUILD_SHA.txt 2>/dev/null || echo "unknown")
    SHORT_SHA=${BUILD_SHA:0:7}
    
    # Replace placeholder variables in index.html footer
    sed -i "s/GIT_SHA/${SHORT_SHA}/g" /opt/nginx/html/index.html
    sed -i "s/BUILD_DATE/${BUILD_DATE}/g" /opt/nginx/html/index.html
    

    # Configure nginx for minimal resource usage
    # CRITICAL: Force only 1-2 workers regardless of CPU count
    # - worker_processes: number of worker processes (1 = minimal, 2 = balanced)
    # - worker_connections: max connections per worker
    # - worker_rlimit_nofile: max file descriptors

    # First, check current nginx.conf
    echo "nginx: checking current worker_processes setting..."
    grep "worker_processes" /etc/nginx/nginx.conf || echo "nginx: no worker_processes found"

    # Force worker_processes to a reasonable number (default: 2)
    # This overrides 'auto' which can create hundreds of workers on high-core systems
    NGINX_WORKERS="${NGINX_WORKERS:-2}"
    echo "nginx: setting worker_processes to ${NGINX_WORKERS}"

    if grep -q "worker_processes" /etc/nginx/nginx.conf; then
        sed -i "s/worker_processes.*/worker_processes ${NGINX_WORKERS};/" /etc/nginx/nginx.conf
    else
        # If not found, add it at the beginning
        sed -i "1i worker_processes ${NGINX_WORKERS};" /etc/nginx/nginx.conf
    fi

    # Also limit connections and file descriptors
    sed -i 's/worker_connections.*/worker_connections 512;/' /etc/nginx/nginx.conf

    # Configure main error log to workspace
    if grep -q "error_log" /etc/nginx/nginx.conf; then
        sed -i "s|error_log.*|error_log ${WORKSPACE}/logs/nginx_main.log;|" /etc/nginx/nginx.conf
    else
        # Add error_log after worker_processes
        sed -i "/worker_processes/a error_log ${WORKSPACE}/logs/nginx_main.log;" /etc/nginx/nginx.conf
    fi

    echo "nginx: configured for 2 worker processes (was auto/250+)"

    # Start nginx
    nginx -t && nginx -g 'daemon off;' >${WORKSPACE}/logs/nginx.log 2>&1 &

    echo "nginx: started on port 80"
    echo "nginx: log file at ${WORKSPACE}/logs/nginx.log"
    echo "nginx: serving landing page at http://${EXTERNAL_IP}:80"
}

# Note: Function is called explicitly from start.sh
# No auto-execution when sourced to prevent duplicate processes
