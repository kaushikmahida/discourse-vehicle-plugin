# frozen_string_literal: true

class VehicleMake < ActiveRecord::Base
  self.table_name = 'vehicle_makes'
  
  has_many :vehicle_year_makes, dependent: :destroy
  has_many :vehicle_year_make_models, dependent: :destroy
  
  validates :make_id, presence: true, uniqueness: true
  validates :name, presence: true
end
