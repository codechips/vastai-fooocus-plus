#!/usr/bin/env bash
# Nginx service with dynamic landing page

function start_nginx() {
    echo "nginx: starting web server"
    
    # Create nginx directories
    mkdir -p /opt/nginx/html
    mkdir -p /var/log/nginx
    
    # Get external IP and port mappings from Vast.ai environment
    EXTERNAL_IP="${PUBLIC_IPADDR:-localhost}"
    FOOOCUS_PORT="${VAST_TCP_PORT_8010:-8010}"
    FILES_PORT="${VAST_TCP_PORT_7010:-7010}"
    TERMINAL_PORT="${VAST_TCP_PORT_7020:-7020}"
    LOGS_PORT="${VAST_TCP_PORT_7030:-7030}"
    
    echo "nginx: generating landing page for IP ${EXTERNAL_IP}"
    echo "nginx: ports - fooocus:${FOOOCUS_PORT}, files:${FILES_PORT}, terminal:${TERMINAL_PORT}, logs:${LOGS_PORT}"
    
    # Generate the landing page HTML with embedded CSS
    cat > /opt/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VastAI Fooocus Plus Services</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            background: linear-gradient(to bottom, #2a2a2a, #1a1a1a);
            color: #e0e0e0;
            display: flex;
            flex-direction: column;
            min-height: 100vh;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
        }
        
        .services {
            flex: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            gap: 1.5rem;
            padding: 2rem;
        }
        
        .service-button {
            display: block;
            width: 280px;
            padding: 1.5rem 2rem;
            background: #fde120;
            border: none;
            border-radius: 8px;
            text-decoration: none;
            color: #1a1a1a;
            text-align: center;
            transition: all 0.3s ease;
            font-size: 1.1rem;
            font-weight: 500;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
        }
        
        .service-button:hover {
            background: #fce000;
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.4);
            color: #000;
        }
        
        .service-button:active {
            transform: translateY(0);
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
        }
        
        .footer {
            position: sticky;
            bottom: 0;
            padding: 1rem;
            text-align: center;
            background: transparent;
            font-size: 0.9rem;
            color: #888;
        }
        
        .footer a {
            color: #ccc;
            text-decoration: none;
            transition: color 0.3s ease;
        }
        
        .footer a:hover {
            color: #fff;
        }
        
        @media (max-width: 600px) {
            .services {
                padding: 1rem;
                gap: 1rem;
            }
            
            .service-button {
                width: 100%;
                max-width: 280px;
            }
        }
    </style>
</head>
<body>
    <div class="services">
        <a href="/fooocus" class="service-button">
            Fooocus Plus
        </a>
        <a href="http://EXTERNAL_IP:FILES_PORT" target="_blank" class="service-button">
            File Browser
        </a>
        <a href="http://EXTERNAL_IP:TERMINAL_PORT" target="_blank" class="service-button">
            Web Terminal
        </a>
        <a href="http://EXTERNAL_IP:LOGS_PORT" target="_blank" class="service-button">
            Log Viewer
        </a>
    </div>
    <div class="footer">
        Another joint by <a href="http://codechips.me" target="_blank">@codechips</a>
    </div>
</body>
</html>
EOF

    # Replace placeholders with actual values
    sed -i "s/EXTERNAL_IP:FILES_PORT/${EXTERNAL_IP}:${FILES_PORT}/g" /opt/nginx/html/index.html
    sed -i "s/EXTERNAL_IP:TERMINAL_PORT/${EXTERNAL_IP}:${TERMINAL_PORT}/g" /opt/nginx/html/index.html
    sed -i "s/EXTERNAL_IP:LOGS_PORT/${EXTERNAL_IP}:${LOGS_PORT}/g" /opt/nginx/html/index.html
    
    # Generate smart Fooocus redirect page
    echo "nginx: creating smart Fooocus redirect page"
    cat > /opt/nginx/html/fooocus.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fooocus Plus - Loading</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            background: linear-gradient(to bottom, #2a2a2a, #1a1a1a);
            color: #e0e0e0;
            display: none;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
        }
        
        .loading-container {
            text-align: center;
            max-width: 500px;
            padding: 2rem;
        }
        
        h1 {
            font-size: 2rem;
            margin-bottom: 2rem;
            color: #fde120;
        }
        
        .spinner {
            width: 80px;
            height: 80px;
            margin: 2rem auto;
            border: 4px solid #444;
            border-top: 4px solid #fde120;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .status {
            font-size: 1.2rem;
            margin: 1rem 0;
            color: #ccc;
        }
        
        .info {
            font-size: 1rem;
            color: #888;
            margin-top: 2rem;
            line-height: 1.4;
        }
        
        .back-link {
            margin-top: 2rem;
        }
        
        .back-link a {
            color: #fde120;
            text-decoration: none;
            border: 1px solid #fde120;
            padding: 0.5rem 1rem;
            border-radius: 4px;
            transition: all 0.3s ease;
        }
        
        .back-link a:hover {
            background: #fde120;
            color: #1a1a1a;
        }
    </style>
</head>
<body>
    <div class="loading-container">
        <h1>Fooocus Plus is Starting</h1>
        <div class="spinner"></div>
        <div class="status" id="status">Checking status...</div>
        <div class="info">
            Please wait while Fooocus Plus initializes. This may take a few minutes on first startup.<br>
            You will be automatically redirected when ready.
        </div>
        <div class="back-link">
            <a href="/">← Back to Services</a>
        </div>
    </div>
    
    <script>
        const FOOOCUS_PORT = 'FOOOCUS_PORT_PLACEHOLDER';
        const FOOOCUS_URL = 'http://' + window.location.hostname + ':' + FOOOCUS_PORT;
        
        let checkCount = 0;
        
        function updateStatus(message) {
            document.getElementById('status').textContent = message;
        }
        
        function checkFooocus() {
            checkCount++;
            updateStatus('Checking Fooocus status... (attempt ' + checkCount + ')');
            
            // Use fetch with no-cors mode to avoid CORS issues
            fetch(FOOOCUS_URL, { 
                mode: 'no-cors',
                cache: 'no-cache'
            }).then(() => {
                // If we get here, Fooocus responded
                updateStatus('Fooocus is ready! Redirecting...');
                window.location.replace(FOOOCUS_URL);
            }).catch(() => {
                // Fooocus not ready yet
                const now = new Date().toLocaleTimeString();
                updateStatus('Still starting... checked at ' + now);
                
                // Check again in 5 seconds
                setTimeout(checkFooocus, 5000);
            });
        }
        
        // Try immediate redirect first (in case Fooocus is already up)
        fetch(FOOOCUS_URL, { mode: 'no-cors', cache: 'no-cache' })
            .then(() => {
                // Fooocus is ready - redirect immediately without showing loading page
                window.location.replace(FOOOCUS_URL);
            })
            .catch(() => {
                // Fooocus not ready - show loading page and start checking
                document.body.style.display = 'flex';
                updateStatus('Fooocus is starting up...');
                
                // Start checking in 2 seconds
                setTimeout(checkFooocus, 2000);
            });
    </script>
</body>
</html>
EOF
    
    # Replace the Fooocus port placeholder with actual port
    sed -i "s/FOOOCUS_PORT_PLACEHOLDER/${FOOOCUS_PORT}/g" /opt/nginx/html/fooocus.html
    
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
    
    echo "nginx: configured for 2 worker processes (was auto/250+)"
    
    # Create simple nginx configuration
    cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /opt/nginx/html;
    index index.html;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Smart Fooocus redirect page
    location = /fooocus {
        try_files /fooocus.html =404;
    }
    
    # Disable access logs for favicon and robots.txt
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    location = /robots.txt {
        log_not_found off;
        access_log off;
    }
}
EOF

    # Start nginx
    nginx -t && nginx -g 'daemon off;' >${WORKSPACE}/logs/nginx.log 2>&1 &
    
    echo "nginx: started on port 80"
    echo "nginx: log file at ${WORKSPACE}/logs/nginx.log"
    echo "nginx: serving landing page at http://${EXTERNAL_IP}:80"
}

# Note: Function is called explicitly from start.sh
# No auto-execution when sourced to prevent duplicate processes