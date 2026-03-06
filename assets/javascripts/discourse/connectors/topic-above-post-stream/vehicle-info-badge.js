import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class VehicleInfoBadge extends Component {
  @service siteSettings;

  get topic() {
    return this.args.outletArgs?.model;
  }

  get vehicleInfo() {
    if (!this.topic) return null;

    const year = this.topic.vehicle_year;
    const make = this.topic.vehicle_make;
    const model = this.topic.vehicle_model;
    const trim = this.topic.vehicle_trim;
    const engine = this.topic.vehicle_engine;

    if (!year && !make && !model) return null;

    return [year, make, model, trim, engine].filter(Boolean).join(" ");
  }

  get dtcCodes() {
    if (!this.topic) return [];
    if (!this.siteSettings.vehicle_fields_dtc_enabled) return [];

    const raw = this.topic.dtc_codes;
    if (!raw) return [];

    try {
      const parsed = typeof raw === "string" ? JSON.parse(raw) : raw;
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  get hasDtcCodes() {
    return this.dtcCodes.length > 0;
  }
}
