# Discourse Vehicle Plugin

A Discourse plugin that adds vehicle information fields (Year, Make, Model, Engine) to topics, with cascading dropdowns, Redis caching, and automatic updates from NHTSA.

## Features

- **Cascading Dropdowns**: Year -> Make -> Model -> Engine selection
- **General Question Toggle**: Users can skip vehicle info for non-vehicle questions
- **Redis Caching**: Vehicle data stored in Discourse's Redis for fast access
- **NHTSA Integration**: Automatic monthly updates from the National Highway Traffic Safety Administration API
- **SSO Ready**: Pre-populate vehicle fields from user SSO claims
- **Admin Controls**: Manual refresh and cache management

## Installation

### Method 1: Git Clone (Recommended)

Add to your `app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/kaushikmahida/discourse-vehicle-plugin.git
```

Then rebuild:

```bash
cd /var/discourse
./launcher rebuild app
```

### Method 2: Manual Copy

Copy the plugin folder to `/var/discourse/plugins/` and rebuild.

## Configuration

### Admin Settings

Navigate to **Admin > Settings > Plugins** and search for "vehicle":

| Setting | Description | Default |
|---------|-------------|---------|
| `vehicle_fields_enabled` | Enable vehicle fields | true |
| `vehicle_fields_required_categories` | Categories where vehicle info is required | (empty) |
| `vehicle_fields_auto_update_enabled` | Enable monthly NHTSA updates | true |
| `vehicle_fields_show_on_topic_list` | Show vehicle badge on topics | true |

### SSO Integration

When configuring SSO, you can pass vehicle data as custom fields:

| Field | Description |
|-------|-------------|
| `vehicle_year` | Vehicle year (e.g., "2020") |
| `vehicle_make` | Vehicle make (e.g., "Toyota") |
| `vehicle_model` | Vehicle model (e.g., "Camry") |
| `vehicle_engine` | Engine type (e.g., "2.5L") |
| `vehicle_vin` | VIN (for future VIN decode) |

Example SSO payload:
```
custom.vehicle_year=2020
custom.vehicle_make=Toyota
custom.vehicle_model=Camry
custom.vehicle_engine=2.5L
```

## API Endpoints

### Public Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /vehicle-api/makes` | Get all vehicle makes |
| `GET /vehicle-api/models?make=Toyota&year=2020` | Get models for make/year |
| `GET /vehicle-api/engines` | Get engine types |
| `GET /vehicle-api/status` | Get cache status |

### Admin Endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /admin/plugins/vehicle/refresh` | Trigger data refresh |
| `POST /admin/plugins/vehicle/clear-cache` | Clear Redis cache |
| `GET /admin/plugins/vehicle/status` | Get detailed status |

## Redis Keys

The plugin uses the following Redis keys:

| Key | Description | TTL |
|-----|-------------|-----|
| `vehicle_plugin:makes` | All vehicle makes | 30 days |
| `vehicle_plugin:models:{make}:{year}` | Models for make/year | 30 days |
| `vehicle_plugin:last_update` | Last refresh timestamp | Never |

## NHTSA Data Source

Vehicle data is fetched from the NHTSA Vehicle Product Information Catalog (vPIC):
- API: https://vpic.nhtsa.dot.gov/api/
- Free, no API key required
- Updated monthly via scheduled job

## Development

### Local Testing

```bash
# Clone Discourse
git clone https://github.com/discourse/discourse.git
cd discourse

# Link plugin
ln -s /path/to/discourse-vehicle-plugin plugins/

# Start development environment
./d/boot_dev --init
```

### Manual Data Refresh

From Rails console:
```ruby
DiscourseVehiclePlugin::VehicleDataService.refresh_all_data
```

Check cache status:
```ruby
DiscourseVehiclePlugin::VehicleDataService.last_update_time
DiscourseVehiclePlugin::VehicleDataService.get_makes.count
```

Clear cache:
```ruby
DiscourseVehiclePlugin::VehicleDataService.clear_cache
```

## Changelog

### v3.0.0
- Added Redis caching for vehicle data
- Added NHTSA API integration
- Added monthly auto-update job
- Added admin controls for cache management

### v2.0.0
- Added cascading dropdowns
- Added general question toggle
- Added SSO integration

### v1.0.0
- Initial release with basic vehicle fields

## License

MIT License - RepairSolutions
