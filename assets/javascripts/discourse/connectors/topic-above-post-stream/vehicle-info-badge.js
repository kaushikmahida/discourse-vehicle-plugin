import Component from "@glimmer/component";

export default class VehicleInfoBadge extends Component {
  get topic() {
    return this.args.outletArgs?.model;
  }

  get vehicleInfo() {
    if (!this.topic) return null;

    const year = this.topic.vehicle_year;
    const make = this.topic.vehicle_make;
    const model = this.topic.vehicle_model;
    const engine = this.topic.vehicle_engine;

    if (!year && !make && !model) return null;

    return [year, make, model, engine].filter(Boolean).join(" ");
  }
}

