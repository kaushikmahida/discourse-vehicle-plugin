# Vehicle Plugin Deployment Guide

## Overview
This plugin is deployed to `/var/discourse/shared/standalone/plugins/discourse-vehicle-plugin` which is a **persistent volume** that survives Discourse updates and container rebuilds.

## Prerequisites
- SSH access to production server
- SSH key: `~/Documents/Keys/RS2/Prod/rs2-discourse.pem`
- Server IPs: `10.0.132.68` or `10.0.131.255`

## Automated Deployment

### Option 1: Full Deployment (Recommended)
This rebuilds Discourse to ensure everything is properly integrated:

```bash
cd "/Users/kaushikm/Documents/Code/RS2 Code/prod_discourse_setup/discourse-vehicle-plugin"
./deploy.sh 10.0.132.68
```

**Time:** 5-10 minutes (includes rebuild)

### Option 2: Quick Deployment
If you need faster deployment without rebuild:

```bash
./deploy_quick.sh 10.0.132.68
```

**Time:** 1-2 minutes (just restarts services)

## Manual Deployment

If automated scripts don't work, follow these steps:

### 1. Prepare Plugin Package
```bash
cd "/Users/kaushikm/Documents/Code/RS2 Code/prod_discourse_setup/discourse-vehicle-plugin"
tar --exclude='.git' --exclude='node_modules' --exclude='*.log' \
    -czf /tmp/vehicle-plugin.tar.gz .
```

### 2. Copy to Server
```bash
scp -i ~/Documents/Keys/RS2/Prod/rs2-discourse.pem \
    /tmp/vehicle-plugin.tar.gz \
    ubuntu@10.0.132.68:/tmp/
```

### 3. SSH to Server and Install
```bash
ssh -i ~/Documents/Keys/RS2/Prod/rs2-discourse.pem ubuntu@10.0.132.68
```

Then on the server:
```bash
# Create plugin directory
sudo mkdir -p /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin

# Extract plugin
cd /tmp
sudo tar -xzf vehicle-plugin.tar.gz -C /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin

# Set permissions
sudo chown -R root:root /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin
sudo chmod -R 755 /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin

# Verify VCDB file
ls -lh /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin/data/vcdb.json

# Rebuild Discourse
cd /var/discourse
sudo ./launcher rebuild app
```

## Verification

### 1. Check Plugin Location
```bash
ssh -i ~/Documents/Keys/RS2/Prod/rs2-discourse.pem ubuntu@10.0.132.68 \
    "ls -la /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin"
```

### 2. Check Plugin in Discourse
1. Log into Discourse as admin
2. Go to **Admin > Plugins**
3. Look for "discourse-vehicle-plugin"
4. Verify it's enabled

### 3. Test Vehicle Fields
1. Create a new topic
2. Verify vehicle dropdowns appear (Year → Make → Model → Trim)
3. Test selecting values

### 4. Check API Endpoint
```bash
curl http://your-discourse-domain.com/vehicle-api/test
```

Should return JSON with VCDB status.

## Persistence Through Updates

The plugin is installed in `/var/discourse/shared/standalone/plugins/` which is:
- A **persistent Docker volume**
- Automatically included in Discourse rebuilds
- **Survives Discourse updates**

When you run `./launcher rebuild app`, Discourse automatically includes all plugins from this directory.

## Troubleshooting

### Plugin Not Appearing
1. Check plugin is in correct location:
   ```bash
   ls -la /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin
   ```

2. Check Discourse logs:
   ```bash
   sudo docker exec app tail -100 /var/www/discourse/log/production.log | grep vehicle
   ```

3. Rebuild Discourse:
   ```bash
   cd /var/discourse
   sudo ./launcher rebuild app
   ```

### VCDB Not Loading
1. Verify VCDB file exists:
   ```bash
   ls -lh /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin/data/vcdb.json
   ```

2. Check file size (should be ~2.1MB)

3. Test VCDB loading:
   ```bash
   sudo docker exec app rails runner "puts DiscourseVehiclePlugin.vcdb_data['years'].length"
   ```
   Should return `37`

### API Endpoints Not Working
1. Check routes are registered:
   ```bash
   sudo docker exec app rails routes | grep vehicle-api
   ```

2. Restart Unicorn:
   ```bash
   sudo docker exec app sv restart unicorn
   ```

## Files Deployed

- `plugin.rb` - Main plugin file with API endpoints
- `assets/javascripts/` - Frontend JavaScript and templates
- `assets/stylesheets/` - CSS styles
- `config/locales/` - Translations
- `data/vcdb.json` - Vehicle database (2.1MB)
- `scripts/process_vcdb.py` - VCDB processing script (for future updates)

## Updating the Plugin

To update the plugin in the future:

1. Make changes locally
2. Run deployment script again:
   ```bash
   ./deploy.sh 10.0.132.68
   ```

The script will:
- Backup existing plugin
- Install new version
- Rebuild Discourse
- Preserve all data

## Multiple Servers

If you have multiple Discourse servers, deploy to each:

```bash
./deploy.sh 10.0.132.68
./deploy.sh 10.0.131.255
```
