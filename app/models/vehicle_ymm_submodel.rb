# frozen_string_literal: true

class VehicleYmmSubmodel < ActiveRecord::Base
  self.table_name = 'vehicle_ymm_submodels'
  
  belongs_to :make, class_name: 'VehicleMake', foreign_key: 'make_id', primary_key: 'make_id'
  belongs_to :model, class_name: 'VehicleModel', foreign_key: 'model_id', primary_key: 'model_id'
  belongs_to :submodel, class_name: 'VehicleSubmodel', foreign_key: 'submodel_id', primary_key: 'submodel_id'
  
  validates :year, presence: true
  validates :make_id, presence: true
  validates :model_id, presence: true
  validates :submodel_id, presence: true
end
