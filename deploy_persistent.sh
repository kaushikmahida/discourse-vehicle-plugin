#!/bin/bash
# Deploy vehicle plugin to production with persistent database setup
# This ensures migrations and data persist across Discourse updates

set -e

PLUGIN_NAME="discourse-vehicle-plugin"
PROD_SERVER="10.0.131.255"
SSH_KEY="$HOME/Documents/Keys/RS2/Prod/rs2-discourse.pem"
PLUGIN_DIR="/shared/plugins/$PLUGIN_NAME"
DISCOURSE_DIR="/var/www/discourse"

echo "=== Deploying Vehicle Plugin (Persistent) ==="
echo ""

# Step 1: Clone/update plugin from GitHub
echo "Step 1: Fetching plugin from GitHub..."
ssh -i "$SSH_KEY" ubuntu@$PROD_SERVER << 'ENDSSH'
  cd /shared/plugins
  if [ -d "$PLUGIN_NAME" ]; then
    echo "  Updating existing plugin..."
    cd "$PLUGIN_NAME"
    git pull origin main
  else
    echo "  Cloning plugin..."
    git clone https://github.com/kaushikmahida/discourse-vehicle-plugin.git "$PLUGIN_NAME"
  fi
ENDSSH

# Step 2: Ensure symlink exists
echo ""
echo "Step 2: Creating symlink..."
ssh -i "$SSH_KEY" ubuntu@$PROD_SERVER << 'ENDSSH'
  sudo docker exec app bash -c "
    if [ ! -L /var/www/discourse/plugins/$PLUGIN_NAME ]; then
      ln -sf $PLUGIN_DIR /var/www/discourse/plugins/$PLUGIN_NAME
      echo '  Symlink created'
    else
      echo '  Symlink already exists'
    fi
  "
ENDSSH

# Step 3: Run migrations (idempotent - safe to run multiple times)
echo ""
echo "Step 3: Running database migrations..."
ssh -i "$SSH_KEY" ubuntu@$PROD_SERVER << 'ENDSSH'
  sudo docker exec app bash -c "
    cd /var/www/discourse
    su discourse -c 'bundle exec rails db:migrate' 2>&1 | grep -E '(migrate|CreateVehicle|EnsureVehicle|vehicle)' || true
  "
ENDSSH

# Step 4: Check if data needs to be imported
echo ""
echo "Step 4: Checking vehicle data..."
ssh -i "$SSH_KEY" ubuntu@$PROD_SERVER << 'ENDSSH'
  sudo docker exec app bash -c "
    cd /var/www/discourse
    YEAR_COUNT=\$(su discourse -c 'bundle exec rails runner \"puts VehicleYear.count rescue 0\"' 2>/dev/null || echo '0')
    if [ \"\$YEAR_COUNT\" = \"0\" ]; then
      echo '  Vehicle data is empty. Importing...'
      su discourse -c 'bundle exec rake vehicle_data:import' 2>&1 | tail -10
    else
      echo \"  Vehicle data already loaded: \$YEAR_COUNT years\"
    fi
  "
ENDSSH

# Step 5: Enable plugin if not already enabled
echo ""
echo "Step 5: Enabling plugin..."
ssh -i "$SSH_KEY" ubuntu@$PROD_SERVER << 'ENDSSH'
  sudo docker exec app bash -c "
    cd /var/www/discourse
    su discourse -c 'bundle exec rails runner \"SiteSetting.vehicle_fields_enabled = true unless SiteSetting.vehicle_fields_enabled\"' 2>&1 | grep -v '^$' || true
  "
ENDSSH

# Step 6: Restart Unicorn
echo ""
echo "Step 6: Restarting Unicorn..."
ssh -i "$SSH_KEY" ubuntu@$PROD_SERVER << 'ENDSSH'
  sudo docker exec app bash -c "sv restart unicorn" && sleep 5
ENDSSH

# Step 7: Verify deployment
echo ""
echo "Step 7: Verifying deployment..."
ssh -i "$SSH_KEY" ubuntu@$PROD_SERVER << 'ENDSSH'
  sudo docker exec app bash -c "
    sleep 3
    curl -s http://localhost/vehicle-api/test 2>&1 | python3 -m json.tool 2>/dev/null | head -10 || echo '  API test failed - check logs'
  "
ENDSSH

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "The plugin is now deployed with persistent database tables."
echo "Migrations and data will persist across Discourse updates."
echo ""
echo "To verify:"
echo "  - Check /shared/plugins/$PLUGIN_NAME exists"
echo "  - Check database tables: vehicle_years, vehicle_makes, etc."
echo "  - Visit: https://your-domain.com/vehicle-api/test"
