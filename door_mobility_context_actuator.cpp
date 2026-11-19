#include <algorithm>
#include <cstdint>

namespace augmented_hub::door {

enum class MobilityContext : std::uint8_t {
    StandardApproach,
    WheeledMobilityContext,
    WalkingAidContext,
    CaneOrLongObjectContext,
    MobilityAssistDeviceContext,
    MultipleOrUncertainContext,
    NoActionableContext
};

struct VisionInference {
    MobilityContext context;
    float confidence;
    bool approaching_door;
    bool model_healthy;
};

struct SafetyState {
    bool operator_healthy;
    bool pressure_mat_clear;
    bool lidar_clear;
    bool ultrasonic_clear;
    bool obstruction_clear;
};

struct AssistanceRequest {
    float width_ratio;
    std::uint32_t hold_open_ms;
    float speed_ratio;
    bool vision_assistance_active;
    bool use_standard_accessible_profile;
};

class MobilityContextActuator {
public:
    AssistanceRequest select(
        const VisionInference& inference,
        const SafetyState& safety
    ) const {
        if (
            !safety.operator_healthy ||
            !safety.pressure_mat_clear ||
            !safety.lidar_clear ||
            !safety.ultrasonic_clear ||
            !safety.obstruction_clear
        ) {
            return {
                .width_ratio = 1.0F,
                .hold_open_ms = extended_hold_open_ms_,
                .speed_ratio = 0.0F,
                .vision_assistance_active = false,
                .use_standard_accessible_profile = true
            };
        }

        if (
            !inference.model_healthy ||
            !inference.approaching_door ||
            inference.confidence < confidence_threshold_
        ) {
            return standard_profile();
        }

        switch (inference.context) {
            case MobilityContext::WheeledMobilityContext:
            case MobilityContext::WalkingAidContext:
            case MobilityContext::MobilityAssistDeviceContext:
            case MobilityContext::MultipleOrUncertainContext:
                return extended_profile();

            case MobilityContext::CaneOrLongObjectContext:
                return {
                    .width_ratio = 0.85F,
                    .hold_open_ms = extended_hold_open_ms_,
                    .speed_ratio = reduced_speed_ratio_,
                    .vision_assistance_active = true,
                    .use_standard_accessible_profile = false
                };

            case MobilityContext::StandardApproach:
            case MobilityContext::NoActionableContext:
                return standard_profile();
        }

        return standard_profile();
    }

private:
    static constexpr float confidence_threshold_ = 0.65F;
    static constexpr std::uint32_t standard_hold_open_ms_ = 4000U;
    static constexpr std::uint32_t extended_hold_open_ms_ = 8000U;
    static constexpr float reduced_speed_ratio_ = 0.45F;

    static AssistanceRequest standard_profile() {
        return {
            .width_ratio = 0.70F,
            .hold_open_ms = standard_hold_open_ms_,
            .speed_ratio = 0.75F,
            .vision_assistance_active = false,
            .use_standard_accessible_profile = true
        };
    }

    static AssistanceRequest extended_profile() {
        return {
            .width_ratio = 1.0F,
            .hold_open_ms = extended_hold_open_ms_,
            .speed_ratio = reduced_speed_ratio_,
            .vision_assistance_active = true,
            .use_standard_accessible_profile = false
        };
    }
};

}
