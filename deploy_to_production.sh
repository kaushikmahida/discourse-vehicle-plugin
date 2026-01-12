#!/bin/bash
# Deploy Vehicle Plugin to Production Discourse Server
# 
# Usage: ./deploy_to_production.sh [server_ip]
# Example: ./deploy_to_production.sh 10.0.132.68

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
    exit 1
fi

# Check if plugin directory exists
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "ERROR: Plugin directory not found: $SCRIPT_DIR"
    exit 1
fi

# Create temp directory for plugin
TEMP_DIR=$(mktemp -d)
echo "=== Preparing plugin files ==="
cp -r "$SCRIPT_DIR"/* "$TEMP_DIR/"
# Remove unnecessary files
rm -rf "$TEMP_DIR"/.git "$TEMP_DIR"/node_modules "$TEMP_DIR"/*.log 2>/dev/null || true
echo "✓ Plugin files prepared"

# Copy plugin to server's persistent plugins directory
echo ""
echo "=== Copying plugin to server ==="
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" "sudo mkdir -p /var/discourse/shared/standalone/plugins"
scp -i "$KEY_PATH" -r "$TEMP_DIR" ubuntu@"$SERVER_IP":/tmp/$PLUGIN_NAME

# Move to persistent location and set permissions
echo ""
echo "=== Installing plugin ==="
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" << 'ENDSSH'
    sudo rm -rf /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin
    sudo mv /tmp/discourse-vehicle-plugin /var/discourse/shared/standalone/plugins/
    sudo chown -R root:root /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin
    sudo chmod -R 755 /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin
    echo "✓ Plugin installed to persistent location"
ENDSSH

# Verify VCDB file exists
echo ""
echo "=== Verifying VCDB data ==="
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" << 'ENDSSH'
    if [ -f "/var/discourse/shared/standalone/plugins/discourse-vehicle-plugin/data/vcdb.json" ]; then
        VCDB_SIZE=$(du -h /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin/data/vcdb.json | cut -f1)
        echo "✓ VCDB file found ($VCDB_SIZE)"
    else
        echo "⚠ WARNING: VCDB file not found - plugin may not work correctly"
    fi
ENDSSH

# Rebuild Discourse to include the plugin
echo ""
echo "=== Rebuilding Discourse container (this may take a few minutes) ==="
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" << 'ENDSSH'
    cd /var/discourse
    sudo ./launcher rebuild app
    echo "✓ Discourse rebuilt with plugin"
ENDSSH

# Cleanup temp directory
rm -rf "$TEMP_DIR"

echo ""
echo "========================================"
echo "Deployment Complete!"
echo "========================================"
echo ""
echo "The plugin is now installed in:"
echo "  /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin"
echo ""
echo "This location persists through Discourse updates."
echo ""
echo "To verify, check the plugin in Admin > Plugins"
echo ""
