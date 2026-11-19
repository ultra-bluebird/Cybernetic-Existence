#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
#include <queue>
#include <random>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace {

constexpr double kMinimumDataQuality = 0.90;
constexpr double kMinimumAccessibleIntakeCoverage = 0.90;
constexpr double kMinutesPerHour = 60.0;
constexpr double kSecondsPerHour = 3600.0;
constexpr double kDefaultEmergencyRoutineFloor = 0.00;
constexpr double kMaximumUtilizationForPlanning = 0.90;
constexpr double kMaximumRoutineStarvationRisk = 0.10;

enum class RequestClass {
    Urgent,
    Routine
};

enum class ScenarioStatus {
    QualifiedForPlanning,
    HoldForReview
};

struct ExponentialServiceDistribution {
    double meanMinutes;
};

struct StaffingSegment {
    double startMinute;
    double endMinute;
    int staffCount;
};

struct Input {
    std::string serviceNodeId;
    double simulationWindowMinutes;
    double urgentArrivalRatePerHour;
    double routineArrivalRatePerHour;
    ExponentialServiceDistribution urgentService;
    ExponentialServiceDistribution routineService;
    std::vector<StaffingSegment> staffingSchedule;
    bool urgentInterruptsRoutine;
    bool routineInterruptionSafe;
    double routineServiceFloorFraction;
    double urgentWaitTargetMinutes;
    double routineWaitTargetMinutes;
    std::string emergencyProtocolStatus;
    double accessibilityIntakeCoverage;
    double dataQuality;
    std::string modelVersion;
    std::uint64_t randomSeed;
};

struct Request {
    RequestClass requestClass;
    double arrivalMinute;
    double remainingServiceMinutes;
    std::uint64_t sequence;
};

struct Server {
    bool busy = false;
    Request current{RequestClass::Routine, 0.0, 0.0, 0};
    double completionMinute = std::numeric_limits<double>::infinity();
};

struct Metrics {
    double urgentMeanWaitMinutes = 0.0;
    double urgentP95WaitMinutes = 0.0;
    double routineMeanWaitMinutes = 0.0;
    double routineP95WaitMinutes = 0.0;
    double urgentUtilization = 0.0;
    double routineUtilization = 0.0;
    double totalUtilization = 0.0;
    double routineStarvationRisk = 0.0;
    bool capacityEscalationRequired = false;
    double accessibleIntakeCoverage = 0.0;
    ScenarioStatus scenarioStatus = ScenarioStatus::HoldForReview;
    std::string humanReviewStatus;
    std::string explanation;
};

bool finite(double value) {
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
    if (!finite(value) || value < minimum || value > maximum) {
        throw std::invalid_argument(
            std::string(name) + " must be finite and within the allowed range"
        );
    }
}

double parseDouble(const char* value, std::string_view name) {
    try {
        std::size_t consumed = 0;
        const std::string raw(value);
        const double parsed = std::stod(raw, &consumed);
        if (consumed != raw.size() || !finite(parsed)) {
            throw std::invalid_argument("invalid number");
        }
        return parsed;
    } catch (const std::exception&) {
        throw std::invalid_argument(std::string(name) + " must be a finite number");
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

bool parseBoolean(const char* value, std::string_view name) {
    const std::string raw(value);
    if (raw == "true") {
        return true;
    }
    if (raw == "false") {
        return false;
    }
    throw std::invalid_argument(std::string(name) + " must be true or false");
}

std::vector<StaffingSegment> parseStaffingSchedule(const char* value) {
    const std::string raw(value);
    if (raw.empty()) {
        throw std::invalid_argument("staffing_schedule must not be empty");
    }

    std::vector<StaffingSegment> segments;
    std::size_t start = 0;

    while (start < raw.size()) {
        const std::size_t end = raw.find(';', start);
        const std::string segmentText = raw.substr(
            start,
            end == std::string::npos ? std::string::npos : end - start
        );

        const std::size_t colon = segmentText.find(':');
        const std::size_t dash = segmentText.find('-');

        if (colon == std::string::npos || dash == std::string::npos || dash > colon) {
            throw std::invalid_argument(
                "staffing_schedule items must use start-end:staff format"
            );
        }

        const std::string startText = segmentText.substr(0, dash);
        const std::string endText = segmentText.substr(dash + 1, colon - dash - 1);
        const std::string staffText = segmentText.substr(colon + 1);

        if (startText.empty() || endText.empty() || staffText.empty()) {
            throw std::invalid_argument("staffing_schedule contains an incomplete segment");
        }

        std::size_t consumed = 0;
        const double startMinute = std::stod(startText, &consumed);
        if (consumed != startText.size()) {
            throw std::invalid_argument("staffing_schedule start is invalid");
        }

        consumed = 0;
        const double endMinute = std::stod(endText, &consumed);
        if (consumed != endText.size()) {
            throw std::invalid_argument("staffing_schedule end is invalid");
        }

        consumed = 0;
        const int staffCount = std::stoi(staffText, &consumed);
        if (consumed != staffText.size()) {
            throw std::invalid_argument("staffing_schedule staff count is invalid");
        }

        requireRange("staffing_schedule start", startMinute, 0.0, 525600.0);
        requireRange("staffing_schedule end", endMinute, 0.0, 525600.0);

        if (endMinute <= startMinute || staffCount < 0) {
            throw std::invalid_argument(
                "staffing_schedule requires end > start and non-negative staff count"
            );
        }

        segments.push_back({startMinute, endMinute, staffCount});

        if (end == std::string::npos) {
            break;
        }

        start = end + 1;
    }

    std::sort(
        segments.begin(),
        segments.end(),
        [](const StaffingSegment& left, const StaffingSegment& right) {
            return left.startMinute < right.startMinute;
        }
    );

    for (std::size_t index = 1; index < segments.size(); ++index) {
        if (segments[index].startMinute < segments[index - 1].endMinute) {
            throw std::invalid_argument("staffing_schedule segments must not overlap");
        }
    }

    return segments;
}

int activeStaffAt(const std::vector<StaffingSegment>& schedule, double minute) {
    for (const StaffingSegment& segment : schedule) {
        if (minute >= segment.startMinute && minute < segment.endMinute) {
            return segment.staffCount;
        }
    }
    return 0;
}

double nextStaffingBoundary(
    const std::vector<StaffingSegment>& schedule,
    double minute,
    double simulationWindowMinutes
) {
    double boundary = simulationWindowMinutes;

    for (const StaffingSegment& segment : schedule) {
        if (segment.startMinute > minute) {
            boundary = std::min(boundary, segment.startMinute);
        }
        if (segment.endMinute > minute) {
            boundary = std::min(boundary, segment.endMinute);
        }
    }

    return boundary;
}

double exponentialInterarrivalMinutes(
    std::mt19937_64& generator,
    double arrivalRatePerHour
) {
    if (arrivalRatePerHour <= 0.0) {
        return std::numeric_limits<double>::infinity();
    }

    std::exponential_distribution<double> distribution(arrivalRatePerHour / kMinutesPerHour);
    return distribution(generator);
}

double exponentialServiceMinutes(
    std::mt19937_64& generator,
    const ExponentialServiceDistribution& distribution
) {
    std::exponential_distribution<double> exponential(1.0 / distribution.meanMinutes);
    return exponential(generator);
}

double percentile(std::vector<double> values, double probability) {
    if (values.empty()) {
        return 0.0;
    }

    std::sort(values.begin(), values.end());

    const double position = probability * static_cast<double>(values.size() - 1);
    const std::size_t lowerIndex = static_cast<std::size_t>(std::floor(position));
    const std::size_t upperIndex = static_cast<std::size_t>(std::ceil(position));
    const double weight = position - static_cast<double>(lowerIndex);

    return values[lowerIndex] * (1.0 - weight) + values[upperIndex] * weight;
}

double arithmeticMean(const std::vector<double>& values) {
    if (values.empty()) {
        return 0.0;
    }

    double total = 0.0;
    for (const double value : values) {
        total += value;
    }

    return total / static_cast<double>(values.size());
}

double totalStaffMinutes(
    const std::vector<StaffingSegment>& schedule,
    double simulationWindowMinutes
) {
    double total = 0.0;

    for (const StaffingSegment& segment : schedule) {
        const double clippedStart = std::max(0.0, segment.startMinute);
        const double clippedEnd = std::min(simulationWindowMinutes, segment.endMinute);

        if (clippedEnd > clippedStart) {
            total += (clippedEnd - clippedStart) * static_cast<double>(segment.staffCount);
        }
    }

    return total;
}

void addRequestToQueue(
    const Request& request,
    std::deque<Request>& urgentQueue,
    std::deque<Request>& routineQueue
) {
    if (request.requestClass == RequestClass::Urgent) {
        urgentQueue.push_back(request);
    } else {
        routineQueue.push_back(request);
    }
}

bool canReserveRoutineService(
    const Input& input,
    std::size_t urgentQueueSize,
    int activeStaff
) {
    if (activeStaff <= 0) {
        return false;
    }

    if (input.emergencyProtocolStatus == "temporary_heat_emergency") {
        return false;
    }

    const int protectedRoutineServers = static_cast<int>(
        std::ceil(
            input.routineServiceFloorFraction * static_cast<double>(activeStaff)
        )
    );

    return protectedRoutineServers > 0
        && urgentQueueSize < static_cast<std::size_t>(
            std::max(0, activeStaff - protectedRoutineServers)
        );
}

void dispatchQueuedWork(
    const Input& input,
    double currentMinute,
    std::vector<Server>& servers,
    std::deque<Request>& urgentQueue,
    std::deque<Request>& routineQueue,
    std::vector<double>& urgentWaits,
    std::vector<double>& routineWaits
) {
    const int activeStaff = activeStaffAt(input.staffingSchedule, currentMinute);

    for (std::size_t serverIndex = 0; serverIndex < servers.size(); ++serverIndex) {
        Server& server = servers[serverIndex];

        if (static_cast<int>(serverIndex) >= activeStaff || server.busy) {
            continue;
        }

        Request nextRequest{RequestClass::Routine, 0.0, 0.0, 0};
        bool hasRequest = false;

        const bool preserveRoutineFloor = canReserveRoutineService(
            input,
            urgentQueue.size(),
            activeStaff
        );

        if (!urgentQueue.empty() && !preserveRoutineFloor) {
            nextRequest = urgentQueue.front();
            urgentQueue.pop_front();
            hasRequest = true;
        } else if (!routineQueue.empty()) {
            nextRequest = routineQueue.front();
            routineQueue.pop_front();
            hasRequest = true;
        } else if (!urgentQueue.empty()) {
            nextRequest = urgentQueue.front();
            urgentQueue.pop_front();
            hasRequest = true;
        }

        if (!hasRequest) {
            continue;
        }

        const double wait = std::max(0.0, currentMinute - nextRequest.arrivalMinute);

        if (nextRequest.requestClass == RequestClass::Urgent) {
            urgentWaits.push_back(wait);
        } else {
            routineWaits.push_back(wait);
        }

        server.busy = true;
        server.current = nextRequest;
        server.completionMinute = currentMinute + nextRequest.remainingServiceMinutes;
    }
}

void preemptRoutineWorkForUrgentRequest(
    const Input& input,
    double currentMinute,
    std::vector<Server>& servers,
    std::deque<Request>& urgentQueue,
    std::deque<Request>& routineQueue
) {
    if (!input.urgentInterruptsRoutine || !input.routineInterruptionSafe || urgentQueue.empty()) {
        return;
    }

    const int activeStaff = activeStaffAt(input.staffingSchedule, currentMinute);

    for (std::size_t serverIndex = 0; serverIndex < servers.size(); ++serverIndex) {
        Server& server = servers[serverIndex];

        if (static_cast<int>(serverIndex) >= activeStaff
            || !server.busy
            || server.current.requestClass != RequestClass::Routine
            || urgentQueue.empty()) {
            continue;
        }

        const double remaining = std::max(0.0, server.completionMinute - currentMinute);

        if (remaining <= 0.0) {
            continue;
        }

        Request resumed = server.current;
        resumed.remainingServiceMinutes = remaining;
        resumed.arrivalMinute = currentMinute;
        routineQueue.push_front(resumed);

        server.busy = false;
        server.completionMinute = std::numeric_limits<double>::infinity();
    }
}

Metrics simulate(const Input& input) {
    requireNonEmpty(input.serviceNodeId, "service_node_id");
    requireNonEmpty(input.emergencyProtocolStatus, "emergency_protocol_status");
    requireNonEmpty(input.modelVersion, "model_version");

    requireRange(
        "simulation_window_minutes",
        input.simulationWindowMinutes,
        1.0,
        525600.0
    );
    requireRange(
        "urgent_arrival_rate_per_hour",
        input.urgentArrivalRatePerHour,
        0.0,
        100000.0
    );
    requireRange(
        "routine_arrival_rate_per_hour",
        input.routineArrivalRatePerHour,
        0.0,
        100000.0
    );
    requireRange(
        "urgent_service_mean_minutes",
        input.urgentService.meanMinutes,
        0.01,
        100000.0
    );
    requireRange(
        "routine_service_mean_minutes",
        input.routineService.meanMinutes,
        0.01,
        100000.0
    );
    requireRange(
        "routine_service_floor_fraction",
        input.routineServiceFloorFraction,
        0.0,
        1.0
    );
    requireRange(
        "urgent_wait_target_minutes",
        input.urgentWaitTargetMinutes,
        0.01,
        100000.0
    );
    requireRange(
        "routine_wait_target_minutes",
        input.routineWaitTargetMinutes,
        0.01,
        100000.0
    );
    requireRange(
        "accessibility_intake_coverage",
        input.accessibilityIntakeCoverage,
        0.0,
        1.0
    );
    requireRange("data_quality", input.dataQuality, 0.0, 1.0);

    if (input.emergencyProtocolStatus != "normal"
        && input.emergencyProtocolStatus != "temporary_heat_emergency"
        && input.emergencyProtocolStatus != "restricted") {
        throw std::invalid_argument(
            "emergency_protocol_status must be normal, temporary_heat_emergency, or restricted"
        );
    }

    const double urgentUtilization =
        input.urgentArrivalRatePerHour
        * input.urgentService.meanMinutes
        / kMinutesPerHour;

    const double routineUtilization =
        input.routineArrivalRatePerHour
        * input.routineService.meanMinutes
        / kMinutesPerHour;

    const double totalWorkMinutes =
        (
            input.urgentArrivalRatePerHour * input.urgentService.meanMinutes
            + input.routineArrivalRatePerHour * input.routineService.meanMinutes
        )
        * input.simulationWindowMinutes / kMinutesPerHour;

    const double availableStaffMinutes = totalStaffMinutes(
        input.staffingSchedule,
        input.simulationWindowMinutes
    );

    const double totalUtilization =
        availableStaffMinutes > 0.0
            ? totalWorkMinutes / availableStaffMinutes
            : 1.0;

    if (input.dataQuality < kMinimumDataQuality
        || input.accessibilityIntakeCoverage < kMinimumAccessibleIntakeCoverage
        || availableStaffMinutes <= 0.0) {
        return {
            0.0,
            0.0,
            0.0,
            0.0,
            urgentUtilization,
            routineUtilization,
            totalUtilization,
            1.0,
            true,
            input.accessibilityIntakeCoverage,
            ScenarioStatus::HoldForReview,
            "pending",
            "hold_for_review: insufficient data quality, accessible intake coverage, or staffing"
        };
    }

    int maxStaff = 0;
    for (const StaffingSegment& segment : input.staffingSchedule) {
        maxStaff = std::max(maxStaff, segment.staffCount);
    }

    if (maxStaff == 0) {
        return {
            0.0,
            0.0,
            0.0,
            0.0,
            urgentUtilization,
            routineUtilization,
            1.0,
            1.0,
            true,
            input.accessibilityIntakeCoverage,
            ScenarioStatus::HoldForReview,
            "pending",
            "hold_for_review: no active staff are scheduled"
        };
    }

    std::mt19937_64 generator(input.randomSeed);
    std::vector<Server> servers(static_cast<std::size_t>(maxStaff));
    std::deque<Request> urgentQueue;
    std::deque<Request> routineQueue;
    std::vector<double> urgentWaits;
    std::vector<double> routineWaits;

    double currentMinute = 0.0;
    double nextUrgentArrival = exponentialInterarrivalMinutes(
        generator,
        input.urgentArrivalRatePerHour
    );
    double nextRoutineArrival = exponentialInterarrivalMinutes(
        generator,
        input.routineArrivalRatePerHour
    );

    std::uint64_t requestSequence = 0;
    std::size_t routineRequestsOverTarget = 0;
    std::size_t totalRoutineRequests = 0;

    while (currentMinute < input.simulationWindowMinutes) {
        double nextCompletion = std::numeric_limits<double>::infinity();

        for (const Server& server : servers) {
            nextCompletion = std::min(nextCompletion, server.completionMinute);
        }

        const double staffingBoundary = nextStaffingBoundary(
            input.staffingSchedule,
            currentMinute,
            input.simulationWindowMinutes
        );

        const double nextEvent = std::min(
            {
                nextUrgentArrival,
                nextRoutineArrival,
                nextCompletion,
                staffingBoundary,
                input.simulationWindowMinutes
            }
        );

        if (!finite(nextEvent) || nextEvent < currentMinute) {
            break;
        }

        currentMinute = nextEvent;

        for (Server& server : servers) {
            if (server.busy && server.completionMinute <= currentMinute) {
                server.busy = false;
                server.completionMinute = std::numeric_limits<double>::infinity();
            }
        }

        const int activeStaff = activeStaffAt(input.staffingSchedule, currentMinute);

        for (std::size_t serverIndex = 0; serverIndex < servers.size(); ++serverIndex) {
            Server& server = servers[serverIndex];

            if (static_cast<int>(serverIndex) >= activeStaff && server.busy) {
                Request paused = server.current;
                paused.remainingServiceMinutes = std::max(
                    0.0,
                    server.completionMinute - currentMinute
                );
                paused.arrivalMinute = currentMinute;

                if (paused.requestClass == RequestClass::Routine
                    && input.routineInterruptionSafe) {
                    routineQueue.push_front(paused);
                } else if (paused.requestClass == RequestClass::Urgent) {
                    urgentQueue.push_front(paused);
                } else {
                    routineQueue.push_front(paused);
                }

                server.busy = false;
                server.completionMinute = std::numeric_limits<double>::infinity();
            }
        }

        while (nextUrgentArrival <= currentMinute
            && nextUrgentArrival < input.simulationWindowMinutes) {
            urgentQueue.push_back(
                {
                    RequestClass::Urgent,
                    nextUrgentArrival,
                    exponentialServiceMinutes(generator, input.urgentService),
                    requestSequence++
                }
            );

            nextUrgentArrival += exponentialInterarrivalMinutes(
                generator,
                input.urgentArrivalRatePerHour
            );
        }

        while (nextRoutineArrival <= currentMinute
            && nextRoutineArrival < input.simulationWindowMinutes) {
            routineQueue.push_back(
                {
                    RequestClass::Routine,
                    nextRoutineArrival,
                    exponentialServiceMinutes(generator, input.routineService),
                    requestSequence++
                }
            );

            totalRoutineRequests++;

            nextRoutineArrival += exponentialInterarrivalMinutes(
                generator,
                input.routineArrivalRatePerHour
            );
        }

        preemptRoutineWorkForUrgentRequest(
            input,
            currentMinute,
            servers,
            urgentQueue,
            routineQueue
        );

        const std::size_t routineWaitCountBefore = routineWaits.size();

        dispatchQueuedWork(
            input,
            currentMinute,
            servers,
            urgentQueue,
            routineQueue,
            urgentWaits,
            routineWaits
        );

        for (std::size_t index = routineWaitCountBefore; index < routineWaits.size(); ++index) {
            if (routineWaits[index] > input.routineWaitTargetMinutes) {
                routineRequestsOverTarget++;
            }
        }

        if (currentMinute >= input.simulationWindowMinutes) {
            break;
        }
    }

    const double urgentMeanWait = arithmeticMean(urgentWaits);
    const double urgentP95Wait = percentile(urgentWaits, 0.95);
    const double routineMeanWait = arithmeticMean(routineWaits);
    const double routineP95Wait = percentile(routineWaits, 0.95);

    const std::size_t unresolvedRoutine =
        routineQueue.size()
        + static_cast<std::size_t>(
            std::count_if(
                servers.begin(),
                servers.end(),
                [](const Server& server) {
                    return server.busy
                        && server.current.requestClass == RequestClass::Routine;
                }
            )
        );

    const double routineStarvationRisk =
        totalRoutineRequests > 0
            ? clamp(
                (
                    static_cast<double>(routineRequestsOverTarget)
                    + static_cast<double>(unresolvedRoutine)
                )
                / static_cast<double>(totalRoutineRequests),
                0.0,
                1.0
            )
            : 0.0;

    const bool escalationRequired =
        totalUtilization > kMaximumUtilizationForPlanning
        || urgentP95Wait > input.urgentWaitTargetMinutes
        || routineP95Wait > input.routineWaitTargetMinutes
        || routineStarvationRisk > kMaximumRoutineStarvationRisk
        || input.emergencyProtocolStatus == "restricted";

    const ScenarioStatus scenarioStatus =
        escalationRequired
            ? ScenarioStatus::HoldForReview
            : ScenarioStatus::QualifiedForPlanning;

    return {
        urgentMeanWait,
        urgentP95Wait,
        routineMeanWait,
        routineP95Wait,
        urgentUtilization,
        routineUtilization,
        totalUtilization,
        routineStarvationRisk,
        escalationRequired,
        input.accessibilityIntakeCoverage,
        scenarioStatus,
        "pending",
        escalationRequired
            ? "capacity escalation or queue-policy review required"
            : "planning simulation completed; human review required before operational use"
    };
}

const char* toString(ScenarioStatus status) {
    switch (status) {
        case ScenarioStatus::QualifiedForPlanning:
            return "qualified_for_planning";
        case ScenarioStatus::HoldForReview:
            return "hold_for_review";
    }

    return "hold_for_review";
}

void printUsage(const char* program) {
    std::cerr
        << "Usage:\n"
        << "  " << program
        << " service_node_id simulation_window_minutes"
        << " urgent_arrival_rate_per_hour routine_arrival_rate_per_hour"
        << " urgent_service_mean_minutes routine_service_mean_minutes"
        << " staffing_schedule urgent_interrupts_routine"
        << " routine_interruption_safe routine_service_floor_fraction"
        << " urgent_wait_target_minutes routine_wait_target_minutes"
        << " emergency_protocol_status accessibility_intake_coverage"
        << " data_quality model_version random_seed\n\n"
        << "staffing_schedule format: start-end:staff;start-end:staff\n"
        << "Example:\n"
        << "  " << program
        << " civic-node-01 480 1.0 4.0 15 20"
        << " 0-240:2;240-480:3 true true 0.20"
        << " 20 90 normal 0.95 0.95 v1 42\n";
}

}  // namespace

int main(int argc, char* argv[]) {
    constexpr int kExpectedArgumentCount = 18;

    if (argc != kExpectedArgumentCount) {
        printUsage(argv[0]);
        return 64;
    }

    try {
        const Input input{
            argv[1],
            parseDouble(argv[2], "simulation_window_minutes"),
            parseDouble(argv[3], "urgent_arrival_rate_per_hour"),
            parseDouble(argv[4], "routine_arrival_rate_per_hour"),
            {parseDouble(argv[5], "urgent_service_mean_minutes")},
            {parseDouble(argv[6], "routine_service_mean_minutes")},
            parseStaffingSchedule(argv[7]),
            parseBoolean(argv[8], "urgent_interrupts_routine"),
            parseBoolean(argv[9], "routine_interruption_safe"),
            parseDouble(argv[10], "routine_service_floor_fraction"),
            parseDouble(argv[11], "urgent_wait_target_minutes"),
            parseDouble(argv[12], "routine_wait_target_minutes"),
            argv[13],
            parseDouble(argv[14], "accessibility_intake_coverage"),
            parseDouble(argv[15], "data_quality"),
            argv[16],
            parseUnsigned(argv[17], "random_seed")
        };

        const Metrics result = simulate(input);

        std::cout << std::fixed << std::setprecision(6);
        std::cout << "service_node_id=" << input.serviceNodeId << '\n';
        std::cout << "model_version=" << input.modelVersion << '\n';
        std::cout << "urgent_mean_wait_minutes=" << result.urgentMeanWaitMinutes << '\n';
        std::cout << "urgent_p95_wait_minutes=" << result.urgentP95WaitMinutes << '\n';
        std::cout << "routine_mean_wait_minutes=" << result.routineMeanWaitMinutes << '\n';
        std::cout << "routine_p95_wait_minutes=" << result.routineP95WaitMinutes << '\n';
        std::cout << "utilization_urgent=" << result.urgentUtilization << '\n';
        std::cout << "utilization_routine=" << result.routineUtilization << '\n';
        std::cout << "total_utilization=" << result.totalUtilization << '\n';
        std::cout << "routine_starvation_risk=" << result.routineStarvationRisk << '\n';
        std::cout << "capacity_escalation_required="
                  << (result.capacityEscalationRequired ? "true" : "false") << '\n';
        std::cout << "accessible_intake_coverage="
                  << result.accessibleIntakeCoverage << '\n';
        std::cout << "scenario_status=" << toString(result.scenarioStatus) << '\n';
        std::cout << "human_review_status=" << result.humanReviewStatus << '\n';
        std::cout << "explanation=" << result.explanation << '\n';
        std::cout << "refuses_requests=false\n";
        std::cout << "issues_medical_advice=false\n";
        std::cout << "removes_people_from_public_space=false\n";
        std::cout << "makes_eligibility_decisions=false\n";

        return result.scenarioStatus == ScenarioStatus::QualifiedForPlanning ? 0 : 2;
    } catch (const std::exception& error) {
        std::cerr << "Input error: " << error.what() << '\n';
        return 65;
    }
}
