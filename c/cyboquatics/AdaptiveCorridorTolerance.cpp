#include <algorithm>
#include <cmath>
#include <iostream>
#include <string>
#include <vector>

namespace cyboquatics {

enum class Decision {
    ToleranceAvailable,
    CalibrationReviewRequired,
    RejectedInput
};

struct Input {
    double baseTolerance;
    double temperatureCoefficient;
    double currentTemperatureC;
    double referenceTemperatureC;
    double minimumTolerance;
    double maximumTolerance;
    double sensorQuality;
    double minimumSensorQuality;
    double sensorOperatingMinimumC;
    double sensorOperatingMaximumC;
    bool calibrationCurrent;
};

struct Result {
    Decision decision;
    double adaptiveTolerance;
    std::vector<std::string> reasons;
};

bool finite(double value) {
    return std::isfinite(value);
}

bool unitInterval(double value) {
    return finite(value) && value >= 0.0 && value <= 1.0;
}

Result evaluate(const Input& input) {
    if (!finite(input.baseTolerance) ||
        !finite(input.temperatureCoefficient) ||
        !finite(input.currentTemperatureC) ||
        !finite(input.referenceTemperatureC) ||
        !finite(input.minimumTolerance) ||
        !finite(input.maximumTolerance) ||
        !unitInterval(input.sensorQuality) ||
        !unitInterval(input.minimumSensorQuality) ||
        !finite(input.sensorOperatingMinimumC) ||
        !finite(input.sensorOperatingMaximumC) ||
        input.baseTolerance < 0.0 ||
        input.temperatureCoefficient < 0.0 ||
        input.minimumTolerance < 0.0 ||
        input.maximumTolerance < input.minimumTolerance ||
        input.sensorOperatingMaximumC < input.sensorOperatingMinimumC) {
        return {Decision::RejectedInput, 0.0, {"Tolerance or sensor bounds are invalid."}};
    }

    const double rawTolerance = input.baseTolerance +
        input.temperatureCoefficient *
        std::abs(input.currentTemperatureC - input.referenceTemperatureC);
    const double adaptiveTolerance = std::clamp(
        rawTolerance,
        input.minimumTolerance,
        input.maximumTolerance
    );

    std::vector<std::string> reasons;
    if (!input.calibrationCurrent) {
        reasons.emplace_back("Sensor calibration is absent or expired.");
    }
    if (input.sensorQuality < input.minimumSensorQuality) {
        reasons.emplace_back("Sensor quality is below the configured minimum.");
    }
    if (input.currentTemperatureC < input.sensorOperatingMinimumC ||
        input.currentTemperatureC > input.sensorOperatingMaximumC) {
        reasons.emplace_back("Temperature is outside the documented sensor operating range.");
    }

    if (!reasons.empty()) {
        return {Decision::CalibrationReviewRequired, adaptiveTolerance, reasons};
    }

    return {
        Decision::ToleranceAvailable,
        adaptiveTolerance,
        {"Adaptive tolerance is bounded and does not change hard safety limits."}
    };
}

std::string toString(Decision decision) {
    switch (decision) {
        case Decision::ToleranceAvailable: return "TOLERANCE_AVAILABLE";
        case Decision::CalibrationReviewRequired: return "CALIBRATION_REVIEW_REQUIRED";
        case Decision::RejectedInput: return "REJECTED_INPUT";
    }
    return "REJECTED_INPUT";
}

}  // namespace cyboquatics

int main() {
    const cyboquatics::Input input{
        0.50, 0.03, 42.0, 25.0, 0.50, 1.20, 0.92, 0.80, -10.0, 60.0, true
    };
    const auto result = cyboquatics::evaluate(input);
    std::cout << cyboquatics::toString(result.decision)
              << " tolerance=" << result.adaptiveTolerance << '\n';
    return 0;
}
