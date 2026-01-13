# frozen_string_literal: true

namespace :vehicle_data do
  desc "Import VCDB JSON data into database"
  task import: :environment do
    puts "Starting VCDB import..."
    
    # Find VCDB file
    possible_paths = [
      File.join(Rails.root, "plugins", "discourse-vehicle-plugin", "data", "vcdb.json"),
      File.join(Rails.root, "plugins", "discourse-vehicle-plugin", "data", "vcdb_processed.json"),
      "/shared/plugins/discourse-vehicle-plugin/data/vcdb.json",
      "/var/discourse/shared/standalone/plugins/discourse-vehicle-plugin/data/vcdb.json",
      "/src/plugins/discourse-vehicle-plugin/data/vcdb.json",
      "/src/plugins/discourse-vehicle-plugin/data/vcdb_processed.json"
    ]
    
    filepath = possible_paths.find { |p| File.exist?(p) }
    
    unless filepath
      puts "ERROR: VCDB file not found. Tried: #{possible_paths.join(', ')}"
      exit 1
    end
    
    puts "Loading VCDB from: #{filepath}"
    
    begin
      vcdb_data = JSON.parse(File.read(filepath))
    rescue => e
      puts "ERROR: Failed to parse VCDB JSON: #{e.message}"
      exit 1
    end
    
    # Clear existing data
    puts "Clearing existing vehicle data..."
    ActiveRecord::Base.connection.execute("DELETE FROM vehicle_ymm_submodels")
    ActiveRecord::Base.connection.execute("DELETE FROM vehicle_year_make_models")
    ActiveRecord::Base.connection.execute("DELETE FROM vehicle_year_makes")
    ActiveRecord::Base.connection.execute("DELETE FROM vehicle_submodels")
    ActiveRecord::Base.connection.execute("DELETE FROM vehicle_models")
    ActiveRecord::Base.connection.execute("DELETE FROM vehicle_makes")
    ActiveRecord::Base.connection.execute("DELETE FROM vehicle_years")
    
    # Import years
    puts "Importing years..."
    years = vcdb_data["years"] || []
    db = ActiveRecord::Base.connection
    years.each do |year|
      db.execute("INSERT INTO vehicle_years (year, created_at, updated_at) VALUES (#{year.to_i}, NOW(), NOW()) ON CONFLICT (year) DO NOTHING")
    end
    year_count = db.execute("SELECT COUNT(*) FROM vehicle_years").first['count'].to_i
    puts "  Imported #{year_count} years"
    
    # Import makes
    puts "Importing makes..."
    makes = vcdb_data["makes"] || {}
    makes.each do |make_id, make_name|
      db.execute("INSERT INTO vehicle_makes (make_id, name, created_at, updated_at) VALUES ('#{make_id.to_s.gsub("'", "''")}', '#{make_name.to_s.gsub("'", "''")}', NOW(), NOW()) ON CONFLICT (make_id) DO UPDATE SET name = EXCLUDED.name")
    end
    make_count = db.execute("SELECT COUNT(*) FROM vehicle_makes").first['count'].to_i
    puts "  Imported #{make_count} makes"
    
    # Import models
    puts "Importing models..."
    models = vcdb_data["models"] || {}
    models.each do |model_id, model_name|
      db.execute("INSERT INTO vehicle_models (model_id, name, created_at, updated_at) VALUES ('#{model_id.to_s.gsub("'", "''")}', '#{model_name.to_s.gsub("'", "''")}', NOW(), NOW()) ON CONFLICT (model_id) DO UPDATE SET name = EXCLUDED.name")
    end
    model_count = db.execute("SELECT COUNT(*) FROM vehicle_models").first['count'].to_i
    puts "  Imported #{model_count} models"
    
    # Import submodels
    puts "Importing submodels..."
    submodels = vcdb_data["submodels"] || {}
    submodels.each do |submodel_id, submodel_name|
      db.execute("INSERT INTO vehicle_submodels (submodel_id, name, created_at, updated_at) VALUES ('#{submodel_id.to_s.gsub("'", "''")}', '#{submodel_name.to_s.gsub("'", "''")}', NOW(), NOW()) ON CONFLICT (submodel_id) DO UPDATE SET name = EXCLUDED.name")
    end
    submodel_count = db.execute("SELECT COUNT(*) FROM vehicle_submodels").first['count'].to_i
    puts "  Imported #{submodel_count} submodels"
    
    # Import year_makes relationships
    puts "Importing year-make relationships..."
    year_makes = vcdb_data["year_makes"] || {}
    year_makes.each do |year, make_ids|
      make_ids.each do |make_id|
        db.execute("INSERT INTO vehicle_year_makes (year, make_id, created_at, updated_at) VALUES (#{year.to_i}, '#{make_id.to_s.gsub("'", "''")}', NOW(), NOW()) ON CONFLICT (year, make_id) DO NOTHING")
      end
    end
    ymm_count = db.execute("SELECT COUNT(*) FROM vehicle_year_makes").first['count'].to_i
    puts "  Imported #{ymm_count} year-make relationships"
    
    # Import year_make_models relationships
    # Structure: {"2002_1" => [1, 2, 3, ...], "2003_1" => [...]}
    puts "Importing year-make-model relationships..."
    ymm = vcdb_data["year_make_models"] || {}
    ymm.each do |key, model_ids|
      # key is "year_makeId" format
      parts = key.split("_")
      next unless parts.length == 2
      year = parts[0].to_i
      make_id = parts[1].to_s
      
      model_ids.each do |model_id|
        db.execute("INSERT INTO vehicle_year_make_models (year, make_id, model_id, created_at, updated_at) VALUES (#{year}, '#{make_id.gsub("'", "''")}', '#{model_id.to_s.gsub("'", "''")}', NOW(), NOW()) ON CONFLICT (year, make_id, model_id) DO NOTHING")
      end
    end
    ymm_count = db.execute("SELECT COUNT(*) FROM vehicle_year_make_models").first['count'].to_i
    puts "  Imported #{ymm_count} year-make-model relationships"
    
    # Import ymm_submodels relationships
    # Structure: {"2002_1_2" => [1, 2, 3, ...], "2003_1_5" => [...]}
    puts "Importing year-make-model-submodel relationships..."
    ymms = vcdb_data["ymm_submodels"] || {}
    ymms.each do |key, submodel_ids|
      # key is "year_makeId_modelId" format
      parts = key.split("_")
      next unless parts.length == 3
      year = parts[0].to_i
      make_id = parts[1].to_s
      model_id = parts[2].to_s
      
      submodel_ids.each do |submodel_id|
        db.execute("INSERT INTO vehicle_ymm_submodels (year, make_id, model_id, submodel_id, created_at, updated_at) VALUES (#{year}, '#{make_id.gsub("'", "''")}', '#{model_id.gsub("'", "''")}', '#{submodel_id.to_s.gsub("'", "''")}', NOW(), NOW()) ON CONFLICT (year, make_id, model_id, submodel_id) DO NOTHING")
      end
    end
    ymms_count = db.execute("SELECT COUNT(*) FROM vehicle_ymm_submodels").first['count'].to_i
    puts "  Imported #{ymms_count} year-make-model-submodel relationships"
    
    puts ""
    puts "✅ VCDB import completed successfully!"
    puts "   Years: #{year_count}"
    puts "   Makes: #{make_count}"
    puts "   Models: #{model_count}"
    puts "   Submodels: #{submodel_count}"
  end
  
  desc "Clear all vehicle data from database"
  task clear: :environment do
    puts "Clearing all vehicle data..."
    db = ActiveRecord::Base.connection
    db.execute("DELETE FROM vehicle_ymm_submodels")
    db.execute("DELETE FROM vehicle_year_make_models")
    db.execute("DELETE FROM vehicle_year_makes")
    db.execute("DELETE FROM vehicle_submodels")
    db.execute("DELETE FROM vehicle_models")
    db.execute("DELETE FROM vehicle_makes")
    db.execute("DELETE FROM vehicle_years")
    puts "✅ All vehicle data cleared"
  end
end
