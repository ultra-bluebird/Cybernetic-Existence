#include <cmath>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <set>
#include <string>

enum class Route {
    KNOWN_MEDIA,
    FOG_REVIEW,
    QUARANTINED_INPUT,
    REJECTED_INPUT
};

struct Decision {
    Route route;
    std::string code;
    std::string explanation;
};

struct Observation {
    std::string nodeId;
    std::string observedAt;
    std::string media;
    double confidence;
    double completeness;
    bool fog;
    double flowM3S;
    double temperatureC;
    double measurementQuality;
    double k;
    double e;
    double r;
    bool consentActive;
};

bool finiteInRange(double value, double minimum, double maximum) {
    return std::isfinite(value) && value >= minimum && value <= maximum;
}

bool knownMedia(const std::string& media) {
    static const std::set<std::string> allowed{
        "freshwater", "brackish_water", "wastewater", "stormwater", "sediment"
    };
    return allowed.contains(media);
}

Decision routeObservation(const Observation& value) {
    if (value.nodeId.empty() || value.observedAt.empty()) {
        return {Route::REJECTED_INPUT, "MISSING_REQUIRED_FIELD",
                "A pseudonymous node identifier and observation time are required."};
    }
    if (!value.consentActive) {
        return {Route::REJECTED_INPUT, "CONSENT_NOT_ACTIVE",
                "The purpose-limited consent state is not active; do not process this observation."};
    }
    if (!finiteInRange(value.confidence, 0.0, 1.0) ||
        !finiteInRange(value.completeness, 0.0, 1.0) ||
        !finiteInRange(value.measurementQuality, 0.0, 1.0) ||
        !finiteInRange(value.k, 0.0, 1.0) ||
        !finiteInRange(value.e, 0.0, 1.0) ||
        !finiteInRange(value.r, 0.0, 1.0) ||
        !finiteInRange(value.flowM3S, 0.0, 1000.0) ||
        !finiteInRange(value.temperatureC, -5.0, 60.0)) {
        return {Route::REJECTED_INPUT, "INVALID_BOUNDED_VALUE",
                "One or more measurements are missing, non-finite, or outside the configured local bounds."};
    }
    if (value.fog || !knownMedia(value.media)) {
        return {Route::FOG_REVIEW, "FOG_EXPLICIT",
                "FOG is explicit or the media is unknown; preserve uncertainty and request qualified human review."};
    }
    if (value.completeness < 0.90 || value.confidence < 0.70 || value.measurementQuality < 0.70 || value.k < 0.70) {
        return {Route::FOG_REVIEW, "EVIDENCE_INCOMPLETE",
                "Evidence completeness, confidence, measurement quality, or knowledge quality is insufficient for known-media review."};
    }
    if (value.r > 0.30) {
        return {Route::QUARANTINED_INPUT, "RISK_ABOVE_AUTOMATION_BOUND",
                "Risk of harm exceeds 0.30; quarantine the record for qualified human review and do not automate a recommendation."};
    }
    return {Route::KNOWN_MEDIA, "KNOWN_MEDIA_READY",
            "Known media with complete, authorized evidence is suitable for human review only; no physical action is authorized."};
}

std::string routeName(Route route) {
    switch (route) {
        case Route::KNOWN_MEDIA: return "KNOWN_MEDIA";
        case Route::FOG_REVIEW: return "FOG_REVIEW";
        case Route::QUARANTINED_INPUT: return "QUARANTINED_INPUT";
        case Route::REJECTED_INPUT: return "REJECTED_INPUT";
    }
    return "REJECTED_INPUT";
}

bool parseDouble(const char* text, double& output) {
    char* end = nullptr;
    output = std::strtod(text, &end);
    return end != text && *end == '\0';
}

bool parseBoolean(const std::string& text, bool& output) {
    if (text == "true") {
        output = true;
        return true;
    }
    if (text == "false") {
        output = false;
        return true;
    }
    return false;
}

int main(int argc, char* argv[]) {
    if (argc != 14) {
        std::cerr << "usage: fog_router_cpp node_id observed_at media confidence completeness fog flow_m3_s temperature_c measurement_quality K E R consent_active\n";
        return 2;
    }

    Observation value{};
    value.nodeId = argv[1];
    value.observedAt = argv[2];
    value.media = argv[3];

    if (!parseDouble(argv[4], value.confidence) ||
        !parseDouble(argv[5], value.completeness) ||
        !parseBoolean(argv[6], value.fog) ||
        !parseDouble(argv[7], value.flowM3S) ||
        !parseDouble(argv[8], value.temperatureC) ||
        !parseDouble(argv[9], value.measurementQuality) ||
        !parseDouble(argv[10], value.k) ||
        !parseDouble(argv[11], value.e) ||
        !parseDouble(argv[12], value.r) ||
        !parseBoolean(argv[13], value.consentActive)) {
        std::cerr << "route=REJECTED_INPUT\ncode=PARSE_FAILURE\nexplanation=Input values must use decimal numbers and lowercase true or false booleans.\n";
        return 1;
    }

    const Decision decision = routeObservation(value);
    std::cout << "route=" << routeName(decision.route) << "\n";
    std::cout << "code=" << decision.code << "\n";
    std::cout << "explanation=" << decision.explanation << "\n";
    return decision.route == Route::REJECTED_INPUT ? 1 : 0;
}
