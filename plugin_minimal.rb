# frozen_string_literal: true

# name: discourse-vehicle-plugin
# about: Vehicle fields for topics - MINIMAL VERSION
# version: 6.0.0
# authors: RepairSolutions
# url: https://github.com/kaushikmahida/discourse-vehicle-plugin
# required_version: 2.7.0

enabled_site_setting :vehicle_fields_enabled

PLUGIN_NAME = "discourse-vehicle-plugin"

after_initialize do
  # Only register custom fields - nothing else
  begin
    %w[vehicle_year vehicle_make vehicle_model vehicle_trim vehicle_engine].each do |field|
      Topic.register_custom_field_type(field, :string)
      PostRevisor.track_topic_field(field.to_sym)
    end
    Topic.register_custom_field_type("is_general_question", :boolean)
    PostRevisor.track_topic_field(:is_general_question)
  rescue => e
    Rails.logger.error("[VehiclePlugin] Error in after_initialize: #{e.message}")
  end

  module ::DiscourseVehiclePlugin
    @@vcdb_cache = nil
    
    def self.get_vcdb_data
      return @@vcdb_cache if @@vcdb_cache
      
      begin
        possible_paths = [
          File.join(Rails.root, "plugins", PLUGIN_NAME, "data", "vcdb.json"),
          "/shared/plugins/#{PLUGIN_NAME}/data/vcdb.json",
          "/var/discourse/shared/standalone/plugins/#{PLUGIN_NAME}/data/vcdb.json"
        ]
        
        filepath = possible_paths.find { |p| File.exist?(p) rescue false }
        return {} unless filepath
        
        @@vcdb_cache = JSON.parse(File.read(filepath))
      rescue => e
        Rails.logger.error("[VehiclePlugin] Error loading VCDB: #{e.message}")
        @@vcdb_cache = {}
      end
      
      @@vcdb_cache
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
          data = get_vcdb_data
          years = data["years"] || []
          render json: { years: years }
        rescue => e
          Rails.logger.error("[VehiclePlugin] Error in years: #{e.message}")
          render json: { years: [] }
        end
      end

      def makes
        begin
          year = params[:year].to_s
          return render json: { makes: [] } if year.blank?
          
          data = get_vcdb_data
          make_ids = data.dig("year_makes", year) || []
          makes_map = data["makes"] || {}
          
          makes = make_ids.map { |id|
            name = makes_map[id.to_s] || makes_map[id.to_i.to_s]
            { id: id.to_s, name: name } if name
          }.compact.sort_by { |m| m[:name] }
          
          render json: { makes: makes }
        rescue => e
          Rails.logger.error("[VehiclePlugin] Error in makes: #{e.message}")
          render json: { makes: [] }
        end
      end

      def models
        begin
          year = params[:year].to_s
          make_id = params[:make_id].to_s
          return render json: { models: [] } if year.blank? || make_id.blank?
          
          data = get_vcdb_data
          key = "#{year}_#{make_id}"
          model_ids = data.dig("year_make_models", key) || []
          models_map = data["models"] || {}
          
          models = model_ids.map { |id|
            name = models_map[id.to_s] || models_map[id.to_i.to_s]
            { id: id.to_s, name: name } if name
          }.compact.sort_by { |m| m[:name] }
          
          render json: { models: models }
        rescue => e
          Rails.logger.error("[VehiclePlugin] Error in models: #{e.message}")
          render json: { models: [] }
        end
      end

      def trims
        begin
          year = params[:year].to_s
          make_id = params[:make_id].to_s
          model_id = params[:model_id].to_s
          return render json: { trims: [] } if year.blank? || make_id.blank? || model_id.blank?
          
          data = get_vcdb_data
          key = "#{year}_#{make_id}_#{model_id}"
          trim_ids = data.dig("ymm_submodels", key) || []
          trims_map = data["submodels"] || {}
          
          trims = trim_ids.map { |id|
            name = trims_map[id.to_s] || trims_map[id.to_i.to_s]
            { id: id.to_s, name: name } if name
          }.compact.sort_by { |t| t[:name] }
          
          render json: { trims: trims }
        rescue => e
          Rails.logger.error("[VehiclePlugin] Error in trims: #{e.message}")
          render json: { trims: [] }
        end
      end

      def engines
        render json: { engines: ["1.5L I4", "2.0L I4", "2.0L Turbo", "2.5L I4", "3.0L V6", "3.5L V6", 
                                  "5.0L V8", "5.7L V8", "6.2L V8", "Hybrid", "Electric", "Other"] }
      end
    end

    Engine.routes.draw do
      get "/years" => "vehicle#years"
      get "/makes" => "vehicle#makes"
      get "/models" => "vehicle#models"
      get "/trims" => "vehicle#trims"
      get "/engines" => "vehicle#engines"
    end
  end

  Discourse::Application.routes.append do
    mount ::DiscourseVehiclePlugin::Engine, at: "/vehicle-api", as: "vehicle_api"
  end

  on(:topic_created) do |topic, opts, user|
    begin
      return unless topic && opts
      topic.custom_fields["is_general_question"] = opts[:is_general_question] == true
      %w[vehicle_year vehicle_make vehicle_model vehicle_trim vehicle_engine].each do |field|
        topic.custom_fields[field] = opts[field.to_sym] if opts[field.to_sym].present?
      end
      topic.save_custom_fields
    rescue => e
      Rails.logger.error("[VehiclePlugin] Error in topic_created: #{e.message}")
    end
  end
end

register_asset "stylesheets/vehicle-fields.scss"
