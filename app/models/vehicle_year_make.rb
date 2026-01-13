# frozen_string_literal: true

class VehicleYearMake < ActiveRecord::Base
  self.table_name = 'vehicle_year_makes'
  
  belongs_to :make, class_name: 'VehicleMake', foreign_key: 'make_id', primary_key: 'make_id'
  
  validates :year, presence: true
  validates :make_id, presence: true
end
