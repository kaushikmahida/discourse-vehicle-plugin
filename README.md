# Discourse Vehicle Plugin

A Discourse plugin that adds vehicle information fields (Year, Make, Model, Trim, Engine) to topics using ACES VCDB data.

## Features

- **Vehicle Fields**: Year, Make, Model, Trim, and Engine dropdowns in topic composer
- **ACES VCDB Integration**: Uses official ACES Vehicle Configuration Database
- **Cascading Dropdowns**: Year → Make → Model → Trim selection
- **SSO Integration**: Pre-populates fields from user's vehicle data
- **API Endpoints**: RESTful API for fetching vehicle data
- **Persistent Storage**: Vehicle data stored with topics

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

### Quick Install from GitHub

```bash
cd /var/discourse/shared/standalone/plugins
sudo git clone https://github.com/kaushikmahida/discourse-vehicle-plugin.git discourse-vehicle-plugin
cd discourse-vehicle-plugin
sudo chown -R root:root .
```

Then copy your VCDB data file and rebuild Discourse.

## Requirements

- Discourse 2.7.0 or higher
- ACES VCDB data file (processed JSON format)
- Ruby 3.3+

## VCDB Data

The plugin requires a processed VCDB JSON file. Use the included `scripts/process_vcdb.py` to convert raw ACES VCDB files into the required format.

**Note:** The `vcdb.json` file is NOT included in the repository. You must provide your own.

## Testing

Run the local test script:

```bash
./test_local.sh
```

This verifies:
- Plugin loads correctly
- VCDB data loads
- API endpoints work
- Plugin is recognized by Discourse

## API Endpoints

- `GET /vehicle-api/years` - Get all available years
- `GET /vehicle-api/makes?year=2024` - Get makes for a year
- `GET /vehicle-api/models?year=2024&make_id=123` - Get models for year/make
- `GET /vehicle-api/trims?year=2024&make_id=123&model_id=456` - Get trims for year/make/model
- `GET /vehicle-api/engines` - Get available engines
- `GET /vehicle-api/test` - Test VCDB loading status

## Deployment

### From GitHub (Recommended)

```bash
./deploy_from_github.sh [server_ip] [branch]
```

### Manual Deployment

```bash
./deploy.sh [server_ip]
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

## Configuration

The plugin is enabled by default. Configure via Discourse Admin:

1. Go to **Admin > Settings > Plugins**
2. Find "Vehicle Fields"
3. Adjust settings as needed

## File Structure

```
discourse-vehicle-plugin/
├── plugin.rb                          # Main plugin file
├── assets/
│   ├── javascripts/                   # Frontend JavaScript
│   └── stylesheets/                   # CSS styles
├── config/
│   ├── locales/                       # Translations
│   └── settings.yml                    # Plugin settings
├── data/
│   └── vcdb.json                      # VCDB data (not in repo)
├── scripts/
│   └── process_vcdb.py                # VCDB processing script
├── deploy_from_github.sh              # GitHub deployment script
├── test_local.sh                      # Local testing script
└── README.md                          # This file
```

## Development

1. Clone the repository
2. Copy your `vcdb.json` to `data/`
3. Link plugin to Discourse dev environment
4. Run `./test_local.sh` to verify

## License

Copyright (c) 2025 RepairSolutions

## Support

For issues or questions, please open an issue on GitHub:
https://github.com/kaushikmahida/discourse-vehicle-plugin/issues
