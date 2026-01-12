#!/bin/bash
# Deploy Vehicle Plugin from GitHub to Production
# This script fetches the plugin from GitHub and deploys it
# 
# Usage: ./deploy_from_github.sh [server_ip] [branch]
# Example: ./deploy_from_github.sh 10.0.131.255 main

set -e

SERVER_IP="${1:-10.0.131.255}"
BRANCH="${2:-main}"
KEY_PATH="${HOME}/Documents/Keys/RS2/Prod/rs2-discourse.pem"
PLUGIN_NAME="discourse-vehicle-plugin"
GITHUB_REPO="https://github.com/kaushikmahida/discourse-vehicle-plugin.git"

echo "========================================"
echo "Deploying Vehicle Plugin from GitHub"
echo "========================================"
echo "Server: $SERVER_IP"
echo "Branch: $BRANCH"
echo "Repository: $GITHUB_REPO"
echo ""

# Check if key exists
if [ ! -f "$KEY_PATH" ]; then
    echo "ERROR: SSH key not found at $KEY_PATH"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
echo "=== Cloning plugin from GitHub ==="
git clone --depth 1 --branch "$BRANCH" "$GITHUB_REPO" "$TEMP_DIR/$PLUGIN_NAME" || {
    echo "ERROR: Failed to clone repository"
    rm -rf "$TEMP_DIR"
    exit 1
}
echo "✓ Plugin cloned"

# Create tarball
echo ""
echo "=== Packaging plugin ==="
cd "$TEMP_DIR"
tar --exclude='.git' --exclude='node_modules' --exclude='*.log' \
    -czf "$TEMP_DIR/plugin.tar.gz" "$PLUGIN_NAME"
echo "✓ Plugin packaged"

# Copy to server
echo ""
echo "=== Uploading to server ==="
scp -i "$KEY_PATH" "$TEMP_DIR/plugin.tar.gz" ubuntu@"$SERVER_IP":/tmp/

# Install on server
echo ""
echo "=== Installing on server ==="
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" << 'ENDSSH'
    PLUGIN_NAME="discourse-vehicle-plugin"
    PLUGIN_DIR="/var/discourse/shared/standalone/plugins/$PLUGIN_NAME"
    
    # Backup existing plugin if it exists
    if [ -d "$PLUGIN_DIR" ]; then
        sudo mv "$PLUGIN_DIR" "${PLUGIN_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✓ Backed up existing plugin"
    fi
    
    # Create plugin directory
    sudo mkdir -p "$PLUGIN_DIR"
    
    # Extract plugin
    cd /tmp
    sudo tar -xzf plugin.tar.gz -C "$PLUGIN_DIR" --strip-components=1
    sudo rm -f plugin.tar.gz
    
    # Set proper permissions
    sudo chown -R root:root "$PLUGIN_DIR"
    sudo chmod -R 755 "$PLUGIN_DIR"
    
    # Check if VCDB file needs to be copied (if it exists in backup)
    BACKUP_DIR=$(ls -td ${PLUGIN_DIR}.backup.* 2>/dev/null | head -1)
    if [ -n "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/data/vcdb.json" ]; then
        sudo mkdir -p "$PLUGIN_DIR/data"
        sudo cp "$BACKUP_DIR/data/vcdb.json" "$PLUGIN_DIR/data/vcdb.json"
        echo "✓ VCDB file restored from backup"
    else
        echo "⚠ VCDB file not found - you may need to copy it manually"
    fi
    
    echo "✓ Plugin installed to: $PLUGIN_DIR"
ENDSSH

# Rebuild Discourse
echo ""
echo "=== Rebuilding Discourse (this takes 5-10 minutes) ==="
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
