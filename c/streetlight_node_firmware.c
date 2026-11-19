#include <stdbool.h>
#include <stdint.h>

typedef enum {
    NODE_NORMAL,
    NODE_OUTAGE,
    NODE_LOW_POWER,
    NODE_FAULT
} NodeMode;

typedef struct {
    bool grid_power_present;
    bool luminaire_feedback_present;
    bool secure_boot_valid;
    bool sensor_bus_healthy;
    bool lorawan_joined;
    bool battery_healthy;
    float battery_confidence;
    float temperature_c;
    float humidity_percent;
    float illuminance_lux;
} NodeInputs;

typedef struct {
    NodeMode mode;
    bool sample_environment;
    bool transmit_telemetry;
    bool transmit_outage_beacon;
    bool enable_optional_mesh_relay;
    bool permit_firmware_update;
    bool request_maintenance;
} NodeActions;

static float clamp_unit(float value) {
    if (value < 0.0f) {
        return 0.0f;
    }
    if (value > 1.0f) {
        return 1.0f;
    }
    return value;
}

NodeActions evaluate_node_state(const NodeInputs *inputs) {
    NodeActions actions = {
        .mode = NODE_NORMAL,
        .sample_environment = true,
        .transmit_telemetry = inputs->lorawan_joined,
        .transmit_outage_beacon = false,
        .enable_optional_mesh_relay = inputs->lorawan_joined,
        .permit_firmware_update = false,
        .request_maintenance = false
    };

    if (!inputs->secure_boot_valid) {
        actions.mode = NODE_FAULT;
        actions.sample_environment = false;
        actions.transmit_telemetry = false;
        actions.enable_optional_mesh_relay = false;
        actions.request_maintenance = true;
        return actions;
    }

    if (!inputs->grid_power_present) {
        actions.mode = inputs->battery_healthy && clamp_unit(inputs->battery_confidence) >= 0.20f
            ? NODE_OUTAGE
            : NODE_LOW_POWER;
        actions.sample_environment = false;
        actions.transmit_telemetry = false;
        actions.transmit_outage_beacon = inputs->lorawan_joined && inputs->battery_healthy;
        actions.enable_optional_mesh_relay = false;
        actions.permit_firmware_update = false;
        return actions;
    }

    if (!inputs->sensor_bus_healthy || !inputs->luminaire_feedback_present) {
        actions.request_maintenance = true;
    }

    return actions;
}
