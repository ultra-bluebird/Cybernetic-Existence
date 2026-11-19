#include <iostream>
#include <string>
#include <unordered_set>

namespace cyboquatics {

enum class Route {
    KnownMediaReviewable,
    FogReview,
    RejectedInput
};

enum class Reason {
    Eligible,
    InvalidInput,
    UnknownMedia,
    HazardFlag,
    UncertaintyFlag,
    ConfidenceBelow700,
    CompletenessBelow900,
    KnowledgeBelow700,
    HarmRiskAbove300
};

struct Input {
    std::string mediaClass;
    int confidenceMilli;
    int completenessMilli;
    int knowledgeFactorMilli;
    int harmRiskMilli;
    bool uncertaintyFlag;
    bool hazardFlag;
};

struct Result {
    Route route;
    Reason reason;
};

bool inMilliRange(int value) {
    return value >= 0 && value <= 1000;
}

bool approvedMedia(const std::string& mediaClass) {
    static const std::unordered_set<std::string> approved{
        "AQUEOUS", "SEDIMENT", "BIOREACTOR", "ORGANIC_DEBRIS"
    };
    return approved.contains(mediaClass);
}

Result evaluate(const Input& input) {
    if (!inMilliRange(input.confidenceMilli) ||
        !inMilliRange(input.completenessMilli) ||
        !inMilliRange(input.knowledgeFactorMilli) ||
        !inMilliRange(input.harmRiskMilli)) {
        return {Route::RejectedInput, Reason::InvalidInput};
    }
    if (!approvedMedia(input.mediaClass)) {
        return {Route::RejectedInput, Reason::UnknownMedia};
    }
    if (input.hazardFlag) {
        return {Route::FogReview, Reason::HazardFlag};
    }
    if (input.uncertaintyFlag) {
        return {Route::FogReview, Reason::UncertaintyFlag};
    }
    if (input.confidenceMilli < 700) {
        return {Route::FogReview, Reason::ConfidenceBelow700};
    }
    if (input.completenessMilli < 900) {
        return {Route::FogReview, Reason::CompletenessBelow900};
    }
    if (input.knowledgeFactorMilli < 700) {
        return {Route::FogReview, Reason::KnowledgeBelow700};
    }
    if (input.harmRiskMilli > 300) {
        return {Route::FogReview, Reason::HarmRiskAbove300};
    }
    return {Route::KnownMediaReviewable, Reason::Eligible};
}

std::string toString(Route route) {
    switch (route) {
        case Route::KnownMediaReviewable: return "KNOWN_MEDIA_REVIEWABLE";
        case Route::FogReview: return "FOG_REVIEW";
        case Route::RejectedInput: return "REJECTED_INPUT";
    }
    return "REJECTED_INPUT";
}

std::string toString(Reason reason) {
    switch (reason) {
        case Reason::Eligible: return "ELIGIBLE";
        case Reason::InvalidInput: return "INVALID_INPUT";
        case Reason::UnknownMedia: return "UNKNOWN_MEDIA";
        case Reason::HazardFlag: return "HAZARD_FLAG";
        case Reason::UncertaintyFlag: return "UNCERTAINTY_FLAG";
        case Reason::ConfidenceBelow700: return "CONFIDENCE_BELOW_700";
        case Reason::CompletenessBelow900: return "COMPLETENESS_BELOW_900";
        case Reason::KnowledgeBelow700: return "KNOWLEDGE_BELOW_700";
        case Reason::HarmRiskAbove300: return "HARM_RISK_ABOVE_300";
    }
    return "INVALID_INPUT";
}

}  // namespace cyboquatics

int main() {
    const cyboquatics::Input input{
        "AQUEOUS", 850, 950, 800, 250, false, false
    };
    const auto result = cyboquatics::evaluate(input);
    std::cout << cyboquatics::toString(result.route)
              << "|" << cyboquatics::toString(result.reason) << '\n';
    return 0;
}
