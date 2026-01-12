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
    @@vcdb_data = nil
    
    def self.vcdb_data
      return @@vcdb_data if @@vcdb_data
      
      begin
        # Try multiple possible paths (production and dev)
        possible_paths = [
          File.join(Rails.root, "plugins", PLUGIN_NAME, "data", "vcdb.json"),
          File.join(Rails.root, "plugins", PLUGIN_NAME, "data", "vcdb_processed.json"),
          "/shared/plugins/#{PLUGIN_NAME}/data/vcdb.json",
          "/var/discourse/shared/standalone/plugins/#{PLUGIN_NAME}/data/vcdb.json",
          "/src/plugins/#{PLUGIN_NAME}/data/vcdb.json",
          "/src/plugins/#{PLUGIN_NAME}/data/vcdb_processed.json"
        ]
        
        filepath = possible_paths.find { |p| File.exist?(p) rescue false }
        
        if filepath
          Rails.logger.info("[VehiclePlugin] Loading VCDB from #{filepath}")
          begin
            @@vcdb_data = JSON.parse(File.read(filepath))
            Rails.logger.info("[VehiclePlugin] VCDB loaded: #{@@vcdb_data['years']&.length} years, #{@@vcdb_data['makes']&.length} makes")
          rescue => e
            Rails.logger.error("[VehiclePlugin] Failed to parse VCDB: #{e.message}")
            @@vcdb_data = empty_vcdb
          end
        else
          Rails.logger.warn("[VehiclePlugin] VCDB file not found. Plugin will work with empty VCDB data")
          @@vcdb_data = empty_vcdb
        end
      rescue => e
        Rails.logger.error("[VehiclePlugin] Error in vcdb_data: #{e.message}")
        @@vcdb_data = empty_vcdb
      end
      
      @@vcdb_data
    end
    
    def self.empty_vcdb
      { "years" => [], "makes" => {}, "models" => {}, "submodels" => {}, 
        "year_makes" => {}, "year_make_models" => {}, "ymm_submodels" => {} }
    end

    def self.reload_vcdb!
      @@vcdb_data = nil
      vcdb_data
    end

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseVehiclePlugin
    end

    class VehicleController < ::ApplicationController
      requires_plugin PLUGIN_NAME
      skip_before_action :check_xhr

      def years
        data = DiscourseVehiclePlugin.vcdb_data
        render json: { years: data["years"] || [] }
      end

      def makes
        year = params[:year]
        return render json: { makes: [] } if year.blank?
        
        begin
          data = DiscourseVehiclePlugin.vcdb_data
          return render json: { makes: [], error: "VCDB not loaded" } if data.empty? || !data.is_a?(Hash)
          
          make_ids = data.dig("year_makes", year.to_s) || []
          makes_map = data["makes"] || {}
          
          return render json: { makes: [] } unless make_ids.is_a?(Array)
          
          makes = make_ids.map { |id| 
            make_name = makes_map[id.to_s] || makes_map[id.to_i.to_s]
            { id: id.to_s, name: make_name } if make_name.present?
          }.compact.sort_by { |m| m[:name] }
          
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
        return render json: { models: [] } if year.blank? || make_id.blank?
        
        begin
          data = DiscourseVehiclePlugin.vcdb_data
          return render json: { models: [], error: "VCDB not loaded" } if data.empty? || !data.is_a?(Hash)
          
          key = "#{year}_#{make_id}"
          model_ids = data.dig("year_make_models", key) || []
          models_map = data["models"] || {}
          
          return render json: { models: [] } unless model_ids.is_a?(Array)
          
          models = model_ids.map { |id| 
            model_name = models_map[id.to_s] || models_map[id.to_i.to_s]
            { id: id.to_s, name: model_name } if model_name.present?
          }.compact.sort_by { |m| m[:name] }
          
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
        return render json: { trims: [] } if year.blank? || make_id.blank? || model_id.blank?
        
        begin
          data = DiscourseVehiclePlugin.vcdb_data
          return render json: { trims: [], error: "VCDB not loaded" } if data.empty? || !data.is_a?(Hash)
          
          key = "#{year}_#{make_id}_#{model_id}"
          trim_ids = data.dig("ymm_submodels", key) || []
          trims_map = data["submodels"] || {}
          
          return render json: { trims: [] } unless trim_ids.is_a?(Array)
          
          trims = trim_ids.map { |id| 
            trim_name = trims_map[id.to_s] || trims_map[id.to_i.to_s]
            { id: id.to_s, name: trim_name } if trim_name.present?
          }.compact.sort_by { |t| t[:name] }
          
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
        data = DiscourseVehiclePlugin.vcdb_data
        render json: { 
          loaded: !data.empty?,
          years_count: data["years"]&.length || 0,
          makes_count: data["makes"]&.length || 0,
          sample_years: data["years"]&.first(5) || [],
          file_paths: [
            File.join(Rails.root, "plugins", PLUGIN_NAME, "data", "vcdb.json"),
            "/src/plugins/#{PLUGIN_NAME}/data/vcdb.json"
          ].map { |p| { path: p, exists: File.exist?(p) } }
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
    mount ::DiscourseVehiclePlugin::Engine, at: "/vehicle-api"
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
