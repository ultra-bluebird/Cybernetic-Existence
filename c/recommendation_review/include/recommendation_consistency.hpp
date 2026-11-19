#pragma once

#include <cmath>
#include <stdexcept>
#include <string_view>

namespace augmented_hub::recommendation_review {

enum class ConsistencyStatus {
    Valid,
    InvalidVersion,
    InvalidUncertainty,
    InvalidNonActuationBoundary,
    InvalidEvidenceState,
    InvalidContestState
};

struct RecommendationConsistencyInput {
    int recommendation_version;
    bool external_action_authorized;
    bool evidence_accepted_for_design;
    bool uncertainty_available;
    bool lower_confidence_bound_available;
    bool contest_open;
    bool supersession_link_present;
    double evidence_sufficiency_score;
};

inline ConsistencyStatus validate(
    const RecommendationConsistencyInput& input
) {
    if (input.recommendation_version < 1) {
        return ConsistencyStatus::InvalidVersion;
    }

    if (input.external_action_authorized) {
        return ConsistencyStatus::InvalidNonActuationBoundary;
    }

    if (!std::isfinite(input.evidence_sufficiency_score)
        || input.evidence_sufficiency_score < 0.0
        || input.evidence_sufficiency_score > 1.0) {
        return ConsistencyStatus::InvalidEvidenceState;
    }

    if (!input.uncertainty_available
        || !input.lower_confidence_bound_available) {
        return ConsistencyStatus::InvalidUncertainty;
    }

    if (input.contest_open && input.evidence_accepted_for_design) {
        return ConsistencyStatus::InvalidContestState;
    }

    if (!input.evidence_accepted_for_design && input.supersession_link_present) {
        return ConsistencyStatus::InvalidEvidenceState;
    }

    return ConsistencyStatus::Valid;
}

inline std::string_view message(ConsistencyStatus status) {
    switch (status) {
        case ConsistencyStatus::Valid:
            return "VALID";
        case ConsistencyStatus::InvalidVersion:
            return "INVALID_RECOMMENDATION_VERSION";
        case ConsistencyStatus::InvalidUncertainty:
            return "INVALID_OR_MISSING_UNCERTAINTY";
        case ConsistencyStatus::InvalidNonActuationBoundary:
            return "EXTERNAL_ACTION_AUTHORIZATION_NOT_ALLOWED";
        case ConsistencyStatus::InvalidEvidenceState:
            return "INVALID_EVIDENCE_OR_SUPERSESSION_STATE";
        case ConsistencyStatus::InvalidContestState:
            return "CONTEST_STATE_CONFLICT";
    }

    throw std::logic_error("unrecognized consistency status");
}

}  // namespace augmented_hub::recommendation_review
