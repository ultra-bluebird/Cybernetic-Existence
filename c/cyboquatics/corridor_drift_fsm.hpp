#ifndef AUGMENTED_HUB_CORRIDOR_DRIFT_FSM_HPP
#define AUGMENTED_HUB_CORRIDOR_DRIFT_FSM_HPP

#include <cmath>
#include <cstddef>
#include <optional>
#include <stdexcept>
#include <string>

namespace augmented_hub::cyboquatics {

enum class DriftState {
    Uninitialized,
    Nominal,
    Suspect,
    DriftLockout,
    InvalidInputLockout
};

struct DriftResult {
    DriftState state;
    std::size_t consecutive_exceedances;
    std::optional<double> residual;
    bool safe_for_automated_reliance;
    bool requires_manual_review;
    std::string reason;
};

class CorridorDriftFsm final {
public:
    explicit CorridorDriftFsm(std::size_t threshold_samples)
        : threshold_samples_(threshold_samples) {
        if (threshold_samples_ == 0U) {
            throw std::invalid_argument("threshold_samples must be greater than zero");
        }
    }

    [[nodiscard]] DriftResult observe(
        const double observed,
        const double reference,
        const double tolerance) noexcept {
        if (!std::isfinite(observed) || !std::isfinite(reference) ||
            !std::isfinite(tolerance) || tolerance <= 0.0) {
            state_ = DriftState::InvalidInputLockout;
            consecutive_exceedances_ = 0U;
            return {
                state_,
                consecutive_exceedances_,
                std::nullopt,
                false,
                true,
                "Invalid observation, reference, or tolerance; fail-closed lockout."
            };
        }

        const double residual = std::abs(observed - reference) / tolerance;
        if (residual <= 1.0) {
            state_ = DriftState::Nominal;
            consecutive_exceedances_ = 0U;
            return {
                state_,
                consecutive_exceedances_,
                residual,
                true,
                false,
                "Residual is within the calibration corridor."
            };
        }

        ++consecutive_exceedances_;
        if (consecutive_exceedances_ >= threshold_samples_) {
            state_ = DriftState::DriftLockout;
            return {
                state_,
                consecutive_exceedances_,
                residual,
                false,
                true,
                "Drift threshold reached; manual calibration review required."
            };
        }

        state_ = DriftState::Suspect;
        return {
            state_,
            consecutive_exceedances_,
            residual,
            false,
            false,
            "Residual exceeded corridor; awaiting consecutive-sample confirmation."
        };
    }

    [[nodiscard]] DriftState state() const noexcept {
        return state_;
    }

    [[nodiscard]] std::size_t threshold_samples() const noexcept {
        return threshold_samples_;
    }

private:
    DriftState state_ {DriftState::Uninitialized};
    std::size_t consecutive_exceedances_ {0U};
    std::size_t threshold_samples_;
};

}  // namespace augmented_hub::cyboquatics

#endif
