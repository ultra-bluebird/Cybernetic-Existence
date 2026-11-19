#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define APS_PROTOCOL_VERSION 1U
#define APS_MESSAGE_MAX_AGE_MS 1500U
#define APS_PAYLOAD_SIZE 48U

typedef enum {
    APS_PHASE_DONT_WALK = 0,
    APS_PHASE_WALK = 1,
    APS_PHASE_CLEARANCE = 2,
    APS_PHASE_UNKNOWN = 255
} aps_phase_t;

typedef struct {
    uint32_t intersection_code;
    uint16_t crossing_code;
    aps_phase_t phase;
    uint32_t phase_expires_at_ms;
    uint32_t sequence;
    uint16_t configuration_revision;
} aps_controller_state_t;

typedef struct {
    uint8_t protocol_version;
    uint32_t intersection_code;
    uint16_t crossing_code;
    uint8_t phase;
    uint32_t phase_expires_at_ms;
    uint32_t sequence;
    uint16_t configuration_revision;
    uint8_t signature[16];
} aps_beacon_payload_t;

typedef bool (*aps_signer_t)(
    const uint8_t *message,
    size_t message_length,
    uint8_t signature_out[16]
);

static bool phase_is_valid(aps_phase_t phase) {
    return phase == APS_PHASE_DONT_WALK ||
           phase == APS_PHASE_WALK ||
           phase == APS_PHASE_CLEARANCE;
}

static bool controller_state_is_valid(
    const aps_controller_state_t *state,
    uint32_t now_ms
) {
    if (state == NULL || !phase_is_valid(state->phase)) {
        return false;
    }

    if (state->phase_expires_at_ms <= now_ms) {
        return false;
    }

    if ((state->phase_expires_at_ms - now_ms) > APS_MESSAGE_MAX_AGE_MS) {
        return false;
    }

    return true;
}

bool aps_build_beacon(
    const aps_controller_state_t *state,
    uint32_t now_ms,
    aps_signer_t signer,
    aps_beacon_payload_t *payload_out
) {
    uint8_t serialized[APS_PAYLOAD_SIZE];
    size_t unsigned_size;

    if (payload_out == NULL || signer == NULL) {
        return false;
    }

    memset(payload_out, 0, sizeof(*payload_out));

    if (!controller_state_is_valid(state, now_ms)) {
        return false;
    }

    payload_out->protocol_version = APS_PROTOCOL_VERSION;
    payload_out->intersection_code = state->intersection_code;
    payload_out->crossing_code = state->crossing_code;
    payload_out->phase = (uint8_t)state->phase;
    payload_out->phase_expires_at_ms = state->phase_expires_at_ms;
    payload_out->sequence = state->sequence;
    payload_out->configuration_revision = state->configuration_revision;

    memset(serialized, 0, sizeof(serialized));
    serialized[0] = payload_out->protocol_version;
    memcpy(&serialized[1], &payload_out->intersection_code, sizeof(uint32_t));
    memcpy(&serialized[5], &payload_out->crossing_code, sizeof(uint16_t));
    serialized[7] = payload_out->phase;
    memcpy(&serialized[8], &payload_out->phase_expires_at_ms, sizeof(uint32_t));
    memcpy(&serialized[12], &payload_out->sequence, sizeof(uint32_t));
    memcpy(
        &serialized[16],
        &payload_out->configuration_revision,
        sizeof(uint16_t)
    );

    unsigned_size = 18U;

    if (!signer(
            serialized,
            unsigned_size,
            payload_out->signature
        )) {
        memset(payload_out, 0, sizeof(*payload_out));
        return false;
    }

    return true;
}
