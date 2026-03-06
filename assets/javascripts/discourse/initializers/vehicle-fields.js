import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "vehicle-fields",

  initialize() {
    withPluginApi("1.0.0", (api) => {
      // Extend composer model to include vehicle + DTC fields
      api.modifyClass("model:composer", {
        pluginId: "discourse-vehicle-plugin",

        vehicle_year: null,
        vehicle_make: null,
        vehicle_model: null,
        vehicle_trim: null,
        vehicle_engine: null,
        is_general_question: null,
        dtc_codes: null,
      });

      // Serialize all fields when creating topic
      api.serializeOnCreate("vehicle_year");
      api.serializeOnCreate("vehicle_make");
      api.serializeOnCreate("vehicle_model");
      api.serializeOnCreate("vehicle_trim");
      api.serializeOnCreate("vehicle_engine");
      api.serializeOnCreate("is_general_question");
      api.serializeOnCreate("dtc_codes");

      // Serialize on draft too
      api.serializeToDraft("vehicle_year");
      api.serializeToDraft("vehicle_make");
      api.serializeToDraft("vehicle_model");
      api.serializeToDraft("vehicle_trim");
      api.serializeToDraft("vehicle_engine");
      api.serializeToDraft("is_general_question");
      api.serializeToDraft("dtc_codes");

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
