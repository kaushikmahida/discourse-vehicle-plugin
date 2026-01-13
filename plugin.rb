# frozen_string_literal: true

# name: discourse-vehicle-plugin
# about: Vehicle fields for topics using VCDB data
# version: 5.0.0
# authors: RepairSolutions
# url: https://github.com/kaushikmahida/discourse-vehicle-plugin
# required_version: 2.7.0

enabled_site_setting :vehicle_fields_enabled

PLUGIN_NAME = "discourse-vehicle-plugin"

after_initialize do
  begin
    # Custom fields for topics
    %w[vehicle_year vehicle_make vehicle_model vehicle_trim vehicle_engine].each do |field|
      Topic.register_custom_field_type(field, :string)
      PostRevisor.track_topic_field(field.to_sym)
      add_preloaded_topic_list_custom_field(field)
    rescue => e
      Rails.logger.error("[VehiclePlugin] Error registering field #{field}: #{e.message}")
    end
    Topic.register_custom_field_type("is_general_question", :boolean)
    PostRevisor.track_topic_field(:is_general_question)
    add_preloaded_topic_list_custom_field("is_general_question")
  rescue => e
    Rails.logger.error("[VehiclePlugin] Error in after_initialize: #{e.message}")
    Rails.logger.error("[VehiclePlugin] Backtrace: #{e.backtrace.first(5).join(', ')}")
  end

  # Serializers
  %w[vehicle_year vehicle_make vehicle_model vehicle_trim vehicle_engine is_general_question].each do |field|
    add_to_serializer(:topic_view, field.to_sym) { object.topic.custom_fields[field] }
    add_to_serializer(:topic_list_item, field.to_sym) { object.custom_fields[field] }
  end

  # User fields for SSO
  %w[vehicle_year vehicle_make vehicle_model vehicle_trim vehicle_engine vehicle_vin].each do |field|
    User.register_custom_field_type(field, :string)
    add_to_serializer(:current_user, field.to_sym) { object.custom_fields[field] }
  end

  module ::DiscourseVehiclePlugin
    # Check if database tables exist (migration has run)
    def self.database_ready?
      ActiveRecord::Base.connection.table_exists?('vehicle_years')
    rescue
      false
    end

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseVehiclePlugin
    end

    class VehicleController < ::ApplicationController
      requires_plugin PLUGIN_NAME
      skip_before_action :check_xhr

      def years
        begin
          unless DiscourseVehiclePlugin.database_ready?
            return render json: { years: [], error: "Database not ready. Run migration and import data." }
          end
          
          years = VehicleYear.order(year: :desc).pluck(:year)
          render json: { years: years }
        rescue => e
          Rails.logger.error("[VehiclePlugin] Error in years endpoint: #{e.message}")
          render json: { years: [], error: "Internal error" }, status: 500
        end
      end

      def makes
        year = params[:year]
        return render json: { makes: [], error: "Year parameter is missing" } if year.blank?
        
        begin
          unless DiscourseVehiclePlugin.database_ready?
            return render json: { makes: [], error: "Database not ready. Run migration and import data." }
          end
          
          make_ids = VehicleYearMake.where(year: year.to_i).pluck(:make_id)
          makes = VehicleMake.where(make_id: make_ids)
            .order(:name)
            .map { |m| { id: m.make_id, name: m.name } }
          
          render json: { makes: makes }
        rescue => e
          Rails.logger.error("[VehiclePlugin] Error in makes endpoint: #{e.message}")
          Rails.logger.error("[VehiclePlugin] Backtrace: #{e.backtrace.first(3).join(', ')}")
          render json: { makes: [], error: "Internal error" }, status: 500
        end
      end

      def models
        year = params[:year]
        make_id = params[:make_id]
        return render json: { models: [], error: "Year or make_id parameter is missing" } if year.blank? || make_id.blank?
        
        begin
          unless DiscourseVehiclePlugin.database_ready?
            return render json: { models: [], error: "Database not ready. Run migration and import data." }
          end
          
          model_ids = VehicleYearMakeModel.where(year: year.to_i, make_id: make_id.to_s).pluck(:model_id)
          models = VehicleModel.where(model_id: model_ids)
            .order(:name)
            .map { |m| { id: m.model_id, name: m.name } }
          
          render json: { models: models }
        rescue => e
          Rails.logger.error("[VehiclePlugin] Error in models endpoint: #{e.message}")
          render json: { models: [], error: "Internal error" }, status: 500
        end
      end

      def trims
        year = params[:year]
        make_id = params[:make_id]
        model_id = params[:model_id]
        return render json: { trims: [], error: "Year, make_id, or model_id parameter is missing" } if year.blank? || make_id.blank? || model_id.blank?
        
        begin
          unless DiscourseVehiclePlugin.database_ready?
            return render json: { trims: [], error: "Database not ready. Run migration and import data." }
          end
          
          submodel_ids = VehicleYmmSubmodel.where(
            year: year.to_i,
            make_id: make_id.to_s,
            model_id: model_id.to_s
          ).pluck(:submodel_id)
          
          trims = VehicleSubmodel.where(submodel_id: submodel_ids)
            .order(:name)
            .map { |s| { id: s.submodel_id, name: s.name } }
          
          render json: { trims: trims }
        rescue => e
          Rails.logger.error("[VehiclePlugin] Error in trims endpoint: #{e.message}")
          render json: { trims: [], error: "Internal error" }, status: 500
        end
      end

      def engines
        render json: { engines: ["1.5L I4", "2.0L I4", "2.0L Turbo", "2.5L I4", "3.0L V6", "3.5L V6", 
                                  "5.0L V8", "5.7L V8", "6.2L V8", "Hybrid", "Electric", "Other"] }
      end

      def test
        render json: { 
          database_ready: DiscourseVehiclePlugin.database_ready?,
          years_count: VehicleYear.count,
          makes_count: VehicleMake.count,
          models_count: VehicleModel.count,
          submodels_count: VehicleSubmodel.count,
          sample_years: VehicleYear.order(year: :desc).limit(5).pluck(:year)
        }
      end
    end

    Engine.routes.draw do
      get "/years" => "vehicle#years"
      get "/makes" => "vehicle#makes"
      get "/models" => "vehicle#models"
      get "/trims" => "vehicle#trims"
      get "/engines" => "vehicle#engines"
      get "/test" => "vehicle#test"
    end
  end

  Discourse::Application.routes.append do
    mount ::DiscourseVehiclePlugin::Engine, at: "/vehicle-api", as: "vehicle_api"
  end

  on(:topic_created) do |topic, opts, user|
    begin
      topic.custom_fields["is_general_question"] = opts[:is_general_question] == true
      %w[vehicle_year vehicle_make vehicle_model vehicle_trim vehicle_engine].each do |field|
        topic.custom_fields[field] = opts[field.to_sym] if opts[field.to_sym].present?
      end
      topic.save_custom_fields
    rescue => e
      Rails.logger.error("[VehiclePlugin] Error in topic_created hook: #{e.message}")
    end
  end
end

register_asset "stylesheets/vehicle-fields.scss"
