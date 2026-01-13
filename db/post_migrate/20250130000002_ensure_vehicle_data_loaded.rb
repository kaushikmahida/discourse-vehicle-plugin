# frozen_string_literal: true

class EnsureVehicleDataLoaded < ActiveRecord::Migration[7.0]
  def up
    # Only run if tables exist but are empty
    return unless table_exists?(:vehicle_years)
    
    year_count = DB.query_single("SELECT COUNT(*) FROM vehicle_years").to_i
    
    if year_count == 0
      puts "[VehiclePlugin] Vehicle data tables are empty. Run 'rake vehicle_data:import' to load data."
      Rails.logger.warn("[VehiclePlugin] Vehicle data tables exist but are empty. Import data with: bundle exec rake vehicle_data:import")
    else
      Rails.logger.info("[VehiclePlugin] Vehicle data already loaded: #{year_count} years")
    end
  end

  def down
    # Nothing to do - this is just a check
  end
end
