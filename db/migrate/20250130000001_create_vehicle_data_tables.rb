# frozen_string_literal: true

class CreateVehicleDataTables < ActiveRecord::Migration[7.0]
  def up
    create_table :vehicle_makes do |t|
      t.string :make_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.timestamps
    end
    add_index :vehicle_makes, :name

    create_table :vehicle_models do |t|
      t.string :model_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.timestamps
    end
    add_index :vehicle_models, :name

    create_table :vehicle_submodels do |t|
      t.string :submodel_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.timestamps
    end
    add_index :vehicle_submodels, :name

    # Junction tables for relationships
    create_table :vehicle_year_makes do |t|
      t.integer :year, null: false
      t.string :make_id, null: false
      t.timestamps
    end
    add_index :vehicle_year_makes, [:year, :make_id], unique: true
    add_index :vehicle_year_makes, :year

    create_table :vehicle_year_make_models do |t|
      t.integer :year, null: false
      t.string :make_id, null: false
      t.string :model_id, null: false
      t.timestamps
    end
    add_index :vehicle_year_make_models, [:year, :make_id, :model_id], unique: true, name: 'idx_ymm'
    add_index :vehicle_year_make_models, [:year, :make_id]

    create_table :vehicle_ymm_submodels do |t|
      t.integer :year, null: false
      t.string :make_id, null: false
      t.string :model_id, null: false
      t.string :submodel_id, null: false
      t.timestamps
    end
    add_index :vehicle_ymm_submodels, [:year, :make_id, :model_id, :submodel_id], unique: true, name: 'idx_ymms'
    add_index :vehicle_ymm_submodels, [:year, :make_id, :model_id]

    # Store years separately for quick lookup
    create_table :vehicle_years do |t|
      t.integer :year, null: false, index: { unique: true }
      t.timestamps
    end
  end

  def down
    drop_table :vehicle_ymm_submodels
    drop_table :vehicle_year_make_models
    drop_table :vehicle_year_makes
    drop_table :vehicle_submodels
    drop_table :vehicle_models
    drop_table :vehicle_makes
    drop_table :vehicle_years
  end
end
