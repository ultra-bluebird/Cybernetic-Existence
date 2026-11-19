#include <stdbool.h>
#include <stdint.h>

typedef enum {
    POWER_MODE_NORMAL = 0,
    POWER_MODE_CONSERVATION = 1,
    POWER_MODE_CRITICAL_RESERVE = 2,
    POWER_MODE_FAULT = 3
} power_mode_t;

typedef struct {
    uint32_t storage_capacity_millijoules;
    uint32_t storage_energy_millijoules;
    uint32_t critical_reserve_millijoules;
    uint32_t conservation_threshold_millijoules;
    uint32_t normal_threshold_millijoules;
    uint32_t measurement_cost_millijoules;
    uint32_t transmission_cost_millijoules;
    uint32_t maximum_charge_current_milliamps;
} power_profile_t;

typedef struct {
    power_mode_t mode;
    uint32_t available_energy_millijoules;
    bool routine_sampling_allowed;
    bool routine_transmission_allowed;
    bool critical_alert_transmission_allowed;
} power_decision_t;

static bool profile_is_valid(const power_profile_t *profile) {
    if (profile == 0) {
        return false;
    }

    if (profile->storage_capacity_millijoules == 0U) {
        return false;
    }

    if (profile->critical_reserve_millijoules >=
        profile->conservation_threshold_millijoules) {
        return false;
    }

    if (profile->conservation_threshold_millijoules >=
        profile->normal_threshold_millijoules) {
        return false;
    }

    if (profile->normal_threshold_millijoules >
        profile->storage_capacity_millijoules) {
        return false;
    }

    if (profile->measurement_cost_millijoules == 0U ||
        profile->transmission_cost_millijoules == 0U ||
        profile->maximum_charge_current_milliamps == 0U) {
        return false;
    }

    return true;
}

bool power_manager_apply_harvest(
    power_profile_t *profile,
    uint32_t harvested_energy_millijoules
) {
    uint32_t available_capacity;
    uint32_t accepted_energy;

    if (!profile_is_valid(profile)) {
        return false;
    }

    available_capacity =
        profile->storage_capacity_millijoules -
        profile->storage_energy_millijoules;

    accepted_energy = harvested_energy_millijoules;
    if (accepted_energy > available_capacity) {
        accepted_energy = available_capacity;
    }

    profile->storage_energy_millijoules += accepted_energy;
    return true;
}

power_decision_t power_manager_decide(
    const power_profile_t *profile
) {
    power_decision_t decision;

    decision.mode = POWER_MODE_FAULT;
    decision.available_energy_millijoules = 0U;
    decision.routine_sampling_allowed = false;
    decision.routine_transmission_allowed = false;
    decision.critical_alert_transmission_allowed = false;

    if (!profile_is_valid(profile) ||
        profile->storage_energy_millijoules >
        profile->storage_capacity_millijoules) {
        return decision;
    }

    decision.available_energy_millijoules =
        profile->storage_energy_millijoules;

    if (profile->storage_energy_millijoules >=
        profile->normal_threshold_millijoules) {
        decision.mode = POWER_MODE_NORMAL;
        decision.routine_sampling_allowed = true;
        decision.routine_transmission_allowed = true;
        decision.critical_alert_transmission_allowed = true;
        return decision;
    }

    if (profile->storage_energy_millijoules >=
        profile->conservation_threshold_millijoules) {
        decision.mode = POWER_MODE_CONSERVATION;
        decision.routine_sampling_allowed = true;
        decision.routine_transmission_allowed = false;
        decision.critical_alert_transmission_allowed = true;
        return decision;
    }

    if (profile->storage_energy_millijoules >=
        profile->critical_reserve_millijoules +
        profile->transmission_cost_millijoules) {
        decision.mode = POWER_MODE_CRITICAL_RESERVE;
        decision.routine_sampling_allowed = false;
        decision.routine_transmission_allowed = false;
        decision.critical_alert_transmission_allowed = true;
        return decision;
    }

    decision.mode = POWER_MODE_CRITICAL_RESERVE;
    return decision;
}

bool power_manager_consume(
    power_profile_t *profile,
    uint32_t energy_cost_millijoules
) {
    if (!profile_is_valid(profile)) {
        return false;
    }

    if (energy_cost_millijoules > profile->storage_energy_millijoules) {
        return false;
    }

    if (profile->storage_energy_millijoules - energy_cost_millijoules <
        profile->critical_reserve_millijoules) {
        return false;
    }

    profile->storage_energy_millijoules -= energy_cost_millijoules;
    return true;
}
