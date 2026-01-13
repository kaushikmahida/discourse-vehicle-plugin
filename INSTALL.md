# Discourse Vehicle Plugin - Installation Guide

## Overview
This plugin adds vehicle information fields (Year, Make, Model, Trim, Engine) to Discourse topics using ACES VCDB data. The plugin uses a **database-backed approach** for reliability and performance, ensuring data persists across Discourse updates.

## Installation Methods

### Method 1: Persistent Deployment Script (Recommended)

This method ensures the plugin and database persist across Discourse updates:

```bash
git clone https://github.com/kaushikmahida/discourse-vehicle-plugin.git
cd discourse-vehicle-plugin
./deploy_persistent.sh
```

This script will:
1. Clone/update the plugin from GitHub to `/shared/plugins/discourse-vehicle-plugin`
2. Create a symlink in Discourse's plugin directory
3. Run database migrations (idempotent - safe to run multiple times)
4. Import VCDB data if tables are empty
5. Enable the plugin
6. Restart Unicorn

**The database tables and data will persist even when Discourse is updated.**

### Method 2: Install from GitHub (Manual)

```bash
cd /var/discourse/shared/standalone/plugins
sudo git clone https://github.com/kaushikmahida/discourse-vehicle-plugin.git discourse-vehicle-plugin
cd discourse-vehicle-plugin
sudo chown -R root:root .
```

Then copy your VCDB data file:
```bash
sudo mkdir -p data
sudo cp /path/to/your/vcdb.json data/
```

Run migrations and import data:
```bash
sudo docker exec app bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rails db:migrate'"
sudo docker exec app bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rake vehicle_data:import'"
```

Rebuild Discourse:
```bash
cd /var/discourse
sudo ./launcher rebuild app
```

### Method 3: Manual Installation

1. Download or clone the repository
2. Copy the entire plugin directory to `/var/discourse/shared/standalone/plugins/discourse-vehicle-plugin`
3. Copy your `vcdb.json` file to `data/vcdb.json`
4. Set permissions: `sudo chown -R root:root discourse-vehicle-plugin`
5. Run migrations: `docker exec app bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rails db:migrate'"`
6. Import data: `docker exec app bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rake vehicle_data:import'"`
7. Rebuild Discourse: `cd /var/discourse && sudo ./launcher rebuild app`

## VCDB Data File

The plugin requires a `vcdb.json` file in the `data/` directory. This file is generated from ACES VCDB data using the included `scripts/process_vcdb.py` script.

**Note:** The `vcdb.json` file is NOT included in the repository due to its size (~2.1MB). You must provide your own.

**Important:** After providing the `vcdb.json` file, you must import it into the database:
```bash
docker exec app bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rake vehicle_data:import'"
```

This imports all vehicle data into database tables, which is much faster and more reliable than loading from JSON on every request.

## Requirements

- Discourse 2.7.0 or higher
- Ruby 3.3+
- ACES VCDB data file (processed)

## Configuration

After installation, enable the plugin in Discourse:
1. Go to **Admin > Plugins**
2. Find "discourse-vehicle-plugin"
3. Ensure it's enabled

The plugin is enabled by default via the site setting `vehicle_fields_enabled`.

## Verification

1. Check plugin is loaded:
   ```bash
   docker exec app rails runner "puts Discourse.plugins.map(&:name).grep(/vehicle/)"
   ```

2. Test API endpoint:
   ```bash
   curl http://your-domain.com/vehicle-api/years
   ```

3. Create a new topic - vehicle fields should appear in the composer

## Troubleshooting

### Plugin Not Appearing
- Check plugin is in `/var/discourse/shared/standalone/plugins/discourse-vehicle-plugin`
- Verify file permissions: `sudo chown -R root:root`
- Rebuild Discourse: `cd /var/discourse && sudo ./launcher rebuild app`

### VCDB Data Not Loading
- Verify `data/vcdb.json` exists and is readable
- Check if data is imported: `docker exec app rails runner "puts VehicleYear.count"`
- If count is 0, import data: `docker exec app bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rake vehicle_data:import'"`
- Check logs: `docker exec app tail -f /var/www/discourse/log/production.log | grep VehiclePlugin`
- Test API: `curl http://your-domain.com/vehicle-api/test`

### API Endpoints Not Working
- Check routes: `docker exec app rails routes | grep vehicle-api`
- Restart Unicorn: `docker exec app sv restart unicorn`

## Updating

### Using Persistent Deployment Script (Recommended)

```bash
./deploy_persistent.sh
```

This will:
- Pull latest code from GitHub
- Run any new migrations automatically
- Preserve all existing database data
- Restart services

### Manual Update

```bash
cd /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin
sudo git pull
sudo docker exec app bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rails db:migrate'"
sudo docker exec app sv restart unicorn
```

**Note:** Database tables and data persist across updates. You only need to re-import data if you have a new `vcdb.json` file.

## Support

For issues or questions, please open an issue on GitHub:
https://github.com/kaushikmahida/discourse-vehicle-plugin
