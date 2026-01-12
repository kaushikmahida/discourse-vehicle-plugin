#!/bin/bash
# Test the vehicle plugin locally
# This script verifies the plugin works in the local dev environment

set -e

echo "========================================"
echo "Testing Vehicle Plugin Locally"
echo "========================================"
echo ""

# Check if Docker container is running
if ! docker ps | grep -q discourse_dev; then
    echo "ERROR: discourse_dev container is not running"
    echo "Start it with: cd discourse-dev && bin/docker/boot_dev"
    exit 1
fi

echo "=== Testing plugin loading ==="
docker exec discourse_dev bash -c "cd /src && bundle exec rails runner \"begin; require_dependency 'plugins/discourse-vehicle-plugin/plugin.rb'; puts '✓ Plugin loads successfully'; rescue => e; puts '✗ ERROR: ' + e.message; exit 1; end\" 2>&1 | tail -3"

echo ""
echo "=== Testing VCDB data loading ==="
docker exec discourse_dev bash -c "cd /src && bundle exec rails runner \"data = DiscourseVehiclePlugin.vcdb_data; puts '✓ VCDB loaded: ' + data['years'].length.to_s + ' years, ' + data['makes'].length.to_s + ' makes'; rescue => e; puts '✗ ERROR: ' + e.message; exit 1; end\" 2>&1 | tail -3"

echo ""
echo "=== Testing API endpoints ==="
echo "Testing /vehicle-api/years..."
YEAR_RESPONSE=$(docker exec discourse_dev bash -c "curl -s http://localhost:3000/vehicle-api/years 2>&1")
if echo "$YEAR_RESPONSE" | grep -q '"years"'; then
    YEAR_COUNT=$(echo "$YEAR_RESPONSE" | grep -o '"years":\[.*\]' | grep -o ',' | wc -l | tr -d ' ')
    echo "✓ Years endpoint working ($((YEAR_COUNT + 1)) years)"
else
    echo "✗ Years endpoint failed: $YEAR_RESPONSE"
    exit 1
fi

echo ""
echo "Testing /vehicle-api/makes?year=2024..."
MAKE_RESPONSE=$(docker exec discourse_dev bash -c "curl -s 'http://localhost:3000/vehicle-api/makes?year=2024' 2>&1")
if echo "$MAKE_RESPONSE" | grep -q '"makes"'; then
    echo "✓ Makes endpoint working"
else
    echo "✗ Makes endpoint failed: $MAKE_RESPONSE"
    exit 1
fi

echo ""
echo "=== Testing plugin recognition ==="
docker exec discourse_dev bash -c "cd /src && bundle exec rails runner \"plugins = Discourse.plugins.map(&:name).grep(/vehicle/); if plugins.any?; puts '✓ Plugin recognized: ' + plugins.join(', '); else; puts '✗ Plugin not recognized'; exit 1; end\" 2>&1 | tail -2"

echo ""
echo "========================================"
echo "All tests passed! Plugin is working."
echo "========================================"
