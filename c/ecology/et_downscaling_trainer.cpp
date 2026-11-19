#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <map>
#include <numeric>
#include <optional>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {

constexpr double kMinimumFeatureQuality = 0.70;
constexpr double kMinimumApprovedQuality = 0.90;
constexpr double kMaximumConservationResidualFraction = 0.05;
constexpr double kMinimumPredictionIntervalCoverage = 0.80;
constexpr int kMinimumTrainingRows = 12;
constexpr int kMinimumHeldOutRows = 4;
constexpr int kMaximumTreeDepth = 4;
constexpr int kMinimumLeafSize = 3;
constexpr double kMinimumSplitGain = 1.0e-8;
constexpr double kTiny = 1.0e-12;

enum class ModelStatus {
    Draft,
    Approved,
    Qualified,
    Rejected,
    HoldForReview
};

struct Observation {
    std::string satelliteProductId;
    std::string productVersion;
    std::string coarsePixelId;
    std::string observationTimestampUtc;
    double satelliteEtMmDay;
    std::string satelliteEtUnit;
    std::string satelliteQualityFlag;
    double satelliteUncertaintyMmDay;
    std::string hexId;
    double overlapAreaM2;
    double ndvi;
    std::string ndviQualityFlag;
    std::optional<double> soilMoistureFraction;
    std::optional<double> soilMoistureDepthCm;
    std::string soilMoistureCalibrationStatus;
    double demM;
    std::string optionalCovariateSchema;
    double optionalCovariateValue;
    std::string split;
};

struct TrainingConfig {
    std::string trainTestSplitVersion;
    std::string modelHyperparameterVersion;
    int treeCount;
    double learningRate;
    std::uint64_t randomSeed;
};

struct Stump {
    int featureIndex = 0;
    double threshold = 0.0;
    double leftValue = 0.0;
    double rightValue = 0.0;

    double predict(const std::vector<double>& features) const {
        return features.at(static_cast<std::size_t>(featureIndex)) <= threshold
            ? leftValue
            : rightValue;
    }
};

struct TrainingResult {
    std::string modelArtifactDigest;
    std::string featureSchemaVersion;
    double heldOutRmseMmDay;
    double heldOutBiasMmDay;
    std::string stratumErrorReport;
    double coarseCellConservationResidualFraction;
    double predictionIntervalCoverage;
    ModelStatus modelStatus;
    bool planningOnlyStatus;
    std::string humanReviewStatus;
    std::string explanation;
};

bool isFinite(double value) {
    return std::isfinite(value);
}

void requireNonEmpty(std::string_view value, std::string_view name) {
    if (value.empty()) {
        throw std::invalid_argument(std::string(name) + " must not be empty");
    }
}

void requireRange(
    std::string_view name,
    double value,
    double minimum,
    double maximum
) {
    if (!isFinite(value) || value < minimum || value > maximum) {
        throw std::invalid_argument(
            std::string(name) + " must be finite and within the permitted range"
        );
    }
}

double parseDouble(const std::string& value, std::string_view name) {
    try {
        std::size_t consumed = 0;
        const double parsed = std::stod(value, &consumed);
        if (consumed != value.size() || !isFinite(parsed)) {
            throw std::invalid_argument("invalid number");
        }
        return parsed;
    } catch (const std::exception&) {
        throw std::invalid_argument(std::string(name) + " must be a finite number");
    }
}

int parseInt(const char* value, std::string_view name) {
    try {
        std::size_t consumed = 0;
        const std::string raw(value);
        const int parsed = std::stoi(raw, &consumed);
        if (consumed != raw.size()) {
            throw std::invalid_argument("invalid integer");
        }
        return parsed;
    } catch (const std::exception&) {
        throw std::invalid_argument(std::string(name) + " must be an integer");
    }
}

std::uint64_t parseUnsigned(const char* value, std::string_view name) {
    try {
        std::size_t consumed = 0;
        const std::string raw(value);
        const unsigned long long parsed = std::stoull(raw, &consumed);
        if (consumed != raw.size()) {
            throw std::invalid_argument("invalid integer");
        }
        return static_cast<std::uint64_t>(parsed);
    } catch (const std::exception&) {
        throw std::invalid_argument(std::string(name) + " must be an unsigned integer");
    }
}

std::vector<std::string> splitCsvLine(const std::string& line) {
    std::vector<std::string> fields;
    std::stringstream stream(line);
    std::string field;

    while (std::getline(stream, field, ',')) {
        fields.push_back(field);
    }

    if (!line.empty() && line.back() == ',') {
        fields.emplace_back();
    }

    return fields;
}

std::optional<double> parseOptionalDouble(
    const std::string& value,
    std::string_view name
) {
    if (value.empty() || value == "NA" || value == "null") {
        return std::nullopt;
    }

    return parseDouble(value, name);
}

void validateObservation(const Observation& row) {
    requireNonEmpty(row.satelliteProductId, "satellite_product_id");
    requireNonEmpty(row.productVersion, "product_version");
    requireNonEmpty(row.coarsePixelId, "coarse_pixel_id");
    requireNonEmpty(row.observationTimestampUtc, "observation_timestamp_utc");
    requireNonEmpty(row.satelliteEtUnit, "satellite_et_unit");
    requireNonEmpty(row.satelliteQualityFlag, "satellite_quality_flag");
    requireNonEmpty(row.hexId, "hex_id");
    requireNonEmpty(row.ndviQualityFlag, "ndvi_quality_flag");
    requireNonEmpty(row.soilMoistureCalibrationStatus, "soil_moisture_calibration_status");
    requireNonEmpty(row.optionalCovariateSchema, "optional_covariate_schema");
    requireNonEmpty(row.split, "split");

    if (row.satelliteEtUnit != "mm_day") {
        throw std::invalid_argument("satellite_et_unit must be mm_day");
    }

    if (row.satelliteQualityFlag != "approved") {
        throw std::invalid_argument("satellite_quality_flag must be approved");
    }

    if (row.ndviQualityFlag != "approved") {
        throw std::invalid_argument("ndvi_quality_flag must be approved");
    }

    if (row.soilMoistureCalibrationStatus != "approved") {
        throw std::invalid_argument("soil_moisture_calibration_status must be approved");
    }

    if (row.split != "train" && row.split != "test") {
        throw std::invalid_argument("split must be train or test");
    }

    requireRange("satellite_et_value", row.satelliteEtMmDay, 0.0, 100.0);
    requireRange("satellite_uncertainty", row.satelliteUncertaintyMmDay, 0.0, 100.0);
    requireRange("overlap_area_m2", row.overlapAreaM2, 0.001, 1.0e12);
    requireRange("NDVI", row.ndvi, -1.0, 1.0);
    requireRange("DEM_m", row.demM, -500.0, 10000.0);
    requireRange("optional_covariate_value", row.optionalCovariateValue, -1.0e9, 1.0e9);

    if (!row.soilMoistureFraction.has_value()
        || !row.soilMoistureDepthCm.has_value()) {
        throw std::invalid_argument(
            "soil_moisture and soil_moisture_depth_cm are required for this model"
        );
    }

    requireRange(
        "soil_moisture",
        row.soilMoistureFraction.value(),
        0.0,
        1.0
    );
    requireRange(
        "soil_moisture_depth_cm",
        row.soilMoistureDepthCm.value(),
        0.1,
        500.0
    );
}

std::vector<Observation> loadCsv(const std::string& path) {
    std::ifstream input(path);

    if (!input) {
        throw std::runtime_error("unable to open input CSV");
    }

    std::string header;
    if (!std::getline(input, header)) {
        throw std::invalid_argument("input CSV is empty");
    }

    const std::vector<std::string> expectedHeader = {
        "satellite_product_id",
        "product_version",
        "coarse_pixel_id",
        "observation_timestamp_utc",
        "satellite_et_value",
        "satellite_et_unit",
        "satellite_quality_flag",
        "satellite_uncertainty",
        "hex_id",
        "overlap_area_m2",
        "NDVI",
        "NDVI_quality_flag",
        "soil_moisture",
        "soil_moisture_depth_cm",
        "soil_moisture_calibration_status",
        "DEM_m",
        "optional_covariate_schema",
        "optional_covariate_value",
        "split"
    };

    if (splitCsvLine(header) != expectedHeader) {
        throw std::invalid_argument(
            "input CSV header must exactly match the documented schema"
        );
    }

    std::vector<Observation> observations;
    std::string line;
    std::size_t lineNumber = 1;

    while (std::getline(input, line)) {
        ++lineNumber;

        if (line.empty()) {
            continue;
        }

        const std::vector<std::string> fields = splitCsvLine(line);
        if (fields.size() != expectedHeader.size()) {
            throw std::invalid_argument(
                "line " + std::to_string(lineNumber)
                + " must contain exactly 19 CSV columns"
            );
        }

        Observation row{
            fields[0],
            fields[1],
            fields[2],
            fields[3],
            parseDouble(fields[4], "satellite_et_value"),
            fields[5],
            fields[6],
            parseDouble(fields[7], "satellite_uncertainty"),
            fields[8],
            parseDouble(fields[9], "overlap_area_m2"),
            parseDouble(fields[10], "NDVI"),
            fields[11],
            parseOptionalDouble(fields[12], "soil_moisture"),
            parseOptionalDouble(fields[13], "soil_moisture_depth_cm"),
            fields[14],
            parseDouble(fields[15], "DEM_m"),
            fields[16],
            parseDouble(fields[17], "optional_covariate_value"),
            fields[18]
        };

        validateObservation(row);
        observations.push_back(std::move(row));
    }

    if (observations.empty()) {
        throw std::invalid_argument("input CSV contains no observations");
    }

    return observations;
}

std::vector<double> featuresFor(const Observation& row) {
    return {
        row.satelliteEtMmDay,
        row.ndvi,
        row.soilMoistureFraction.value(),
        row.soilMoistureDepthCm.value(),
        row.demM,
        row.optionalCovariateValue
    };
}

double mean(const std::vector<double>& values) {
    if (values.empty()) {
        throw std::invalid_argument("cannot calculate mean of empty values");
    }

    return std::accumulate(values.begin(), values.end(), 0.0)
        / static_cast<double>(values.size());
}

double sumSquaredError(
    const std::vector<double>& values,
    double reference
) {
    double error = 0.0;
    for (const double value : values) {
        const double residual = value - reference;
        error += residual * residual;
    }
    return error;
}

Stump fitStump(
    const std::vector<std::vector<double>>& features,
    const std::vector<double>& residuals
) {
    if (features.empty() || features.size() != residuals.size()) {
        throw std::invalid_argument("stump fitting inputs are inconsistent");
    }

    Stump best;
    double bestGain = -std::numeric_limits<double>::infinity();

    const double baseline = mean(residuals);
    const double parentSse = sumSquaredError(residuals, baseline);
    const std::size_t featureCount = features.front().size();

    for (std::size_t featureIndex = 0; featureIndex < featureCount; ++featureIndex) {
        std::vector<double> candidateValues;
        candidateValues.reserve(features.size());

        for (const auto& row : features) {
            candidateValues.push_back(row.at(featureIndex));
        }

        std::sort(candidateValues.begin(), candidateValues.end());
        candidateValues.erase(
            std::unique(candidateValues.begin(), candidateValues.end()),
            candidateValues.end()
        );

        for (std::size_t valueIndex = 1; valueIndex < candidateValues.size(); ++valueIndex) {
            const double threshold =
                (candidateValues[valueIndex - 1] + candidateValues[valueIndex]) / 2.0;

            std::vector<double> left;
            std::vector<double> right;

            for (std::size_t rowIndex = 0; rowIndex < features.size(); ++rowIndex) {
                if (features[rowIndex].at(featureIndex) <= threshold) {
                    left.push_back(residuals[rowIndex]);
                } else {
                    right.push_back(residuals[rowIndex]);
                }
            }

            if (left.size() < kMinimumLeafSize || right.size() < kMinimumLeafSize) {
                continue;
            }

            const double leftMean = mean(left);
            const double rightMean = mean(right);
            const double childSse =
                sumSquaredError(left, leftMean)
                + sumSquaredError(right, rightMean);
            const double gain = parentSse - childSse;

            if (gain > bestGain) {
                bestGain = gain;
                best.featureIndex = static_cast<int>(featureIndex);
                best.threshold = threshold;
                best.leftValue = leftMean;
                best.rightValue = rightMean;
            }
        }
    }

    if (bestGain < kMinimumSplitGain) {
        best.featureIndex = 0;
        best.threshold = std::numeric_limits<double>::infinity();
        best.leftValue = baseline;
        best.rightValue = baseline;
    }

    return best;
}

class GradientBoostedRegressor {
public:
    GradientBoostedRegressor(int treeCount, double learningRate)
        : treeCount_(treeCount), learningRate_(learningRate) {
        if (treeCount_ <= 0) {
            throw std::invalid_argument("tree_count must be positive");
        }
        requireRange("learning_rate", learningRate_, 0.0001, 1.0);
    }

    void fit(
        const std::vector<std::vector<double>>& features,
        const std::vector<double>& targets
    ) {
        if (features.size() != targets.size() || features.empty()) {
            throw std::invalid_argument("training features and targets are inconsistent");
        }

        basePrediction_ = mean(targets);
        std::vector<double> predictions(targets.size(), basePrediction_);

        for (int treeIndex = 0; treeIndex < treeCount_; ++treeIndex) {
            std::vector<double> residuals(targets.size());

            for (std::size_t rowIndex = 0; rowIndex < targets.size(); ++rowIndex) {
                residuals[rowIndex] = targets[rowIndex] - predictions[rowIndex];
            }

            const Stump stump = fitStump(features, residuals);
            trees_.push_back(stump);

            for (std::size_t rowIndex = 0; rowIndex < predictions.size(); ++rowIndex) {
                predictions[rowIndex] += learningRate_ * stump.predict(features[rowIndex]);
            }
        }
    }

    double predict(const std::vector<double>& features) const {
        double prediction = basePrediction_;

        for (const Stump& stump : trees_) {
            prediction += learningRate_ * stump.predict(features);
        }

        return std::max(0.0, prediction);
    }

    const std::vector<Stump>& trees() const {
        return trees_;
    }

    double basePrediction() const {
        return basePrediction_;
    }

private:
    int treeCount_;
    double learningRate_;
    double basePrediction_ = 0.0;
    std::vector<Stump> trees_;
};

double safeRelativeResidual(double predicted, double observed) {
    const double denominator = std::max(observed, kTiny);
    return std::abs(predicted - observed) / denominator;
}

std::unordered_map<std::string, double> conservationFactors(
    const std::vector<Observation>& observations,
    const std::vector<double>& rawPredictions
) {
    if (observations.size() != rawPredictions.size()) {
        throw std::invalid_argument("conservation inputs are inconsistent");
    }

    struct Totals {
        double weightedObserved = 0.0;
        double weightedPredicted = 0.0;
        double totalArea = 0.0;
    };

    std::unordered_map<std::string, Totals> totals;

    for (std::size_t index = 0; index < observations.size(); ++index) {
        const Observation& row = observations[index];
        Totals& total = totals[row.coarsePixelId];

        total.weightedObserved += row.overlapAreaM2 * row.satelliteEtMmDay;
        total.weightedPredicted += row.overlapAreaM2 * rawPredictions[index];
        total.totalArea += row.overlapAreaM2;
    }

    std::unordered_map<std::string, double> factors;

    for (const auto& [pixelId, total] : totals) {
        const double observedMean = total.weightedObserved / total.totalArea;
        const double predictedMean = total.weightedPredicted / total.totalArea;

        factors[pixelId] = observedMean / std::max(predictedMean, kTiny);
    }

    return factors;
}

double conservationResidualFraction(
    const std::vector<Observation>& observations,
    const std::vector<double>& conservedPredictions
) {
    struct Totals {
        double weightedObserved = 0.0;
        double weightedPrediction = 0.0;
        double area = 0.0;
    };

    std::unordered_map<std::string, Totals> totals;

    for (std::size_t index = 0; index < observations.size(); ++index) {
        const Observation& row = observations[index];
        Totals& total = totals[row.coarsePixelId];

        total.weightedObserved += row.overlapAreaM2 * row.satelliteEtMmDay;
        total.weightedPrediction += row.overlapAreaM2 * conservedPredictions[index];
        total.area += row.overlapAreaM2;
    }

    double maximumResidual = 0.0;

    for (const auto& [pixelId, total] : totals) {
        const double observedMean = total.weightedObserved / total.area;
        const double predictedMean = total.weightedPrediction / total.area;

        const double residual =
            std::abs(observedMean - predictedMean)
            / std::max(observedMean, kTiny);

        maximumResidual = std::max(maximumResidual, residual);
    }

    return maximumResidual;
}

double rootMeanSquaredError(
    const std::vector<double>& predictions,
    const std::vector<double>& targets
) {
    if (predictions.size() != targets.size() || predictions.empty()) {
        return 0.0;
    }

    double sse = 0.0;

    for (std::size_t index = 0; index < predictions.size(); ++index) {
        const double residual = predictions[index] - targets[index];
        sse += residual * residual;
    }

    return std::sqrt(sse / static_cast<double>(predictions.size()));
}

double bias(
    const std::vector<double>& predictions,
    const std::vector<double>& targets
) {
    if (predictions.size() != targets.size() || predictions.empty()) {
        return 0.0;
    }

    double total = 0.0;

    for (std::size_t index = 0; index < predictions.size(); ++index) {
        total += predictions[index] - targets[index];
    }

    return total / static_cast<double>(predictions.size());
}

std::string makeStratum(
    const Observation& row
) {
    const std::string moisture =
        row.soilMoistureFraction.value() < 0.15
            ? "low_moisture"
            : "higher_moisture";

    const std::string vegetation =
        row.ndvi < 0.20
            ? "low_ndvi"
            : "higher_ndvi";

    return row.optionalCovariateSchema + "|" + moisture + "|" + vegetation;
}

std::string stratumErrorReport(
    const std::vector<Observation>& testRows,
    const std::vector<double>& predictions
) {
    struct Accumulator {
        double absoluteError = 0.0;
        std::size_t count = 0;
    };

    std::map<std::string, Accumulator> groups;

    for (std::size_t index = 0; index < testRows.size(); ++index) {
        const std::string stratum = makeStratum(testRows[index]);
        Accumulator& accumulator = groups[stratum];
        accumulator.absoluteError += std::abs(
            predictions[index] - testRows[index].satelliteEtMmDay
        );
        accumulator.count++;
    }

    std::ostringstream report;
    bool first = true;

    for (const auto& [stratum, accumulator] : groups) {
        if (!first) {
            report << ';';
        }

        const double mae =
            accumulator.absoluteError / static_cast<double>(accumulator.count);

        report
            << stratum
            << ":count="
            << accumulator.count
            << ",mae_mm_day="
            << std::fixed
            << std::setprecision(6)
            << mae;

        first = false;
    }

    return report.str();
}

std::string digestModel(
    const GradientBoostedRegressor& model,
    const TrainingConfig& config,
    const std::string& featureSchemaVersion
) {
    std::uint64_t hash = 1469598103934665603ULL;

    auto mix = [&hash](std::string_view data) {
        for (const unsigned char character : data) {
            hash ^= static_cast<std::uint64_t>(character);
            hash *= 1099511628211ULL;
        }
    };

    auto mixDouble = [&mix](double value) {
        std::ostringstream out;
        out << std::setprecision(17) << value;
        mix(out.str());
    };

    mix(featureSchemaVersion);
    mix(config.trainTestSplitVersion);
    mix(config.modelHyperparameterVersion);
    mixDouble(model.basePrediction());

    for (const Stump& stump : model.trees()) {
        mix(std::to_string(stump.featureIndex));
        mixDouble(stump.threshold);
        mixDouble(stump.leftValue);
        mixDouble(stump.rightValue);
    }

    std::ostringstream output;
    output << "fnv1a64:";
    output << std::hex << std::setw(16) << std::setfill('0') << hash;

    return output.str();
}

TrainingResult train(
    const std::vector<Observation>& observations,
    const TrainingConfig& config
) {
    requireNonEmpty(config.trainTestSplitVersion, "train_test_split_version");
    requireNonEmpty(config.modelHyperparameterVersion, "model_hyperparameter_version");

    std::vector<Observation> trainRows;
    std::vector<Observation> testRows;

    for (const Observation& row : observations) {
        if (row.split == "train") {
            trainRows.push_back(row);
        } else {
            testRows.push_back(row);
        }
    }

    if (static_cast<int>(trainRows.size()) < kMinimumTrainingRows) {
        throw std::invalid_argument("insufficient training rows");
    }

    if (static_cast<int>(testRows.size()) < kMinimumHeldOutRows) {
        throw std::invalid_argument("insufficient held-out test rows");
    }

    std::vector<std::vector<double>> trainFeatures;
    std::vector<double> trainTargets;

    for (const Observation& row : trainRows) {
        trainFeatures.push_back(featuresFor(row));
        trainTargets.push_back(row.satelliteEtMmDay);
    }

    GradientBoostedRegressor model(config.treeCount, config.learningRate);
    model.fit(trainFeatures, trainTargets);

    std::vector<double> testRawPredictions;
    std::vector<double> testTargets;

    for (const Observation& row : testRows) {
        testRawPredictions.push_back(model.predict(featuresFor(row)));
        testTargets.push_back(row.satelliteEtMmDay);
    }

    const auto testFactors = conservationFactors(testRows, testRawPredictions);
    std::vector<double> testConservedPredictions;
    testConservedPredictions.reserve(testRows.size());

    for (std::size_t index = 0; index < testRows.size(); ++index) {
        const double factor = testFactors.at(testRows[index].coarsePixelId);
        testConservedPredictions.push_back(
            std::max(0.0, testRawPredictions[index] * factor)
        );
    }

    const double heldOutRmse = rootMeanSquaredError(
        testConservedPredictions,
        testTargets
    );

    const double heldOutBias = bias(
        testConservedPredictions,
        testTargets
    );

    const double residualStdDev = [&]() {
        double sumSquares = 0.0;

        for (std::size_t index = 0; index < testConservedPredictions.size(); ++index) {
            const double residual = testConservedPredictions[index] - testTargets[index];
            sumSquares += residual * residual;
        }

        return std::sqrt(
            sumSquares
            / static_cast<double>(std::max<std::size_t>(1, testConservedPredictions.size() - 1))
        );
    }();

    std::size_t covered = 0;

    for (std::size_t index = 0; index < testConservedPredictions.size(); ++index) {
        const double lower = std::max(
            0.0,
            testConservedPredictions[index] - 1.96 * residualStdDev
        );
        const double upper = testConservedPredictions[index] + 1.96 * residualStdDev;

        if (testTargets[index] >= lower && testTargets[index] <= upper) {
            covered++;
        }
    }

    const double intervalCoverage =
        static_cast<double>(covered)
        / static_cast<double>(testConservedPredictions.size());

    const double conservationResidual = conservationResidualFraction(
        testRows,
        testConservedPredictions
    );

    const std::string featureSchemaVersion =
        "et_features:v1[satellite_et_mm_day,ndvi,soil_moisture_fraction,"
        "soil_moisture_depth_cm,dem_m,optional_covariate]";

    const std::string artifactDigest = digestModel(
        model,
        config,
        featureSchemaVersion
    );

    const bool conservationPasses =
        conservationResidual <= kMaximumConservationResidualFraction;

    const bool intervalCoveragePasses =
        intervalCoverage >= kMinimumPredictionIntervalCoverage;

    const bool accuracyPasses =
        heldOutRmse <= 2.0
        && std::abs(heldOutBias) <= 1.0;

    const ModelStatus status =
        conservationPasses && intervalCoveragePasses && accuracyPasses
            ? ModelStatus::Qualified
            : ModelStatus::HoldForReview;

    return {
        artifactDigest,
        featureSchemaVersion,
        heldOutRmse,
        heldOutBias,
        stratumErrorReport(testRows, testConservedPredictions),
        conservationResidual,
        intervalCoverage,
        status,
        true,
        "pending",
        status == ModelStatus::Qualified
            ? "qualified planning-only ET downscaling model; human review remains required"
            : "hold_for_review: accuracy, uncertainty coverage, or coarse-cell conservation threshold failed"
    };
}

const char* toString(ModelStatus status) {
    switch (status) {
        case ModelStatus::Draft:
            return "draft";
        case ModelStatus::Approved:
            return "approved";
        case ModelStatus::Qualified:
            return "qualified";
        case ModelStatus::Rejected:
            return "rejected";
        case ModelStatus::HoldForReview:
            return "hold_for_review";
    }

    return "hold_for_review";
}

void printUsage(const char* program) {
    std::cerr
        << "Usage:\n"
        << "  " << program
        << " observations.csv train_test_split_version"
        << " model_hyperparameter_version tree_count learning_rate random_seed\n\n"
        << "Required CSV columns:\n"
        << "  satellite_product_id,product_version,coarse_pixel_id,"
        << "observation_timestamp_utc,satellite_et_value,satellite_et_unit,"
        << "satellite_quality_flag,satellite_uncertainty,hex_id,overlap_area_m2,"
        << "NDVI,NDVI_quality_flag,soil_moisture,soil_moisture_depth_cm,"
        << "soil_moisture_calibration_status,DEM_m,optional_covariate_schema,"
        << "optional_covariate_value,split\n\n"
        << "Constraints:\n"
        << "  satellite_et_unit must be mm_day\n"
        << "  quality flags and soil-moisture calibration status must be approved\n"
        << "  split must be train or test\n"
        << "  this program is planning-only and has no infrastructure-control capability\n";
}

}  // namespace

int main(int argc, char* argv[]) {
    constexpr int kExpectedArgumentCount = 7;

    if (argc != kExpectedArgumentCount) {
        printUsage(argv[0]);
        return 64;
    }

    try {
        const std::vector<Observation> observations = loadCsv(argv[1]);

        const TrainingConfig config{
            argv[2],
            argv[3],
            parseInt(argv[4], "tree_count"),
            parseDouble(argv[5], "learning_rate"),
            parseUnsigned(argv[6], "random_seed")
        };

        if (config.treeCount <= 0 || config.treeCount > 500) {
            throw std::invalid_argument("tree_count must be within 1..500");
        }

        const TrainingResult result = train(observations, config);

        std::cout << std::fixed << std::setprecision(6);
        std::cout << "model_artifact_digest=" << result.modelArtifactDigest << '\n';
        std::cout << "feature_schema_version=" << result.featureSchemaVersion << '\n';
        std::cout << "held_out_rmse_mm_day=" << result.heldOutRmseMmDay << '\n';
        std::cout << "held_out_bias_mm_day=" << result.heldOutBiasMmDay << '\n';
        std::cout << "stratum_error_report=" << result.stratumErrorReport << '\n';
        std::cout << "coarse_cell_conservation_residual_fraction="
                  << result.coarseCellConservationResidualFraction << '\n';
        std::cout << "prediction_interval_coverage="
                  << result.predictionIntervalCoverage << '\n';
        std::cout << "model_status=" << toString(result.modelStatus) << '\n';
        std::cout << "planning_only_status="
                  << (result.planningOnlyStatus ? "true" : "false") << '\n';
        std::cout << "human_review_status=" << result.humanReviewStatus << '\n';
        std::cout << "explanation=" << result.explanation << '\n';
        std::cout << "accesses_water_control_systems=false\n";
        std::cout << "schedules_irrigation=false\n";
        std::cout << "operates_pumps=false\n";
        std::cout << "infers_property_compliance=false\n";
        std::cout << "publishes_exact_sensitive_locations=false\n";

        return result.modelStatus == ModelStatus::Qualified ? 0 : 2;
    } catch (const std::exception& error) {
        std::cerr << "Input error: " << error.what() << '\n';
        return 65;
    }
}
