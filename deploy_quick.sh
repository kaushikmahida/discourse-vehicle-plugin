#!/bin/bash
# Quick Deploy Vehicle Plugin (without full rebuild)
# Copies files directly into running container
# 
# Usage: ./deploy_quick.sh [server_ip]
# Example: ./deploy_quick.sh 10.0.132.68

set -e

SERVER_IP="${1:-10.0.132.68}"
KEY_PATH="${HOME}/Documents/Keys/RS2/Prod/rs2-discourse.pem"
PLUGIN_NAME="discourse-vehicle-plugin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Quick Deploy Vehicle Plugin"
echo "========================================"
echo "Server: $SERVER_IP"
echo ""

# Check if key exists
if [ ! -f "$KEY_PATH" ]; then
    echo "ERROR: SSH key not found at $KEY_PATH"
    exit 1
fi

# Get container name
echo "=== Finding Discourse container ==="
CONTAINER_NAME=$(ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" "sudo docker ps --format '{{.Names}}' | grep -E '^app$|discourse' | head -1")
if [ -z "$CONTAINER_NAME" ]; then
    echo "ERROR: Discourse container not found"
    exit 1
fi
echo "✓ Found container: $CONTAINER_NAME"

# Copy plugin files directly to container
echo ""
echo "=== Copying plugin files to container ==="
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" "sudo docker exec $CONTAINER_NAME mkdir -p /var/www/discourse/plugins/$PLUGIN_NAME"

# Copy each file/directory
for item in plugin.rb assets config lib app scripts data; do
    if [ -e "$SCRIPT_DIR/$item" ]; then
        echo "  Copying $item..."
        docker cp "$SCRIPT_DIR/$item" "$(ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" "sudo docker ps -q --filter name=$CONTAINER_NAME"):/var/www/discourse/plugins/$PLUGIN_NAME/" 2>/dev/null || \
        ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" "sudo docker cp - $CONTAINER_NAME:/var/www/discourse/plugins/$PLUGIN_NAME/$item < $SCRIPT_DIR/$item" 2>/dev/null || \
        scp -i "$KEY_PATH" -r "$SCRIPT_DIR/$item" ubuntu@"$SERVER_IP":/tmp/plugin_$item && \
        ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" "sudo docker cp /tmp/plugin_$item $CONTAINER_NAME:/var/www/discourse/plugins/$PLUGIN_NAME/$item && sudo rm -rf /tmp/plugin_$item"
    fi
done

# Also copy to persistent location for future rebuilds
echo ""
echo "=== Copying to persistent location ==="
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" << ENDSSH
    sudo mkdir -p /var/discourse/shared/standalone/plugins/$PLUGIN_NAME
    sudo docker cp $CONTAINER_NAME:/var/www/discourse/plugins/$PLUGIN_NAME /var/discourse/shared/standalone/plugins/ 2>/dev/null || \
    (sudo rm -rf /var/discourse/shared/standalone/plugins/$PLUGIN_NAME && \
     sudo cp -r /tmp/plugin_* /var/discourse/shared/standalone/plugins/$PLUGIN_NAME/ 2>/dev/null || true)
    sudo chown -R root:root /var/discourse/shared/standalone/plugins/$PLUGIN_NAME
    echo "✓ Plugin copied to persistent location"
ENDSSH

# Restart services
echo ""
echo "=== Restarting services ==="
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" "sudo docker exec $CONTAINER_NAME sv restart unicorn"
sleep 3
ssh -i "$KEY_PATH" ubuntu@"$SERVER_IP" "sudo docker exec $CONTAINER_NAME sv restart sidekiq" || true

echo ""
echo "========================================"
echo "Quick deployment complete!"
echo "========================================"
echo ""
echo "Plugin installed. Changes should be live in ~30 seconds."
echo ""
