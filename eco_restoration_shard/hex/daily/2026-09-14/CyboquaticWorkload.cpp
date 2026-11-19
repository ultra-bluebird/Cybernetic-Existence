#include <cmath>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <vector>

struct WorkloadInput {
    std::string workloadId;
    std::string canalNodeId;
    std::string taskType;
    double massKg;
    double distanceM;
    double dutySeconds;
    double ratedPowerW;
    double motorEfficiency;
    double baselineVoltageV;
    double internalResistanceOhm;
    double batterySoc;
    double renewableFraction;
    std::string mediaClass;
};

struct WorkloadResult {
    double energyreqJ;
    double estimatedCurrentA;
    double deltaVt;
    bool valid;
    std::string reason;
};

static std::vector<std::string> splitCsv(const std::string& line) {
    std::vector<std::string> values;
    std::stringstream stream(line);
    std::string value;

    while (std::getline(stream, value, ',')) {
        values.push_back(value);
    }

    return values;
}

static bool parseDouble(const std::string& text, double& result) {
    char* end = nullptr;
    const double value = std::strtod(text.c_str(), &end);

    if (end == text.c_str() || *end != '\0' || !std::isfinite(value)) {
        return false;
    }

    result = value;
    return true;
}

static bool isUnitInterval(double value) {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

static bool isKnownTask(const std::string& taskType) {
    return taskType == "debris_skim" ||
           taskType == "sediment_dredge" ||
           taskType == "biofilm_scrub" ||
           taskType == "aerator_drive";
}

static bool isKnownMedia(const std::string& mediaClass) {
    return mediaClass == "known_safe" ||
           mediaClass == "unmodeled_media" ||
           mediaClass == "pfas_suspected" ||
           mediaClass == "hazardous_material" ||
           mediaClass == "unknown";
}

static WorkloadResult evaluate(const WorkloadInput& input) {
    if (!isKnownTask(input.taskType)) {
        return {0.0, 0.0, 0.0, false, "unsupported task_type"};
    }

    if (!isKnownMedia(input.mediaClass)) {
        return {0.0, 0.0, 0.0, false, "unsupported media_class"};
    }

    if (input.massKg <= 0.0 ||
        input.distanceM < 0.0 ||
        input.dutySeconds <= 0.0 ||
        input.ratedPowerW <= 0.0 ||
        input.motorEfficiency <= 0.0 ||
        input.motorEfficiency > 1.0 ||
        input.baselineVoltageV <= 0.0 ||
        input.internalResistanceOhm < 0.0 ||
        !isUnitInterval(input.batterySoc) ||
        !isUnitInterval(input.renewableFraction)) {
        return {0.0, 0.0, 0.0, false, "input violates physical or unit-interval bounds"};
    }

    const double estimatedCurrentA = input.ratedPowerW / input.baselineVoltageV;
    const double deltaVt = estimatedCurrentA * input.internalResistanceOhm;
    const double energyreqJ =
        (input.ratedPowerW * input.dutySeconds) / input.motorEfficiency;

    if (!std::isfinite(estimatedCurrentA) ||
        !std::isfinite(deltaVt) ||
        !std::isfinite(energyreqJ) ||
        energyreqJ <= 0.0 ||
        deltaVt < 0.0) {
        return {0.0, 0.0, 0.0, false, "non-finite or invalid derived value"};
    }

    return {energyreqJ, estimatedCurrentA, deltaVt, true, "valid"};
}

int main() {
    std::string line;
    bool firstLine = true;

    std::cout << "workload_id,canal_node_id,energyreqJ,estimated_current_a,deltaVt,status,reason\n";
    std::cout << std::fixed << std::setprecision(6);

    while (std::getline(std::cin, line)) {
        if (firstLine) {
            firstLine = false;
            continue;
        }

        if (line.empty()) {
            continue;
        }

        const std::vector<std::string> fields = splitCsv(line);

        if (fields.size() != 13) {
            std::cout << ",,0.000000,0.000000,0.000000,rejected,expected 13 CSV columns\n";
            continue;
        }

        WorkloadInput input{};
        input.workloadId = fields[0];
        input.canalNodeId = fields[1];
        input.taskType = fields[2];
        input.mediaClass = fields[12];

        const bool parsed =
            parseDouble(fields[3], input.massKg) &&
            parseDouble(fields[4], input.distanceM) &&
            parseDouble(fields[5], input.dutySeconds) &&
            parseDouble(fields[6], input.ratedPowerW) &&
            parseDouble(fields[7], input.motorEfficiency) &&
            parseDouble(fields[8], input.baselineVoltageV) &&
            parseDouble(fields[9], input.internalResistanceOhm) &&
            parseDouble(fields[10], input.batterySoc) &&
            parseDouble(fields[11], input.renewableFraction);

        if (!parsed) {
            std::cout << input.workloadId << "," << input.canalNodeId
                      << ",0.000000,0.000000,0.000000,rejected,invalid numeric input\n";
            continue;
        }

        const WorkloadResult result = evaluate(input);

        std::cout << input.workloadId << ","
                  << input.canalNodeId << ","
                  << result.energyreqJ << ","
                  << result.estimatedCurrentA << ","
                  << result.deltaVt << ","
                  << (result.valid ? "valid" : "rejected") << ","
                  << result.reason << "\n";
    }

    return 0;
}
