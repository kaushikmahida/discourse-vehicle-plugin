# Discourse Vehicle Plugin - Installation Guide

## Overview
This plugin adds vehicle information fields (Year, Make, Model, Trim, Engine) to Discourse topics using ACES VCDB data.

## Installation Methods

### Method 1: Install from GitHub (Recommended)

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

Rebuild Discourse:
```bash
cd /var/discourse
sudo ./launcher rebuild app
```

### Method 2: Using Deployment Script

```bash
git clone https://github.com/kaushikmahida/discourse-vehicle-plugin.git
cd discourse-vehicle-plugin
./deploy_from_github.sh 10.0.131.255 main
```

### Method 3: Manual Installation

1. Download or clone the repository
2. Copy the entire plugin directory to `/var/discourse/shared/standalone/plugins/discourse-vehicle-plugin`
3. Copy your `vcdb.json` file to `data/vcdb.json`
4. Set permissions: `sudo chown -R root:root discourse-vehicle-plugin`
5. Rebuild Discourse: `cd /var/discourse && sudo ./launcher rebuild app`

## VCDB Data File

The plugin requires a `vcdb.json` file in the `data/` directory. This file is generated from ACES VCDB data using the included `scripts/process_vcdb.py` script.

**Note:** The `vcdb.json` file is NOT included in the repository due to its size (~2.1MB). You must provide your own.

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

### VCDB Not Loading
- Verify `data/vcdb.json` exists and is readable
- Check logs: `docker exec app tail -f /var/www/discourse/log/production.log | grep VehiclePlugin`
- Test loading: `docker exec app rails runner "puts DiscourseVehiclePlugin.vcdb_data['years'].length"`

### API Endpoints Not Working
- Check routes: `docker exec app rails routes | grep vehicle-api`
- Restart Unicorn: `docker exec app sv restart unicorn`

## Updating

To update the plugin:

```bash
cd /var/discourse/shared/standalone/plugins/discourse-vehicle-plugin
sudo git pull
cd /var/discourse
sudo ./launcher rebuild app
```

## Support

For issues or questions, please open an issue on GitHub:
https://github.com/kaushikmahida/discourse-vehicle-plugin
