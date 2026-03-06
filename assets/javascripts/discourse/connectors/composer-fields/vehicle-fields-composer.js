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

  // SSO pre-population state
  @tracked ssoVehicleLoaded = false;

  // DTC code state
  @tracked userDtcCodes = [];
  @tracked selectedDtcCodes = [];
  @tracked manualDtcInput = "";
  @tracked dtcInputError = null;

  constructor() {
    super(...arguments);
    try {
      this.loadYears();
      this.loadEngines();
      this._parseSsoDtcCodes();
      this._scheduleSsoPrePopulation();
    } catch (error) {
      console.error("[VehiclePlugin] Error in constructor:", error);
    }
  }

  get model() {
    try {
      return this.args?.outletArgs?.model;
    } catch (error) {
      console.error("[VehiclePlugin] Error getting model:", error);
      return null;
    }
  }

  get showVehicleFields() {
    try {
      if (!this.model) return false;
      return this.model.action === "createTopic";
    } catch (error) {
      console.error("[VehiclePlugin] Error checking showVehicleFields:", error);
      return false;
    }
  }

  get showDtcSection() {
    return this.siteSettings.vehicle_fields_dtc_enabled && !this.isGeneralQuestion;
  }

  get hasSsoDtcCodes() {
    return this.userDtcCodes.length > 0;
  }

  // Format for ComboBox
  get formattedYears() {
    return this.availableYears.map((year) => ({
      id: year.toString(),
      name: year.toString(),
    }));
  }

  get formattedMakes() {
    return this.availableMakes.map((m) => ({
      id: m.id.toString(),
      name: m.name,
    }));
  }

  get formattedModels() {
    return this.availableModels.map((m) => ({
      id: m.id.toString(),
      name: m.name,
    }));
  }

  get formattedTrims() {
    return this.availableTrims.map((t) => ({
      id: t.id.toString(),
      name: t.name,
    }));
  }

  get formattedEngines() {
    return this.availableEngines.map((e) => ({ id: e, name: e }));
  }

  get canSelectMake() {
    return !!this.selectedYear && !this.isLoadingMakes;
  }

  get canSelectModel() {
    return (
      !!this.selectedYear && !!this.selectedMakeId && !this.isLoadingModels
    );
  }

  get canSelectTrim() {
    return (
      !!this.selectedYear &&
      !!this.selectedMakeId &&
      !!this.selectedModelId &&
      !this.isLoadingTrims
    );
  }

  get canSelectEngine() {
    return (
      !!this.selectedYear && !!this.selectedMakeId && !!this.selectedModelId
    );
  }

  // ── SSO Pre-population ──

  _parseSsoDtcCodes() {
    if (!this.currentUser) return;

    // report_data comes from the "report" UserField (SSO-synced via custom.user_field_N)
    const jsonStr = this.currentUser.report_data;
    if (!jsonStr) return;

    try {
      const parsed = typeof jsonStr === "string" ? JSON.parse(jsonStr) : jsonStr;
      if (parsed && Array.isArray(parsed.codes)) {
        this.userDtcCodes = parsed.codes.map((c) => ({
          code: c.code,
          description: c.description || "",
          type: c.type || "Unknown",
          scannedAt: c.scannedAt || null,
          fromSso: true,
        }));
      }
    } catch (e) {
      console.error("[VehiclePlugin] Error parsing report_data:", e);
      this.userDtcCodes = [];
    }
  }

  async _scheduleSsoPrePopulation() {
    if (!this.siteSettings.vehicle_fields_sso_prepopulate) return;
    if (!this.currentUser) return;

    const user = this.currentUser;
    // Prefer report vehicle (from latest scan) over account vehicle
    const ssoYear = user.report_vehicle_year || user.vehicle_year;
    const ssoMake = user.report_vehicle_make || user.vehicle_make;
    const ssoModel = user.report_vehicle_model || user.vehicle_model;

    if (!ssoYear) return;

    // Wait for years to finish loading (max 5s timeout)
    await this._waitForYearsLoaded();

    const yearStr = ssoYear.toString();
    this.selectedYear = yearStr;
    if (this.model) this.model.vehicle_year = yearStr;

    if (ssoMake) {
      await this.loadMakes(yearStr);
      const matchingMake = this.availableMakes.find(
        (m) => m.name.toLowerCase() === ssoMake.toLowerCase()
      );
      if (matchingMake) {
        this.selectedMakeId = matchingMake.id.toString();
        this.selectedMakeName = matchingMake.name;
        if (this.model) this.model.vehicle_make = matchingMake.name;

        if (ssoModel) {
          await this.loadModels(yearStr, matchingMake.id.toString());
          const matchingModel = this.availableModels.find(
            (m) => m.name.toLowerCase() === ssoModel.toLowerCase()
          );
          if (matchingModel) {
            this.selectedModelId = matchingModel.id.toString();
            this.selectedModelName = matchingModel.name;
            if (this.model) this.model.vehicle_model = matchingModel.name;

            // Load trims so user can optionally pick one
            await this.loadTrims(
              yearStr,
              matchingMake.id.toString(),
              matchingModel.id.toString()
            );
          }
        }
      }
    }

    this.ssoVehicleLoaded = true;
  }

  _waitForYearsLoaded() {
    return new Promise((resolve) => {
      let elapsed = 0;
      const check = () => {
        if (!this.isLoadingYears && this.availableYears.length > 0) {
          resolve();
        } else if (elapsed >= 5000) {
          console.warn("[VehiclePlugin] Timed out waiting for years to load");
          resolve();
        } else {
          elapsed += 50;
          setTimeout(check, 50);
        }
      };
      check();
    });
  }

  // ── DTC Actions ──

  isDtcSelected(dtc) {
    return this.selectedDtcCodes.some((c) => c.code === dtc.code);
  }

  @action
  toggleDtcCode(dtc) {
    const idx = this.selectedDtcCodes.findIndex((c) => c.code === dtc.code);
    if (idx >= 0) {
      this.selectedDtcCodes = this.selectedDtcCodes.filter(
        (c) => c.code !== dtc.code
      );
    } else {
      this.selectedDtcCodes = [...this.selectedDtcCodes, dtc];
    }
    this._syncDtcToModel();
  }

  @action
  addManualDtcCode() {
    const code = this.manualDtcInput.trim().toUpperCase();
    if (!code) return;

    // Validate DTC format: P/B/C/U followed by 4 alphanumeric chars
    const dtcRegex = /^[PBCU][0-9A-Z]{4}$/;
    if (!dtcRegex.test(code)) {
      this.dtcInputError = "vehicle_fields.dtc_code_format_error";
      return;
    }

    // Check for duplicates
    if (this.selectedDtcCodes.find((c) => c.code === code)) {
      this.manualDtcInput = "";
      this.dtcInputError = null;
      return;
    }

    const type = code.startsWith("P")
      ? "Powertrain"
      : code.startsWith("B")
        ? "Body"
        : code.startsWith("C")
          ? "Chassis"
          : "Network";

    this.selectedDtcCodes = [
      ...this.selectedDtcCodes,
      { code, description: "", type, fromSso: false },
    ];
    this.manualDtcInput = "";
    this.dtcInputError = null;
    this._syncDtcToModel();
  }

  @action
  removeDtcCode(dtc) {
    this.selectedDtcCodes = this.selectedDtcCodes.filter(
      (c) => c.code !== dtc.code
    );
    this._syncDtcToModel();
  }

  @action
  updateManualDtcInput(event) {
    this.manualDtcInput = event.target.value;
    this.dtcInputError = null;
  }

  @action
  onDtcInputKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.addManualDtcCode();
    }
  }

  _syncDtcToModel() {
    if (this.model) {
      this.model.dtc_codes = JSON.stringify(
        this.selectedDtcCodes.map((c) => ({
          code: c.code,
          description: c.description,
          type: c.type,
        }))
      );
    }
  }

  // ── Vehicle field actions ──

  @action
  toggleGeneralQuestion() {
    this.isGeneralQuestion = !this.isGeneralQuestion;

    if (this.isGeneralQuestion && this.model) {
      this.model.vehicle_year = null;
      this.model.vehicle_make = null;
      this.model.vehicle_model = null;
      this.model.vehicle_trim = null;
      this.model.vehicle_engine = null;
      this.model.dtc_codes = null;
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
      const currentYear = new Date().getFullYear();
      this.availableYears = Array.from(
        { length: 35 },
        (_, i) => currentYear + 1 - i
      );
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
      const response = await ajax(
        `/vehicle-api/models?year=${year}&make_id=${makeId}`
      );
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
      const response = await ajax(
        `/vehicle-api/trims?year=${year}&make_id=${makeId}&model_id=${modelId}`
      );
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
      this.availableEngines = [
        "2.0L I4",
        "2.5L I4",
        "3.5L V6",
        "5.0L V8",
        "Hybrid",
        "Electric",
        "Other",
      ];
    }
  }

  @action
  async onYearChange(value) {
    const yearId =
      typeof value === "object" ? value?.id || value?.name : value;
    this.selectedYear = yearId;

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
      this.model.vehicle_year = yearId;
      this.model.vehicle_make = null;
      this.model.vehicle_model = null;
      this.model.vehicle_trim = null;
      this.model.vehicle_engine = null;
    }

    if (yearId) {
      await this.loadMakes(yearId);
    }
  }

  @action
  async onMakeChange(value) {
    const makeId =
      typeof value === "object" ? value?.id || value?.name : value;
    this.selectedMakeId = makeId;

    const make = this.availableMakes.find((m) => m.id.toString() === makeId);
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

    if (makeId && this.selectedYear) {
      await this.loadModels(this.selectedYear, makeId);
    }
  }

  @action
  async onModelChange(value) {
    const modelId =
      typeof value === "object" ? value?.id || value?.name : value;
    this.selectedModelId = modelId;

    const model = this.availableModels.find(
      (m) => m.id.toString() === modelId
    );
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

    if (modelId && this.selectedYear && this.selectedMakeId) {
      await this.loadTrims(this.selectedYear, this.selectedMakeId, modelId);
    }
  }

  @action
  onTrimChange(value) {
    const trimId =
      typeof value === "object" ? value?.id || value?.name : value;
    this.selectedTrimId = trimId;

    const trim = this.availableTrims.find((t) => t.id.toString() === trimId);
    this.selectedTrimName = trim?.name || null;

    if (this.model) {
      this.model.vehicle_trim = this.selectedTrimName;
    }
  }

  @action
  onEngineChange(value) {
    const engineValue =
      typeof value === "object" ? value?.id || value?.name : value;
    this.selectedEngine = engineValue;

    if (this.model) {
      this.model.vehicle_engine = engineValue;
    }
  }
}
