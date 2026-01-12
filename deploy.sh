#!/bin/bash
# Deploy Vehicle Plugin to Production Discourse Server
# Ensures plugin persists through Discourse updates
# 
# Usage: ./deploy.sh [server_ip]
# Example: ./deploy.sh 10.0.132.68

set -e

SERVER_IP="${1:-10.0.132.68}"
KEY_PATH="${HOME}/Documents/Keys/RS2/Prod/rs2-discourse.pem"
PLUGIN_NAME="discourse-vehicle-plugin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Deploying Vehicle Plugin to Production"
echo "========================================"
echo "Server: $SERVER_IP"
echo "Plugin: $PLUGIN_NAME"
echo ""

# Check if key exists
if [ ! -f "$KEY_PATH" ]; then
    echo "ERROR: SSH key not found at $KEY_PATH"
    echo "Please update KEY_PATH in the script or provide key at that location"
    exit 1
fi

# Check if plugin directory exists
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "ERROR: Plugin directory not found: $SCRIPT_DIR"
    exit 1
fi

# Create temp tarball
echo "=== Preparing plugin package ==="
TEMP_DIR=$(mktemp -d)
cd "$SCRIPT_DIR"
tar --exclude='.git' --exclude='node_modules' --exclude='*.log' --exclude='deploy*.sh' \
    -czf "$TEMP_DIR/plugin.tar.gz" .
echo "✓ Plugin packaged"

# Copy to server
echo ""
echo "=== Uploading plugin to server ==="
scp -i "$KEY_PATH" "$TEMP_DIR/plugin.tar.gz" ubuntu@"$SERVER_IP":/tmp/

# Install on server
echo ""
echo "=== Installing plugin on server ==="
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" << 'ENDSSH'
    PLUGIN_NAME="discourse-vehicle-plugin"
    PLUGIN_DIR="/var/discourse/shared/standalone/plugins/$PLUGIN_NAME"
    
    # Create plugin directory in persistent location
    sudo mkdir -p "$PLUGIN_DIR"
    
    # Extract plugin
    cd /tmp
    sudo tar -xzf plugin.tar.gz -C "$PLUGIN_DIR"
    sudo rm -f plugin.tar.gz
    
    # Set proper permissions
    sudo chown -R root:root "$PLUGIN_DIR"
    sudo chmod -R 755 "$PLUGIN_DIR"
    
    # Verify VCDB file
    if [ -f "$PLUGIN_DIR/data/vcdb.json" ]; then
        VCDB_SIZE=$(sudo du -h "$PLUGIN_DIR/data/vcdb.json" | cut -f1)
        echo "✓ VCDB file found ($VCDB_SIZE)"
    else
        echo "⚠ WARNING: VCDB file not found"
    fi
    
    echo "✓ Plugin installed to: $PLUGIN_DIR"
ENDSSH

# Rebuild Discourse to include plugin
echo ""
echo "=== Rebuilding Discourse (this takes 5-10 minutes) ==="
echo "This ensures the plugin is properly integrated and will persist through updates"
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" << 'ENDSSH'
    cd /var/discourse
    echo "Starting rebuild..."
    sudo ./launcher rebuild app
    echo "✓ Rebuild complete"
ENDSSH

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "========================================"
echo "Deployment Complete!"
echo "========================================"
echo ""
echo "Plugin location: /var/discourse/shared/standalone/plugins/$PLUGIN_NAME"
echo "This location persists through Discourse updates."
echo ""
echo "To verify:"
echo "  1. SSH to server and check: ls -la /var/discourse/shared/standalone/plugins/"
echo "  2. Check Admin > Plugins in Discourse UI"
echo "  3. Test vehicle fields in composer"
echo ""
