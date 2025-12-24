#!/bin/bash
set -e

echo "=== Synchronet BBS Installer ==="

# Build the image first
echo "[1/5] Building Docker image..."
docker compose build

# Create directories for persistent data
echo "[2/5] Creating directories..."
mkdir -p ctrl data mods

# Check if ctrl is empty or missing key files
if [ ! -f "./ctrl/sbbs.ini" ]; then
    echo "[3/5] Extracting default config files..."
    
    # Create a temporary container (don't start it)
    docker create --name sbbs-temp bbs-synchronet
    
    # Copy the ctrl directory from the image
    docker cp sbbs-temp:/sbbs/ctrl/. ./ctrl/
    
    # Remove the temporary container
    docker rm sbbs-temp
    
    echo "Config files extracted to ./ctrl/"
else
    echo "[3/5] Config files already exist, skipping extraction"
fi

# List what we have
echo ""
echo "=== Config files in ./ctrl/ ==="
ls -la ./ctrl/ | head -20

# Run scfg BEFORE starting the main container to generate .cnf files
echo ""
echo "[4/5] Running initial configuration (scfg)..."
echo "This will open the Synchronet Configuration utility."
echo "Set up your BBS name and settings, then save and exit (ESC, Y)."
echo ""
read -p "Press Enter to launch scfg..."

docker run -it --rm \
    --entrypoint /sbbs/exec/scfg \
    -v "$(pwd)/ctrl:/sbbs/ctrl" \
    -v "$(pwd)/data:/sbbs/data" \
    -v "$(pwd)/mods:/sbbs/mods" \
    -e TERM=xterm \
    bbs-synchronet

# Verify config was saved (scfg saves to main.ini)
if [ -f "./ctrl/main.ini" ]; then
    echo ""
    echo "Configuration saved successfully!"
    echo "Config file: ./ctrl/main.ini"
    ls -la ./ctrl/main.ini
    
    # Remove passwords from ini files for git safety
    echo ""
    echo "Removing passwords from config files (will be injected from environment)..."
    for ini_file in ./ctrl/main.ini ./ctrl/main.*.ini; do
        if [ -f "$ini_file" ]; then
            # Replace only the FIRST password= line (sysop password) with placeholder
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS sed
                sed -i '' '1,/^password=/{s/^password=.*/password=SET_VIA_ENV/;}' "$ini_file"
            else
                # Linux sed
                sed -i '0,/^password=/{s/^password=.*/password=SET_VIA_ENV/}' "$ini_file"
            fi
            echo "  Sanitized: $ini_file"
        fi
    done
    echo "Passwords removed. Set SYSOP_PASSWORD environment variable in Portainer."
else
    echo ""
    echo "WARNING: main.ini not found. BBS may not start properly."
    echo "You may need to run scfg again and save your configuration."
    echo ""
    echo "Current ctrl/ contents:"
    ls -la ./ctrl/ | head -20
fi

# Now start the container
echo ""
echo "[5/5] Starting Synchronet BBS..."
docker compose up -d

# Wait for container to be ready
echo "Waiting for container to start..."
sleep 5

# Generate SSH keys if needed
echo ""
echo "Generating SSH keys..."
docker exec SynchronetBBS bash -c "rm -f /sbbs/ctrl/cryptlib.key 2>/dev/null; /sbbs/exec/sbbsecho -k 2>/dev/null || true"

# Alternative: restart to regenerate keys
docker compose restart
sleep 3

echo ""
echo "=== Container Status ==="
docker ps --filter name=SynchronetBBS --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== Recent Logs ==="
docker logs --tail 20 SynchronetBBS 2>&1 || true

echo ""
echo "=== Installation Complete ==="
echo ""
echo "If the container is running, connect via:"
echo "  Telnet:  telnet localhost 10023"
echo "  SSH:     ssh -p 10022 localhost"
echo "  Web:     http://localhost:10080"
echo "  FTP:     ftp://localhost:10021"
echo ""
echo "To reconfigure: docker exec -it SynchronetBBS /sbbs/exec/scfg"
echo "To view logs:   docker logs -f SynchronetBBS"
echo "To stop:        docker compose down"