import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class VehicleFieldsComposer extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked isGeneralQuestion = false;
  
  // Selected values (storing both id and name)
  @tracked selectedYear = null;
  @tracked selectedMakeId = null;
  @tracked selectedMakeName = null;
  @tracked selectedModelId = null;
  @tracked selectedModelName = null;
  @tracked selectedTrimId = null;
  @tracked selectedTrimName = null;
  @tracked selectedEngine = null;
  
  // Available options from VCDB
  @tracked availableYears = [];
  @tracked availableMakes = [];
  @tracked availableModels = [];
  @tracked availableTrims = [];
  @tracked availableEngines = [];
  
  // Loading states
  @tracked isLoadingYears = false;
  @tracked isLoadingMakes = false;
  @tracked isLoadingModels = false;
  @tracked isLoadingTrims = false;

  constructor() {
    super(...arguments);
    this.loadYears();
    this.loadEngines();
  }

  get model() {
    return this.args.outletArgs?.model;
  }

  get showVehicleFields() {
    if (!this.model) return false;
    return this.model.action === "createTopic";
  }

  get hasVehicleFromSSO() {
    if (!this.currentUser) return false;
    const user = this.currentUser;
    const customFields = user.custom_fields || {};
    return !!(user.vehicle_year || customFields.vehicle_year);
  }

  // Format for ComboBox
  get formattedYears() {
    return this.availableYears.map(year => ({ id: year.toString(), name: year.toString() }));
  }

  get formattedMakes() {
    return this.availableMakes.map(m => ({ id: m.id.toString(), name: m.name }));
  }

  get formattedModels() {
    return this.availableModels.map(m => ({ id: m.id.toString(), name: m.name }));
  }

  get formattedTrims() {
    return this.availableTrims.map(t => ({ id: t.id.toString(), name: t.name }));
  }

  get formattedEngines() {
    return this.availableEngines.map(e => ({ id: e, name: e }));
  }

  get canSelectMake() {
    return !!this.selectedYear && !this.isLoadingMakes;
  }

  get canSelectModel() {
    return !!this.selectedYear && !!this.selectedMakeId && !this.isLoadingModels;
  }

  get canSelectTrim() {
    return !!this.selectedYear && !!this.selectedMakeId && !!this.selectedModelId && !this.isLoadingTrims;
  }

  get canSelectEngine() {
    return !!this.selectedYear && !!this.selectedMakeId && !!this.selectedModelId;
  }

  @action
  toggleGeneralQuestion() {
    this.isGeneralQuestion = !this.isGeneralQuestion;
    
    if (this.isGeneralQuestion && this.model) {
      this.model.vehicle_year = null;
      this.model.vehicle_make = null;
      this.model.vehicle_model = null;
      this.model.vehicle_trim = null;
      this.model.vehicle_engine = null;
      this.model.is_general_question = true;
    } else if (this.model) {
      this.model.is_general_question = false;
    }
  }

  async loadYears() {
    this.isLoadingYears = true;
    try {
      const response = await ajax("/vehicle-api/years");
      this.availableYears = response.years || [];
    } catch (error) {
      console.error("[VehiclePlugin] Failed to load years:", error);
      // Fallback
      const currentYear = new Date().getFullYear();
      this.availableYears = Array.from({ length: 35 }, (_, i) => currentYear + 1 - i);
    } finally {
      this.isLoadingYears = false;
    }
  }

  async loadMakes(year) {
    this.isLoadingMakes = true;
    this.availableMakes = [];
    try {
      const response = await ajax(`/vehicle-api/makes?year=${year}`);
      this.availableMakes = response.makes || [];
    } catch (error) {
      console.error("[VehiclePlugin] Failed to load makes:", error);
    } finally {
      this.isLoadingMakes = false;
    }
  }

  async loadModels(year, makeId) {
    this.isLoadingModels = true;
    this.availableModels = [];
    try {
      const response = await ajax(`/vehicle-api/models?year=${year}&make_id=${makeId}`);
      this.availableModels = response.models || [];
    } catch (error) {
      console.error("[VehiclePlugin] Failed to load models:", error);
    } finally {
      this.isLoadingModels = false;
    }
  }

  async loadTrims(year, makeId, modelId) {
    this.isLoadingTrims = true;
    this.availableTrims = [];
    try {
      const response = await ajax(`/vehicle-api/trims?year=${year}&make_id=${makeId}&model_id=${modelId}`);
      this.availableTrims = response.trims || [];
    } catch (error) {
      console.error("[VehiclePlugin] Failed to load trims:", error);
    } finally {
      this.isLoadingTrims = false;
    }
  }

  async loadEngines() {
    try {
      const response = await ajax("/vehicle-api/engines");
      this.availableEngines = response.engines || [];
    } catch (error) {
      console.error("[VehiclePlugin] Failed to load engines:", error);
      this.availableEngines = ["2.0L I4", "2.5L I4", "3.5L V6", "5.0L V8", "Hybrid", "Electric", "Other"];
    }
  }

  @action
  async onYearChange(value) {
    this.selectedYear = value;
    
    // Reset dependent fields
    this.selectedMakeId = null;
    this.selectedMakeName = null;
    this.selectedModelId = null;
    this.selectedModelName = null;
    this.selectedTrimId = null;
    this.selectedTrimName = null;
    this.selectedEngine = null;
    this.availableMakes = [];
    this.availableModels = [];
    this.availableTrims = [];
    
    if (this.model) {
      this.model.vehicle_year = value;
      this.model.vehicle_make = null;
      this.model.vehicle_model = null;
      this.model.vehicle_trim = null;
      this.model.vehicle_engine = null;
    }

    if (value) {
      await this.loadMakes(value);
    }
  }

  @action
  async onMakeChange(value) {
    this.selectedMakeId = value;
    
    // Find make name
    const make = this.availableMakes.find(m => m.id.toString() === value);
    this.selectedMakeName = make?.name || null;
    
    // Reset dependent fields
    this.selectedModelId = null;
    this.selectedModelName = null;
    this.selectedTrimId = null;
    this.selectedTrimName = null;
    this.selectedEngine = null;
    this.availableModels = [];
    this.availableTrims = [];
    
    if (this.model) {
      this.model.vehicle_make = this.selectedMakeName;
      this.model.vehicle_model = null;
      this.model.vehicle_trim = null;
      this.model.vehicle_engine = null;
    }

    if (value && this.selectedYear) {
      await this.loadModels(this.selectedYear, value);
    }
  }

  @action
  async onModelChange(value) {
    this.selectedModelId = value;
    
    // Find model name
    const model = this.availableModels.find(m => m.id.toString() === value);
    this.selectedModelName = model?.name || null;
    
    // Reset dependent fields
    this.selectedTrimId = null;
    this.selectedTrimName = null;
    this.selectedEngine = null;
    this.availableTrims = [];
    
    if (this.model) {
      this.model.vehicle_model = this.selectedModelName;
      this.model.vehicle_trim = null;
      this.model.vehicle_engine = null;
    }

    if (value && this.selectedYear && this.selectedMakeId) {
      await this.loadTrims(this.selectedYear, this.selectedMakeId, value);
    }
  }

  @action
  onTrimChange(value) {
    this.selectedTrimId = value;
    
    // Find trim name
    const trim = this.availableTrims.find(t => t.id.toString() === value);
    this.selectedTrimName = trim?.name || null;
    
    if (this.model) {
      this.model.vehicle_trim = this.selectedTrimName;
    }
  }

  @action
  onEngineChange(value) {
    this.selectedEngine = value;
    
    if (this.model) {
      this.model.vehicle_engine = value;
    }
  }
}
