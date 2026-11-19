#include <cmath>
#include <iostream>
#include <limits>
#include <string_view>

namespace augmented_hub {

struct AttenuationInput {
    double k_bio;
    double f_bio;
    double k_sorb;
    double f_sorb;
    double k_dil;
    double f_dil;
    double k_resus;
    double f_resus;
    double harm_risk;
    double maximum_harm_risk;
    bool mass_balance_available;
    bool biofilm_evidence_accepted;
    bool sorptive_media_serviceable;
    bool dilution_not_removal_credit;
    bool ecological_review_complete;
    bool human_review_complete;
    bool open_environment_release_proposed;
};

enum class Decision {
    EligibleForHumanReview,
    ReviewRequired,
    Excluded
};

struct Evaluation {
    Decision decision;
    double attenuation_potential;
    std::string_view reason;
};

bool finite_nonnegative(const double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool unit_interval(const double value) noexcept {
    return finite_nonnegative(value) && value <= 1.0;
}

Evaluation evaluate(const AttenuationInput& input) noexcept {
    if (!finite_nonnegative(input.k_bio)
        || !finite_nonnegative(input.k_sorb)
        || !finite_nonnegative(input.k_dil)
        || !finite_nonnegative(input.k_resus)
        || !unit_interval(input.f_bio)
        || !unit_interval(input.f_sorb)
        || !unit_interval(input.f_dil)
        || !unit_interval(input.f_resus)
        || !unit_interval(input.harm_risk)
        || !unit_interval(input.maximum_harm_risk)) {
        return {
            Decision::ReviewRequired,
            0.0,
            "coefficients must be finite and non-negative; fractions and risk must be in [0, 1]"
        };
    }

    const double potential =
        input.k_bio * input.f_bio +
        input.k_sorb * input.f_sorb +
        input.k_dil * input.f_dil -
        input.k_resus * input.f_resus;

    if (!std::isfinite(potential)) {
        return {
            Decision::ReviewRequired,
            0.0,
            "attenuation potential is non-finite"
        };
    }

    if (input.open_environment_release_proposed) {
        return {
            Decision::Excluded,
            potential,
            "open environmental bioaugmentation is outside this research-ranking component"
        };
    }

    if (!input.mass_balance_available
        || !input.biofilm_evidence_accepted
        || !input.sorptive_media_serviceable
        || !input.dilution_not_removal_credit
        || !input.ecological_review_complete
        || !input.human_review_complete) {
        return {
            Decision::ReviewRequired,
            potential,
            "required evidence, containment, ecological review, or human review gate is incomplete"
        };
    }

    if (input.harm_risk > input.maximum_harm_risk) {
        return {
            Decision::ReviewRequired,
            potential,
            "harm risk exceeds the declared policy limit"
        };
    }

    return {
        Decision::EligibleForHumanReview,
        potential,
        "attenuation potential is available for human review only"
    };
}

}  // namespace augmented_hub

int main() {
    const augmented_hub::AttenuationInput input{
        .k_bio = 0.0,
        .f_bio = 0.0,
        .k_sorb = 0.7,
        .f_sorb = 0.5,
        .k_dil = 0.0,
        .f_dil = 0.0,
        .k_resus = 0.4,
        .f_resus = 0.2,
        .harm_risk = 0.10,
        .maximum_harm_risk = 0.30,
        .mass_balance_available = true,
        .biofilm_evidence_accepted = false,
        .sorptive_media_serviceable = true,
        .dilution_not_removal_credit = true,
        .ecological_review_complete = true,
        .human_review_complete = true,
        .open_environment_release_proposed = false,
    };

    const augmented_hub::Evaluation result =
        augmented_hub::evaluate(input);

    std::cout << "decision=" << static_cast<int>(result.decision)
              << "\nattenuation_potential=" << result.attenuation_potential
              << "\nreason=" << result.reason
              << '\n';

    return result.decision == augmented_hub::Decision::Excluded ? 1 : 0;
}
