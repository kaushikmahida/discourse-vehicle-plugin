import { withPluginApi } from "discourse/lib/plugin-api";

const VEHICLE_YEARS = [];
const currentYear = new Date().getFullYear();
for (let year = currentYear + 1; year >= 1980; year--) {
  VEHICLE_YEARS.push({ id: year.toString(), name: year.toString() });
}

const VEHICLE_MAKES = [
  { id: "acura", name: "Acura" },
  { id: "audi", name: "Audi" },
  { id: "bmw", name: "BMW" },
  { id: "buick", name: "Buick" },
  { id: "cadillac", name: "Cadillac" },
  { id: "chevrolet", name: "Chevrolet" },
  { id: "chrysler", name: "Chrysler" },
  { id: "dodge", name: "Dodge" },
  { id: "ford", name: "Ford" },
  { id: "gmc", name: "GMC" },
  { id: "honda", name: "Honda" },
  { id: "hyundai", name: "Hyundai" },
  { id: "infiniti", name: "Infiniti" },
  { id: "jaguar", name: "Jaguar" },
  { id: "jeep", name: "Jeep" },
  { id: "kia", name: "Kia" },
  { id: "land_rover", name: "Land Rover" },
  { id: "lexus", name: "Lexus" },
  { id: "lincoln", name: "Lincoln" },
  { id: "mazda", name: "Mazda" },
  { id: "mercedes", name: "Mercedes-Benz" },
  { id: "mini", name: "MINI" },
  { id: "mitsubishi", name: "Mitsubishi" },
  { id: "nissan", name: "Nissan" },
  { id: "porsche", name: "Porsche" },
  { id: "ram", name: "RAM" },
  { id: "subaru", name: "Subaru" },
  { id: "tesla", name: "Tesla" },
  { id: "toyota", name: "Toyota" },
  { id: "volkswagen", name: "Volkswagen" },
  { id: "volvo", name: "Volvo" },
  { id: "other", name: "Other" },
];

const ENGINE_TYPES = [
  { id: "4cyl", name: "4-Cylinder" },
  { id: "6cyl", name: "6-Cylinder (V6)" },
  { id: "8cyl", name: "8-Cylinder (V8)" },
  { id: "diesel", name: "Diesel" },
  { id: "hybrid", name: "Hybrid" },
  { id: "electric", name: "Electric" },
  { id: "turbo4", name: "Turbocharged 4-Cylinder" },
  { id: "turbo6", name: "Turbocharged 6-Cylinder" },
  { id: "other", name: "Other" },
];

export default {
  name: "vehicle-fields",

  initialize() {
    withPluginApi("1.0.0", (api) => {
      // Add vehicle data to window for components to access
      window.VehicleFieldsData = {
        years: VEHICLE_YEARS,
        makes: VEHICLE_MAKES,
        engines: ENGINE_TYPES,
      };

      // Extend composer model to include vehicle fields
      api.modifyClass("model:composer", {
        pluginId: "discourse-vehicle-plugin",

        vehicle_year: null,
        vehicle_make: null,
        vehicle_model: null,
        vehicle_engine: null,
      });

      // Serialize vehicle fields when creating topic
      api.serializeOnCreate("vehicle_year");
      api.serializeOnCreate("vehicle_make");
      api.serializeOnCreate("vehicle_model");
      api.serializeOnCreate("vehicle_engine");

      // Serialize on update too
      api.serializeToDraft("vehicle_year");
      api.serializeToDraft("vehicle_make");
      api.serializeToDraft("vehicle_model");
      api.serializeToDraft("vehicle_engine");

      // Vehicle info badge is now displayed via the topic-above-post-stream connector
      // See: connectors/topic-above-post-stream/vehicle-info-badge.hbs

      // Center composer as dialog when opened
      const applyDialogStyles = () => {
        const replyControl = document.getElementById("reply-control");
        if (replyControl && replyControl.classList.contains("open")) {
          replyControl.style.cssText = `
            position: fixed !important;
            bottom: auto !important;
            top: 50% !important;
            left: 50% !important;
            transform: translate(-50%, -50%) !important;
            width: 90vw !important;
            max-width: 800px !important;
            height: auto !important;
            max-height: 90vh !important;
            border-radius: 12px !important;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5) !important;
            z-index: 1100 !important;
          `;
          document.body.classList.add("composer-open");

          // Add backdrop if not exists
          if (!document.getElementById("composer-backdrop")) {
            const backdrop = document.createElement("div");
            backdrop.id = "composer-backdrop";
            backdrop.style.cssText = `
              position: fixed;
              top: 0;
              left: 0;
              right: 0;
              bottom: 0;
              background: rgba(0, 0, 0, 0.5);
              z-index: 1050;
            `;
            document.body.appendChild(backdrop);
          }
        }
      };

      const removeBackdrop = () => {
        const backdrop = document.getElementById("composer-backdrop");
        if (backdrop) {
          backdrop.remove();
        }
      };

      api.onAppEvent("composer:opened", () => {
        // Small delay to ensure DOM is ready
        setTimeout(applyDialogStyles, 50);
      });

      api.onAppEvent("composer:closed", () => {
        document.body.classList.remove("composer-open");
        removeBackdrop();
      });

      api.onAppEvent("composer:cancelled", () => {
        document.body.classList.remove("composer-open");
        removeBackdrop();
      });
    });
  },
};

