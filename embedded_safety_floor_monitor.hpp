#ifndef AUGMENTED_HUB_EMBEDDED_SAFETY_FLOOR_MONITOR_HPP
#define AUGMENTED_HUB_EMBEDDED_SAFETY_FLOOR_MONITOR_HPP

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace augmented_hub::cyboquatic {

enum class DecisionState : std::uint8_t {
    Simulate = 0,
    Derate = 1,
    Hold = 2,
    Reject = 3
};

enum class EvidenceState : std::uint8_t {
    Measured = 0,
    Calculated = 1,
    Modeled = 2,
    ConservativeFallback = 3,
    Missing = 4
};

enum class SafetyFloorKind : std::uint8_t {
    Storage = 0,
    EcologicalFlow = 1,
    WaterQuality = 2,
    WaterTemperature = 3,
    HeatRisk = 4,
    Accessibility = 5,
    Knowledge = 6,
    Governance = 7
};

struct NormalizedMargin {
    float value;

    constexpr bool finite() const noexcept {
        return value == value
            && value != std::numeric_limits<float>::infinity()
            && value != -std::numeric_limits<float>::infinity();
    }

    constexpr bool passed() const noexcept {
        return finite() && value >= 0.0F;
    }
};

struct SafetyFloorReading {
    SafetyFloorKind kind;
    NormalizedMargin margin;
    EvidenceState evidence;
    bool required;
};

struct SafetyAssessment {
    DecisionState decision;
    float admissibility_index;
    std::uint16_t failed_floor_mask;
    std::uint16_t narrow_margin_mask;
    EvidenceState weakest_evidence;
};

struct TelemetryFrame {
    std::uint32_t protocol_version;
    std::uint32_t sequence_number;
    std::uint64_t observed_unix_seconds;
    std::uint16_t station_short_id;
    DecisionState decision;
    std::uint16_t failed_floor_mask;
    std::uint16_t narrow_margin_mask;
    std::int16_t admissibility_index_milliunits;
    EvidenceState weakest_evidence;
    std::uint16_t frame_crc16;
};

constexpr std::uint16_t floor_mask(SafetyFloorKind kind) noexcept {
    return static_cast<std::uint16_t>(1U << static_cast<std::uint8_t>(kind));
}

constexpr std::uint8_t decision_severity(DecisionState state) noexcept {
    return static_cast<std::uint8_t>(state);
}

constexpr DecisionState join_decision(
    DecisionState left,
    DecisionState right
) noexcept {
    return decision_severity(left) >= decision_severity(right) ? left : right;
}

constexpr EvidenceState weakest_evidence(
    EvidenceState left,
    EvidenceState right
) noexcept {
    return static_cast<std::uint8_t>(left) >= static_cast<std::uint8_t>(right)
        ? left
        : right;
}

inline SafetyAssessment assess_safety_floors(
    const SafetyFloorReading* readings,
    std::size_t reading_count,
    float narrow_margin_threshold
) noexcept {
    SafetyAssessment assessment{
        .decision = DecisionState::Simulate,
        .admissibility_index = std::numeric_limits<float>::infinity(),
        .failed_floor_mask = 0U,
        .narrow_margin_mask = 0U,
        .weakest_evidence = EvidenceState::Measured
    };

    if (readings == nullptr || reading_count == 0U) {
        assessment.decision = DecisionState::Hold;
        assessment.admissibility_index = -1.0F;
        assessment.weakest_evidence = EvidenceState::Missing;
        return assessment;
    }

    for (std::size_t index = 0U; index < reading_count; ++index) {
        const SafetyFloorReading& reading = readings[index];

        assessment.weakest_evidence = weakest_evidence(
            assessment.weakest_evidence,
            reading.evidence
        );

        if (!reading.required) {
            continue;
        }

        if (reading.evidence == EvidenceState::Missing || !reading.margin.finite()) {
            assessment.decision = join_decision(
                assessment.decision,
                DecisionState::Hold
            );
            assessment.failed_floor_mask |= floor_mask(reading.kind);
            assessment.admissibility_index = -1.0F;
            continue;
        }

        if (reading.margin.value < assessment.admissibility_index) {
            assessment.admissibility_index = reading.margin.value;
        }

        if (!reading.margin.passed()) {
            assessment.decision = DecisionState::Reject;
            assessment.failed_floor_mask |= floor_mask(reading.kind);
            continue;
        }

        if (reading.margin.value < narrow_margin_threshold) {
            assessment.decision = join_decision(
                assessment.decision,
                DecisionState::Derate
            );
            assessment.narrow_margin_mask |= floor_mask(reading.kind);
        }
    }

    if (assessment.admissibility_index == std::numeric_limits<float>::infinity()) {
        assessment.decision = join_decision(
            assessment.decision,
            DecisionState::Hold
        );
        assessment.admissibility_index = -1.0F;
    }

    return assessment;
}

constexpr std::int16_t encode_milliunits(float value) noexcept {
    const float scaled = value * 1000.0F;

    if (scaled > static_cast<float>(std::numeric_limits<std::int16_t>::max())) {
        return std::numeric_limits<std::int16_t>::max();
    }

    if (scaled < static_cast<float>(std::numeric_limits<std::int16_t>::min())) {
        return std::numeric_limits<std::int16_t>::min();
    }

    return static_cast<std::int16_t>(scaled);
}

inline std::uint16_t crc16_ccitt(
    const std::uint8_t* bytes,
    std::size_t length
) noexcept {
    std::uint16_t crc = 0xFFFFU;

    for (std::size_t index = 0U; index < length; ++index) {
        crc ^= static_cast<std::uint16_t>(bytes[index]) << 8U;

        for (std::uint8_t bit = 0U; bit < 8U; ++bit) {
            crc = (crc & 0x8000U) != 0U
                ? static_cast<std::uint16_t>((crc << 1U) ^ 0x1021U)
                : static_cast<std::uint16_t>(crc << 1U);
        }
    }

    return crc;
}

inline TelemetryFrame build_telemetry_frame(
    std::uint32_t sequence_number,
    std::uint64_t observed_unix_seconds,
    std::uint16_t station_short_id,
    const SafetyAssessment& assessment
) noexcept {
    TelemetryFrame frame{
        .protocol_version = 1U,
        .sequence_number = sequence_number,
        .observed_unix_seconds = observed_unix_seconds,
        .station_short_id = station_short_id,
        .decision = assessment.decision,
        .failed_floor_mask = assessment.failed_floor_mask,
        .narrow_margin_mask = assessment.narrow_margin_mask,
        .admissibility_index_milliunits = encode_milliunits(
            assessment.admissibility_index
        ),
        .weakest_evidence = assessment.weakest_evidence,
        .frame_crc16 = 0U
    };

    frame.frame_crc16 = crc16_ccitt(
        reinterpret_cast<const std::uint8_t*>(&frame),
        sizeof(TelemetryFrame) - sizeof(frame.frame_crc16)
    );

    return frame;
}

}  // namespace augmented_hub::cyboquatic

#endif
