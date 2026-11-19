#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>

namespace augmented_hub::ecological_accounting {

constexpr double kEpsilon = 1e-12;

enum class Verdict {
    ResearchOnly,
    HoldForReview,
    ConservativeNetBenefit
};

struct ScopeInput {
    double device_energy_kwh{};
    double network_energy_kwh{};
    double compute_energy_kwh{};
    double maintenance_energy_kwh{};
    double grid_carbon_g_per_kwh{};
    double renewable_fraction{};
    double embodied_carbon_g{};
    double end_of_life_carbon_g{};
};

struct BenefitInput {
    double avoided_emissions_estimate_g{};
    double avoided_emissions_standard_uncertainty_g{};
    double footprint_standard_uncertainty_g{};
    double coverage_factor{};
    bool baseline_documented{};
    bool intervention_documented{};
    bool attribution_documented{};
    bool double_counting_reviewed{};
};

struct EvidenceInput {
    double metering_confidence{};
    double lifecycle_confidence{};
    double benefit_confidence{};
    bool calibration_current{};
    bool retention_policy_defined{};
    bool no_personal_data_collected{};
    bool human_review_available{};
};

struct LedgerResult {
    double operational_energy_kwh{};
    double attributable_operational_carbon_g{};
    double full_footprint_g{};
    double avoided_emissions_lower_g{};
    double footprint_upper_g{};
    double conservative_net_benefit_g{};
    double eco_efficiency_ratio{};
    double knowledge_factor{};
    double eco_impact_value{};
    double harm_risk{};
    double accessibility_impact{};
    double rights_alignment{};
    Verdict verdict{};
    std::string reason;
};

double clamp01(double value) {
    return std::clamp(value, 0.0, 1.0);
}

void requireFiniteNonNegative(double value, std::string_view name) {
    if (!std::isfinite(value) || value < 0.0) {
        throw std::invalid_argument(std::string(name) + " must be finite and non-negative");
    }
}

void validateScope(const ScopeInput& input) {
    requireFiniteNonNegative(input.device_energy_kwh, "device_energy_kwh");
    requireFiniteNonNegative(input.network_energy_kwh, "network_energy_kwh");
    requireFiniteNonNegative(input.compute_energy_kwh, "compute_energy_kwh");
    requireFiniteNonNegative(input.maintenance_energy_kwh, "maintenance_energy_kwh");
    requireFiniteNonNegative(input.grid_carbon_g_per_kwh, "grid_carbon_g_per_kwh");
    requireFiniteNonNegative(input.embodied_carbon_g, "embodied_carbon_g");
    requireFiniteNonNegative(input.end_of_life_carbon_g, "end_of_life_carbon_g");

    if (!std::isfinite(input.renewable_fraction) ||
        input.renewable_fraction < 0.0 ||
        input.renewable_fraction > 1.0) {
        throw std::invalid_argument("renewable_fraction must be within [0, 1]");
    }
}

void validateBenefit(const BenefitInput& input) {
    requireFiniteNonNegative(input.avoided_emissions_estimate_g, "avoided_emissions_estimate_g");
    requireFiniteNonNegative(
        input.avoided_emissions_standard_uncertainty_g,
        "avoided_emissions_standard_uncertainty_g"
    );
    requireFiniteNonNegative(
        input.footprint_standard_uncertainty_g,
        "footprint_standard_uncertainty_g"
    );

    if (!std::isfinite(input.coverage_factor) ||
        input.coverage_factor < 1.0 ||
        input.coverage_factor > 10.0) {
        throw std::invalid_argument("coverage_factor must be within [1, 10]");
    }
}

void validateEvidence(const EvidenceInput& input) {
    for (const auto [value, name] : {
        std::pair{input.metering_confidence, "metering_confidence"},
        std::pair{input.lifecycle_confidence, "lifecycle_confidence"},
        std::pair{input.benefit_confidence, "benefit_confidence"}
    }) {
        if (!std::isfinite(value) || value < 0.0 || value > 1.0) {
            throw std::invalid_argument(std::string(name) + " must be within [0, 1]");
        }
    }
}

double weightedGeometricMean(double a, double b, double c) {
    constexpr double weightA = 0.40;
    constexpr double weightB = 0.30;
    constexpr double weightC = 0.30;

    const double safeA = std::max(a, kEpsilon);
    const double safeB = std::max(b, kEpsilon);
    const double safeC = std::max(c, kEpsilon);

    return std::exp(
        weightA * std::log(safeA) +
        weightB * std::log(safeB) +
        weightC * std::log(safeC)
    );
}

LedgerResult evaluate(
    const ScopeInput& scope,
    const BenefitInput& benefit,
    const EvidenceInput& evidence
) {
    validateScope(scope);
    validateBenefit(benefit);
    validateEvidence(evidence);

    const double operationalEnergyKwh =
        scope.device_energy_kwh +
        scope.network_energy_kwh +
        scope.compute_energy_kwh +
        scope.maintenance_energy_kwh;

    const double gridFraction = 1.0 - scope.renewable_fraction;

    const double operationalCarbonG =
        operationalEnergyKwh *
        gridFraction *
        scope.grid_carbon_g_per_kwh;

    const double fullFootprintG =
        operationalCarbonG +
        scope.embodied_carbon_g +
        scope.end_of_life_carbon_g;

    const double avoidedLowerG = std::max(
        0.0,
        benefit.avoided_emissions_estimate_g -
            benefit.coverage_factor * benefit.avoided_emissions_standard_uncertainty_g
    );

    const double footprintUpperG =
        fullFootprintG +
        benefit.coverage_factor * benefit.footprint_standard_uncertainty_g;

    const double conservativeNetBenefitG =
        avoidedLowerG - footprintUpperG;

    const double ecoEfficiencyRatio =
        avoidedLowerG / std::max(footprintUpperG, kEpsilon);

    const double knowledgeFactor = weightedGeometricMean(
        evidence.metering_confidence,
        evidence.lifecycle_confidence,
        evidence.benefit_confidence
    );

    const bool accountingEvidenceComplete =
        benefit.baseline_documented &&
        benefit.intervention_documented &&
        benefit.attribution_documented &&
        benefit.double_counting_reviewed;

    const bool rightsEvidenceComplete =
        evidence.calibration_current &&
        evidence.retention_policy_defined &&
        evidence.no_personal_data_collected &&
        evidence.human_review_available;

    const double evidenceCompleteness =
        (
            static_cast<double>(benefit.baseline_documented) +
            static_cast<double>(benefit.intervention_documented) +
            static_cast<double>(benefit.attribution_documented) +
            static_cast<double>(benefit.double_counting_reviewed) +
            static_cast<double>(evidence.calibration_current) +
            static_cast<double>(evidence.retention_policy_defined) +
            static_cast<double>(evidence.no_personal_data_collected) +
            static_cast<double>(evidence.human_review_available)
        ) / 8.0;

    const double ecologicalSignal = clamp01(
        conservativeNetBenefitG /
        std::max(avoidedLowerG + footprintUpperG, kEpsilon)
    );

    const double ecoImpactValue = clamp01(
        knowledgeFactor *
        ecologicalSignal *
        evidenceCompleteness
    );

    const double harmRisk = clamp01(
        1.0 -
        (
            0.45 * knowledgeFactor +
            0.30 * evidenceCompleteness +
            0.25 * clamp01(ecoEfficiencyRatio)
        )
    );

    const double accessibilityImpact =
        evidence.human_review_available ? 0.90 : 0.45;

    const double rightsAlignment = clamp01(
        0.35 * static_cast<double>(evidence.no_personal_data_collected) +
        0.25 * static_cast<double>(evidence.retention_policy_defined) +
        0.20 * static_cast<double>(evidence.human_review_available) +
        0.20 * static_cast<double>(evidence.calibration_current)
    );

    if (!accountingEvidenceComplete) {
        return {
            operationalEnergyKwh,
            operationalCarbonG,
            fullFootprintG,
            avoidedLowerG,
            footprintUpperG,
            conservativeNetBenefitG,
            ecoEfficiencyRatio,
            knowledgeFactor,
            ecoImpactValue,
            harmRisk,
            accessibilityImpact,
            rightsAlignment,
            Verdict::ResearchOnly,
            "Research-only: baseline, intervention, attribution, or double-counting evidence is incomplete."
        };
    }

    if (!rightsEvidenceComplete) {
        return {
            operationalEnergyKwh,
            operationalCarbonG,
            fullFootprintG,
            avoidedLowerG,
            footprintUpperG,
            conservativeNetBenefitG,
            ecoEfficiencyRatio,
            knowledgeFactor,
            ecoImpactValue,
            harmRisk,
            accessibilityImpact,
            rightsAlignment,
            Verdict::HoldForReview,
            "Hold for review: calibration, retention, privacy, or accountable-review evidence is incomplete."
        };
    }

    if (conservativeNetBenefitG <= 0.0) {
        return {
            operationalEnergyKwh,
            operationalCarbonG,
            fullFootprintG,
            avoidedLowerG,
            footprintUpperG,
            conservativeNetBenefitG,
            ecoEfficiencyRatio,
            knowledgeFactor,
            ecoImpactValue,
            harmRisk,
            accessibilityImpact,
            rightsAlignment,
            Verdict::HoldForReview,
            "Hold for review: conservative avoided-emissions lower bound does not exceed full footprint upper bound."
        };
    }

    return {
        operationalEnergyKwh,
        operationalCarbonG,
        fullFootprintG,
        avoidedLowerG,
        footprintUpperG,
        conservativeNetBenefitG,
        ecoEfficiencyRatio,
        knowledgeFactor,
        ecoImpactValue,
        harmRisk,
        accessibilityImpact,
        rightsAlignment,
        Verdict::ConservativeNetBenefit,
        "Conservative net ecological benefit is supported for the declared accounting boundary and evidence interval."
    };
}

std::string_view verdictName(Verdict verdict) {
    switch (verdict) {
        case Verdict::ResearchOnly:
            return "RESEARCH_ONLY";
        case Verdict::HoldForReview:
            return "HOLD_FOR_REVIEW";
        case Verdict::ConservativeNetBenefit:
            return "CONSERVATIVE_NET_BENEFIT";
    }

    return "HOLD_FOR_REVIEW";
}

void printResult(const LedgerResult& result) {
    std::cout << std::fixed << std::setprecision(6)
              << "{"
              << "\"verdict\":\"" << verdictName(result.verdict) << "\","
              << "\"reason\":\"" << result.reason << "\","
              << "\"operational_energy_kwh\":" << result.operational_energy_kwh << ","
              << "\"attributable_operational_carbon_g\":" << result.attributable_operational_carbon_g << ","
              << "\"full_footprint_g\":" << result.full_footprint_g << ","
              << "\"avoided_emissions_lower_g\":" << result.avoided_emissions_lower_g << ","
              << "\"footprint_upper_g\":" << result.footprint_upper_g << ","
              << "\"conservative_net_benefit_g\":" << result.conservative_net_benefit_g << ","
              << "\"eco_efficiency_ratio\":" << result.eco_efficiency_ratio << ","
              << "\"knowledge_factor\":" << result.knowledge_factor << ","
              << "\"eco_impact_value\":" << result.eco_impact_value << ","
              << "\"harm_risk\":" << result.harm_risk << ","
              << "\"accessibility_impact\":" << result.accessibility_impact << ","
              << "\"rights_alignment\":" << result.rights_alignment
              << "}\n";
}

}  // namespace augmented_hub::ecological_accounting

int main() {
    using namespace augmented_hub::ecological_accounting;

    try {
        const ScopeInput scope{
            .device_energy_kwh = 18.40,
            .network_energy_kwh = 4.20,
            .compute_energy_kwh = 8.10,
            .maintenance_energy_kwh = 2.30,
            .grid_carbon_g_per_kwh = 380.00,
            .renewable_fraction = 0.68,
            .embodied_carbon_g = 3200.00,
            .end_of_life_carbon_g = 360.00
        };

        const BenefitInput benefit{
            .avoided_emissions_estimate_g = 26000.00,
            .avoided_emissions_standard_uncertainty_g = 1800.00,
            .footprint_standard_uncertainty_g = 450.00,
            .coverage_factor = 2.0,
            .baseline_documented = true,
            .intervention_documented = true,
            .attribution_documented = true,
            .double_counting_reviewed = true
        };

        const EvidenceInput evidence{
            .metering_confidence = 0.94,
            .lifecycle_confidence = 0.82,
            .benefit_confidence = 0.79,
            .calibration_current = true,
            .retention_policy_defined = true,
            .no_personal_data_collected = true,
            .human_review_available = true
        };

        printResult(evaluate(scope, benefit, evidence));
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "{\"verdict\":\"HOLD_FOR_REVIEW\",\"error\":\""
                  << error.what()
                  << "\"}\n";
        return 1;
    }
}
