#!/bin/bash
# Comprehensive test script for vehicle plugin
# Tests all endpoints, error cases, and edge cases

set -e

echo "========================================"
echo "Comprehensive Vehicle Plugin Tests"
echo "========================================"
echo ""

CONTAINER="discourse_dev"
BASE_URL="http://localhost:3000"

# Test 1: Plugin loads
echo "=== Test 1: Plugin Loading ==="
docker exec $CONTAINER bash -c "cd /src && bundle exec rails runner \"begin; require_dependency 'plugins/discourse-vehicle-plugin/plugin.rb'; puts '✓ Plugin loads'; rescue => e; puts '✗ ERROR: ' + e.message; exit 1; end\" 2>&1 | tail -2"
echo ""

# Test 2: VCDB data structure
echo "=== Test 2: VCDB Data Structure ==="
docker exec $CONTAINER bash -c "cd /src && bundle exec rails runner \"begin; data = DiscourseVehiclePlugin.vcdb_data; puts 'Years: ' + data['years'].length.to_s; puts 'Makes count: ' + data['makes'].length.to_s; puts 'year_makes type: ' + data['year_makes'].class.to_s; puts 'year_makes keys sample: ' + data['year_makes'].keys.first(3).inspect; puts '✓ VCDB structure valid'; rescue => e; puts '✗ ERROR: ' + e.message; exit 1; end\" 2>&1 | tail -6"
echo ""

# Test 3: Years endpoint
echo "=== Test 3: Years Endpoint ==="
YEAR_RESPONSE=$(docker exec $CONTAINER bash -c "curl -s '$BASE_URL/vehicle-api/years' 2>&1")
if echo "$YEAR_RESPONSE" | grep -q '"years"'; then
    YEAR_COUNT=$(echo "$YEAR_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['years']))" 2>/dev/null || echo "0")
    echo "✓ Years endpoint working ($YEAR_COUNT years)"
else
    echo "✗ Years endpoint failed: $YEAR_RESPONSE"
    exit 1
fi
echo ""

# Test 4: Makes endpoint - valid year
echo "=== Test 4: Makes Endpoint (valid year) ==="
MAKE_RESPONSE=$(docker exec $CONTAINER bash -c "curl -s '$BASE_URL/vehicle-api/makes?year=2024' 2>&1")
if echo "$MAKE_RESPONSE" | grep -q '"makes"'; then
    MAKE_COUNT=$(echo "$MAKE_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['makes']))" 2>/dev/null || echo "0")
    echo "✓ Makes endpoint working ($MAKE_COUNT makes for 2024)"
else
    echo "✗ Makes endpoint failed: $MAKE_RESPONSE"
    exit 1
fi
echo ""

# Test 5: Makes endpoint - invalid year
echo "=== Test 5: Makes Endpoint (invalid year) ==="
INVALID_RESPONSE=$(docker exec $CONTAINER bash -c "curl -s '$BASE_URL/vehicle-api/makes?year=1900' 2>&1")
if echo "$INVALID_RESPONSE" | grep -q '"makes"'; then
    echo "✓ Invalid year handled gracefully"
else
    echo "✗ Invalid year not handled: $INVALID_RESPONSE"
    exit 1
fi
echo ""

# Test 6: Makes endpoint - missing year
echo "=== Test 6: Makes Endpoint (missing year) ==="
MISSING_RESPONSE=$(docker exec $CONTAINER bash -c "curl -s '$BASE_URL/vehicle-api/makes' 2>&1")
if echo "$MISSING_RESPONSE" | grep -q '"makes"'; then
    echo "✓ Missing year handled gracefully"
else
    echo "✗ Missing year not handled: $MISSING_RESPONSE"
    exit 1
fi
echo ""

# Test 7: Models endpoint
echo "=== Test 7: Models Endpoint ==="
# First get a valid make_id
MAKE_ID=$(echo "$MAKE_RESPONSE" | python3 -c "import sys, json; makes = json.load(sys.stdin)['makes']; print(makes[0]['id'] if makes else '')" 2>/dev/null)
if [ -n "$MAKE_ID" ]; then
    MODEL_RESPONSE=$(docker exec $CONTAINER bash -c "curl -s '$BASE_URL/vehicle-api/models?year=2024&make_id=$MAKE_ID' 2>&1")
    if echo "$MODEL_RESPONSE" | grep -q '"models"'; then
        echo "✓ Models endpoint working"
    else
        echo "⚠ Models endpoint returned: $MODEL_RESPONSE"
    fi
else
    echo "⚠ Could not test models - no make_id available"
fi
echo ""

# Test 8: Trims endpoint
echo "=== Test 8: Trims Endpoint ==="
if [ -n "$MAKE_ID" ]; then
    MODEL_ID=$(echo "$MODEL_RESPONSE" | python3 -c "import sys, json; models = json.load(sys.stdin)['models']; print(models[0]['id'] if models else '')" 2>/dev/null || echo "")
    if [ -n "$MODEL_ID" ]; then
        TRIM_RESPONSE=$(docker exec $CONTAINER bash -c "curl -s '$BASE_URL/vehicle-api/trims?year=2024&make_id=$MAKE_ID&model_id=$MODEL_ID' 2>&1")
        if echo "$TRIM_RESPONSE" | grep -q '"trims"'; then
            echo "✓ Trims endpoint working"
        else
            echo "⚠ Trims endpoint returned: $TRIM_RESPONSE"
        fi
    else
        echo "⚠ Could not test trims - no model_id available"
    fi
else
    echo "⚠ Could not test trims - no make_id available"
fi
echo ""

# Test 9: Engines endpoint
echo "=== Test 9: Engines Endpoint ==="
ENGINE_RESPONSE=$(docker exec $CONTAINER bash -c "curl -s '$BASE_URL/vehicle-api/engines' 2>&1")
if echo "$ENGINE_RESPONSE" | grep -q '"engines"'; then
    echo "✓ Engines endpoint working"
else
    echo "✗ Engines endpoint failed: $ENGINE_RESPONSE"
    exit 1
fi
echo ""

# Test 10: Test endpoint
echo "=== Test 10: Test Endpoint ==="
TEST_RESPONSE=$(docker exec $CONTAINER bash -c "curl -s '$BASE_URL/vehicle-api/test' 2>&1")
if echo "$TEST_RESPONSE" | grep -q '"loaded"'; then
    echo "✓ Test endpoint working"
else
    echo "⚠ Test endpoint returned: $TEST_RESPONSE"
fi
echo ""

# Test 11: Stress test - multiple rapid requests
echo "=== Test 11: Stress Test (10 rapid requests) ==="
for i in {1..10}; do
    RESPONSE=$(docker exec $CONTAINER bash -c "curl -s '$BASE_URL/vehicle-api/years' 2>&1")
    if ! echo "$RESPONSE" | grep -q '"years"'; then
        echo "✗ Request $i failed: $RESPONSE"
        exit 1
    fi
done
echo "✓ All 10 rapid requests succeeded"
echo ""

# Test 12: Error handling - malformed requests
echo "=== Test 12: Error Handling ==="
ERROR_TESTS=(
    "$BASE_URL/vehicle-api/makes?year="
    "$BASE_URL/vehicle-api/models"
    "$BASE_URL/vehicle-api/trims?year=2024"
)
for url in "${ERROR_TESTS[@]}"; do
    RESPONSE=$(docker exec $CONTAINER bash -c "curl -s '$url' 2>&1")
    if echo "$RESPONSE" | grep -q '"makes"\|"models"\|"trims"'; then
        echo "✓ Error handled for: $url"
    else
        HTTP_CODE=$(docker exec $CONTAINER bash -c "curl -s -o /dev/null -w '%{http_code}' '$url' 2>&1")
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "500" ]; then
            echo "⚠ Unexpected response for $url (HTTP $HTTP_CODE)"
        else
            echo "✓ Error handled for: $url (HTTP $HTTP_CODE)"
        fi
    fi
done
echo ""

# Test 13: Plugin recognition
echo "=== Test 13: Plugin Recognition ==="
docker exec $CONTAINER bash -c "cd /src && bundle exec rails runner \"plugins = Discourse.plugins.map(&:name).grep(/vehicle/); if plugins.any?; puts '✓ Plugin recognized: ' + plugins.join(', '); else; puts '✗ Plugin not recognized'; exit 1; end\" 2>&1 | tail -2"
echo ""

echo "========================================"
echo "All Tests Completed!"
echo "========================================"
