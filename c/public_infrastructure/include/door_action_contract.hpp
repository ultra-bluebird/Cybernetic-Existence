#pragma once

#include <cstdint>
#include <optional>
#include <string_view>

namespace augmented_hub::public_infrastructure {

enum class DoorAction {
    Open,
    HoldOpen,
    Close,
    EmergencyRelease,
    AccessibilityHold
};

enum class DoorAvailability {
    Available,
    Degraded,
    Offline,
    MaintenanceRequired,
    EmergencyMode
};

enum class DoorFallback {
    VisibleStaticInstructions,
    ManualPhysicalControl,
    EmergencyManualRelease,
    LocalFaultIndicator
};

enum class DoorActionPriority : std::uint8_t {
    EmergencyRelease = 1,
    ObstacleSafety = 2,
    AccessibilityHold = 3,
    NormalOpen = 4,
    SafeClose = 5
};

struct DoorActionContract {
    DoorAction action;
    std::string_view purpose;
    bool identity_collection_required;
    bool biometric_collection_required;
    bool health_inference_allowed;
    bool disability_inference_allowed;
    bool behavioral_profiling_allowed;
    bool recipient_effect_is_physical_access_change;
    bool reversible;
    DoorFallback safe_fallback;
    bool external_action_authorized;
};

struct DoorSafetyState {
    bool emergency_release_requested;
    bool obstacle_detected;
    bool accessibility_hold_requested;
    bool open_requested;
    bool close_requested;
    bool closure_is_safe;
    DoorAvailability availability;
};

[[nodiscard]] constexpr DoorActionPriority priority_for(
    const DoorSafetyState& state) noexcept {
    if (state.emergency_release_requested) {
        return DoorActionPriority::EmergencyRelease;
    }

    if (state.obstacle_detected) {
        return DoorActionPriority::ObstacleSafety;
    }

    if (state.accessibility_hold_requested) {
        return DoorActionPriority::AccessibilityHold;
    }

    if (state.open_requested) {
        return DoorActionPriority::NormalOpen;
    }

    return DoorActionPriority::SafeClose;
}

[[nodiscard]] constexpr bool may_close(
    const DoorSafetyState& state) noexcept {
    return state.availability == DoorAvailability::Available
        && state.close_requested
        && state.closure_is_safe
        && !state.obstacle_detected
        && !state.emergency_release_requested
        && !state.accessibility_hold_requested;
}

[[nodiscard]] constexpr bool may_open(
    const DoorSafetyState& state) noexcept {
    return state.availability == DoorAvailability::Available
        && (state.open_requested
            || state.accessibility_hold_requested
            || state.obstacle_detected
            || state.emergency_release_requested);
}

[[nodiscard]] constexpr DoorActionContract open_contract() noexcept {
    return DoorActionContract{
        DoorAction::Open,
        "Request a safe door opening cycle.",
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        DoorFallback::ManualPhysicalControl,
        false
    };
}

[[nodiscard]] constexpr DoorActionContract emergency_release_contract() noexcept {
    return DoorActionContract{
        DoorAction::EmergencyRelease,
        "Enable the approved emergency release path.",
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        DoorFallback::EmergencyManualRelease,
        false
    };
}

} // namespace augmented_hub::public_infrastructure
