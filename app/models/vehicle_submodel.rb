# frozen_string_literal: true

class VehicleSubmodel < ActiveRecord::Base
  self.table_name = 'vehicle_submodels'
  
  has_many :vehicle_ymm_submodels, dependent: :destroy
  
  validates :submodel_id, presence: true, uniqueness: true
  validates :name, presence: true
end
