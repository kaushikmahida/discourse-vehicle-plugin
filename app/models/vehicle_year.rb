# frozen_string_literal: true

class VehicleYear < ActiveRecord::Base
  self.table_name = 'vehicle_years'
  
  validates :year, presence: true, uniqueness: true
end
