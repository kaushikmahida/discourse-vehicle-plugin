# frozen_string_literal: true

class VehicleModel < ActiveRecord::Base
  self.table_name = 'vehicle_models'
  
  has_many :vehicle_year_make_models, dependent: :destroy
  has_many :vehicle_ymm_submodels, dependent: :destroy
  
  validates :model_id, presence: true, uniqueness: true
  validates :name, presence: true
end
