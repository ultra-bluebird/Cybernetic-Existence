#include <cmath>
#include <iostream>
#include <string>
#include <vector>

namespace cyboquatics {

enum class PfasDecision {
    PfasWithinScreeningCorridor,
    PfasReviewRequired,
    RejectedInput
};

struct PfasObservation {
    double observedConcentration;
    double modeledConcentration;
    double uncertainty;
    double harmRiskR;
    bool chainOfCustodyComplete;
    bool analyticalMethodDeclared;
    bool calibrationCurrent;
};

struct PfasResult {
    PfasDecision decision;
    double residual;
    std::vector<std::string> reasons;
};

bool finite(double value) {
    return std::isfinite(value);
}

bool unitInterval(double value) {
    return finite(value) && value >= 0.0 && value <= 1.0;
}

PfasResult evaluate(const PfasObservation& observation) {
    if (!finite(observation.observedConcentration) ||
        !finite(observation.modeledConcentration) ||
        !finite(observation.uncertainty) ||
        !unitInterval(observation.harmRiskR) ||
        observation.uncertainty <= 0.0) {
        return {
            PfasDecision::RejectedInput,
            0.0,
            {"Concentration, uncertainty, and harm risk must be finite; uncertainty must be positive."}
        };
    }

    const double residual =
        std::abs(observation.observedConcentration - observation.modeledConcentration) /
        observation.uncertainty;

    std::vector<std::string> reasons;
    if (residual > 1.0) {
        reasons.emplace_back("Normalized residual exceeds 1.0.");
    }
    if (observation.harmRiskR > 0.30) {
        reasons.emplace_back("Harm risk exceeds 0.30.");
    }
    if (!observation.chainOfCustodyComplete) {
        reasons.emplace_back("Chain-of-custody evidence is incomplete.");
    }
    if (!observation.analyticalMethodDeclared) {
        reasons.emplace_back("Analytical method is not declared.");
    }
    if (!observation.calibrationCurrent) {
        reasons.emplace_back("Calibration evidence is absent or stale.");
    }

    if (!reasons.empty()) {
        return {PfasDecision::PfasReviewRequired, residual, reasons};
    }

    return {
        PfasDecision::PfasWithinScreeningCorridor,
        residual,
        {"Observation is within the configured screening corridor; this is not a safety or fate conclusion."}
    };
}

std::string toString(PfasDecision decision) {
    switch (decision) {
        case PfasDecision::PfasWithinScreeningCorridor:
            return "PFAS_WITHIN_SCREENING_CORRIDOR";
        case PfasDecision::PfasReviewRequired:
            return "PFAS_REVIEW_REQUIRED";
        case PfasDecision::RejectedInput:
            return "REJECTED_INPUT";
    }
    return "REJECTED_INPUT";
}

}  // namespace cyboquatics

int main() {
    const cyboquatics::PfasObservation sample{
        12.0, 10.5, 2.0, 0.22, true, true, true
    };

    const auto result = cyboquatics::evaluate(sample);
    std::cout << cyboquatics::toString(result.decision)
              << " residual=" << result.residual << '\n';

    return 0;
}
