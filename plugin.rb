# frozen_string_literal: true

# name: discourse-vehicle-plugin
# about: Adds vehicle information fields (Year, Make, Model, Trim) using VCDB/ACES data
# version: 4.0.0
# authors: RepairSolutions
# url: https://github.com/kaushikmahida/discourse-vehicle-plugin
# required_version: 2.7.0

enabled_site_setting :vehicle_fields_enabled

PLUGIN_NAME = "discourse-vehicle-plugin"

after_initialize do
  # Register custom fields for topics
  Topic.register_custom_field_type("vehicle_year", :string)
  Topic.register_custom_field_type("vehicle_make", :string)
  Topic.register_custom_field_type("vehicle_model", :string)
  Topic.register_custom_field_type("vehicle_trim", :string)
  Topic.register_custom_field_type("vehicle_engine", :string)
  Topic.register_custom_field_type("is_general_question", :boolean)

  # Register custom fields for users (for SSO vehicle data)
  User.register_custom_field_type("vehicle_year", :string)
  User.register_custom_field_type("vehicle_make", :string)
  User.register_custom_field_type("vehicle_model", :string)
  User.register_custom_field_type("vehicle_trim", :string)
  User.register_custom_field_type("vehicle_engine", :string)
  User.register_custom_field_type("vehicle_vin", :string)

  # Allow custom fields to be set via API
  PostRevisor.track_topic_field(:vehicle_year)
  PostRevisor.track_topic_field(:vehicle_make)
  PostRevisor.track_topic_field(:vehicle_model)
  PostRevisor.track_topic_field(:vehicle_trim)
  PostRevisor.track_topic_field(:vehicle_engine)
  PostRevisor.track_topic_field(:is_general_question)

  # Preload custom fields
  add_preloaded_topic_list_custom_field("vehicle_year")
  add_preloaded_topic_list_custom_field("vehicle_make")
  add_preloaded_topic_list_custom_field("vehicle_model")
  add_preloaded_topic_list_custom_field("vehicle_trim")
  add_preloaded_topic_list_custom_field("vehicle_engine")
  add_preloaded_topic_list_custom_field("is_general_question")

  # Add to topic serializer
  add_to_serializer(:topic_view, :vehicle_year) { object.topic.custom_fields["vehicle_year"] }
  add_to_serializer(:topic_view, :vehicle_make) { object.topic.custom_fields["vehicle_make"] }
  add_to_serializer(:topic_view, :vehicle_model) { object.topic.custom_fields["vehicle_model"] }
  add_to_serializer(:topic_view, :vehicle_trim) { object.topic.custom_fields["vehicle_trim"] }
  add_to_serializer(:topic_view, :vehicle_engine) { object.topic.custom_fields["vehicle_engine"] }
  add_to_serializer(:topic_view, :is_general_question) { object.topic.custom_fields["is_general_question"] }

  # Add to topic list item serializer
  add_to_serializer(:topic_list_item, :vehicle_year) { object.custom_fields["vehicle_year"] }
  add_to_serializer(:topic_list_item, :vehicle_make) { object.custom_fields["vehicle_make"] }
  add_to_serializer(:topic_list_item, :vehicle_model) { object.custom_fields["vehicle_model"] }
  add_to_serializer(:topic_list_item, :vehicle_trim) { object.custom_fields["vehicle_trim"] }
  add_to_serializer(:topic_list_item, :vehicle_engine) { object.custom_fields["vehicle_engine"] }
  add_to_serializer(:topic_list_item, :is_general_question) { object.custom_fields["is_general_question"] }

  # Add user vehicle fields to current user serializer (for SSO data)
  add_to_serializer(:current_user, :vehicle_year) { object.custom_fields["vehicle_year"] }
  add_to_serializer(:current_user, :vehicle_make) { object.custom_fields["vehicle_make"] }
  add_to_serializer(:current_user, :vehicle_model) { object.custom_fields["vehicle_model"] }
  add_to_serializer(:current_user, :vehicle_trim) { object.custom_fields["vehicle_trim"] }
  add_to_serializer(:current_user, :vehicle_engine) { object.custom_fields["vehicle_engine"] }

  module ::DiscourseVehiclePlugin
    VCDB_REDIS_PREFIX = "vcdb:"
    
    class VcdbService
      class << self
        def redis
          Discourse.redis
        end

        def vcdb_loaded?
          redis.exists?("#{VCDB_REDIS_PREFIX}loaded")
        end

        def get_years
          cached = redis.get("#{VCDB_REDIS_PREFIX}years")
          return JSON.parse(cached) if cached
          []
        end

        def get_makes(year)
          cached = redis.get("#{VCDB_REDIS_PREFIX}year_makes:#{year}")
          return [] unless cached
          
          make_ids = JSON.parse(cached)
          makes_map = get_makes_map
          make_ids.map { |id| { id: id, name: makes_map[id.to_s] } }.compact.sort_by { |m| m[:name] }
        end

        def get_models(year, make_id)
          cached = redis.get("#{VCDB_REDIS_PREFIX}ymm:#{year}_#{make_id}")
          return [] unless cached
          
          model_ids = JSON.parse(cached)
          models_map = get_models_map
          model_ids.map { |id| { id: id, name: models_map[id.to_s] } }.compact.sort_by { |m| m[:name] }
        end

        def get_trims(year, make_id, model_id)
          cached = redis.get("#{VCDB_REDIS_PREFIX}ymms:#{year}_#{make_id}_#{model_id}")
          return [] unless cached
          
          submodel_ids = JSON.parse(cached)
          submodels_map = get_submodels_map
          submodel_ids.map { |id| { id: id, name: submodels_map[id.to_s] } }.compact.sort_by { |m| m[:name] }
        end

        def get_makes_map
          cached = redis.get("#{VCDB_REDIS_PREFIX}makes")
          cached ? JSON.parse(cached) : {}
        end

        def get_models_map
          cached = redis.get("#{VCDB_REDIS_PREFIX}models")
          cached ? JSON.parse(cached) : {}
        end

        def get_submodels_map
          cached = redis.get("#{VCDB_REDIS_PREFIX}submodels")
          cached ? JSON.parse(cached) : {}
        end

        def load_vcdb_from_file(filepath)
          Rails.logger.info("[VehiclePlugin] Loading VCDB from #{filepath}")
          
          unless File.exist?(filepath)
            Rails.logger.error("[VehiclePlugin] VCDB file not found: #{filepath}")
            return { success: false, error: "File not found" }
          end

          data = JSON.parse(File.read(filepath))
          
          # Store years
          redis.set("#{VCDB_REDIS_PREFIX}years", data["years"].to_json)
          
          # Store lookup maps
          redis.set("#{VCDB_REDIS_PREFIX}makes", data["makes"].to_json)
          redis.set("#{VCDB_REDIS_PREFIX}models", data["models"].to_json)
          redis.set("#{VCDB_REDIS_PREFIX}submodels", data["submodels"].to_json)
          
          # Store year -> makes mapping
          data["year_makes"].each do |year, make_ids|
            redis.set("#{VCDB_REDIS_PREFIX}year_makes:#{year}", make_ids.to_json)
          end
          
          # Store year_make -> models mapping
          data["year_make_models"].each do |key, model_ids|
            redis.set("#{VCDB_REDIS_PREFIX}ymm:#{key}", model_ids.to_json)
          end
          
          # Store year_make_model -> submodels/trims mapping
          data["ymm_submodels"].each do |key, submodel_ids|
            redis.set("#{VCDB_REDIS_PREFIX}ymms:#{key}", submodel_ids.to_json)
          end
          
          redis.set("#{VCDB_REDIS_PREFIX}loaded", "true")
          
          Rails.logger.info("[VehiclePlugin] VCDB loaded successfully")
          { success: true, years: data["years"].length, makes: data["makes"].length }
        end

        def clear_vcdb
          keys = redis.keys("#{VCDB_REDIS_PREFIX}*")
          redis.del(*keys) if keys.any?
          { cleared: keys.length }
        end
      end
    end

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseVehiclePlugin
    end

    class VehicleController < ::ApplicationController
      requires_plugin PLUGIN_NAME
      skip_before_action :check_xhr, only: [:years, :makes, :models, :trims, :engines]

      def years
        years = VcdbService.get_years
        render json: { years: years }
      end

      def makes
        year = params[:year]
        return render json: { makes: [], error: "Year required" }, status: 400 if year.blank?
        
        makes = VcdbService.get_makes(year)
        render json: { makes: makes }
      end

      def models
        year = params[:year]
        make_id = params[:make_id]
        return render json: { models: [], error: "Year and make_id required" }, status: 400 if year.blank? || make_id.blank?
        
        models = VcdbService.get_models(year, make_id)
        render json: { models: models }
      end

      def trims
        year = params[:year]
        make_id = params[:make_id]
        model_id = params[:model_id]
        return render json: { trims: [], error: "Year, make_id, and model_id required" }, status: 400 if year.blank? || make_id.blank? || model_id.blank?
        
        trims = VcdbService.get_trims(year, make_id, model_id)
        render json: { trims: trims }
      end

      def engines
        engines = [
          "1.5L I4", "2.0L I4", "2.0L Turbo I4", "2.4L I4", "2.5L I4",
          "3.0L V6", "3.5L V6", "3.6L V6", "3.7L V6",
          "4.0L V6", "5.0L V8", "5.3L V8", "5.7L V8",
          "6.0L V8", "6.2L V8", "6.4L V8", "6.7L Diesel",
          "Hybrid", "Plug-in Hybrid", "Electric", "Other"
        ]
        render json: { engines: engines }
      end

      def status
        render json: { 
          vcdb_loaded: VcdbService.vcdb_loaded?,
          years_count: VcdbService.get_years.length
        }
      end
    end

    class AdminVehicleController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      def load_vcdb
        filepath = params[:filepath] || File.join(Rails.root, "plugins", PLUGIN_NAME, "data", "vcdb.json")
        result = VcdbService.load_vcdb_from_file(filepath)
        render json: result
      end

      def clear_vcdb
        result = VcdbService.clear_vcdb
        render json: { success: true, cleared: result[:cleared] }
      end

      def status
        render json: {
          vcdb_loaded: VcdbService.vcdb_loaded?,
          years_count: VcdbService.get_years.length,
          makes_count: VcdbService.get_makes_map.length
        }
      end
    end

    Engine.routes.draw do
      get "/years" => "vehicle#years"
      get "/makes" => "vehicle#makes"
      get "/models" => "vehicle#models"
      get "/trims" => "vehicle#trims"
      get "/engines" => "vehicle#engines"
      get "/status" => "vehicle#status"
    end
  end

  Discourse::Application.routes.append do
    mount ::DiscourseVehiclePlugin::Engine, at: "/vehicle-api"
    
    namespace :admin, constraints: StaffConstraint.new do
      post "/plugins/vehicle/load-vcdb" => "discourse_vehicle_plugin/admin_vehicle#load_vcdb"
      post "/plugins/vehicle/clear-vcdb" => "discourse_vehicle_plugin/admin_vehicle#clear_vcdb"
      get "/plugins/vehicle/status" => "discourse_vehicle_plugin/admin_vehicle#status"
    end
  end

  # Hook into topic creation
  on(:topic_created) do |topic, opts, user|
    if opts[:is_general_question].present? && opts[:is_general_question] == true
      topic.custom_fields["is_general_question"] = true
    else
      topic.custom_fields["is_general_question"] = false
      topic.custom_fields["vehicle_year"] = opts[:vehicle_year] if opts[:vehicle_year].present?
      topic.custom_fields["vehicle_make"] = opts[:vehicle_make] if opts[:vehicle_make].present?
      topic.custom_fields["vehicle_model"] = opts[:vehicle_model] if opts[:vehicle_model].present?
      topic.custom_fields["vehicle_trim"] = opts[:vehicle_trim] if opts[:vehicle_trim].present?
      topic.custom_fields["vehicle_engine"] = opts[:vehicle_engine] if opts[:vehicle_engine].present?
    end
    topic.save_custom_fields if topic.custom_fields.present?
  end
end

# Register assets
register_asset "stylesheets/vehicle-fields.scss"
