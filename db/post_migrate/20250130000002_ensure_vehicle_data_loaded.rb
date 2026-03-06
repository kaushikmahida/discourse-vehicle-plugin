# frozen_string_literal: true

class EnsureVehicleDataLoaded < ActiveRecord::Migration[7.0]
  def up
    # No-op: v7.0.0 uses JSON file instead of database tables
  end

  def down
    # Nothing to do
  end
end
