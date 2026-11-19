#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <limits>
#include <map>
#include <optional>
#include <queue>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace {

enum class ArcKind {
    Pre,
    Post
};

enum class AnalysisStatus {
    CompleteWithinBound,
    Truncated,
    InvalidInput,
    HoldForReview
};

enum class InvariantStatus {
    Valid,
    Invalid,
    Qualified,
    NotProvided
};

struct Place {
    std::string id;
    std::string type;
    std::string subsystem;
    bool interfacePlace;
};

struct Transition {
    std::string id;
    std::string type;
    std::string subsystem;
    bool requiresHumanApproval;
    bool physicalActuationAuthority;
};

struct Arc {
    std::string placeId;
    std::string transitionId;
    ArcKind kind;
    int weight;
};

struct TargetPredicate {
    std::string placeId;
    int minimumTokens;
    int maximumTokens;
};

struct Invariant {
    std::string invariantId;
    std::vector<long long> coefficients;
    long long expectedValue;
};

struct NetModel {
    std::string netVersion;
    std::string policyVersion;
    std::string subsystemInterfaceSchema;
    std::string modelReviewStatus;
    int boundedTokenLimit;
    std::vector<Place> places;
    std::vector<Transition> transitions;
    std::vector<Arc> arcs;
    std::vector<int> initialMarking;
    std::vector<TargetPredicate> targetPredicates;
    std::vector<Invariant> invariants;
};

struct AnalysisResult {
    AnalysisStatus boundedReachabilityStatus;
    bool targetStateReachable;
    std::vector<std::string> deadlockCandidateStates;
    InvariantStatus invariantValidationStatus;
    bool unsafeMarkingDetected;
    std::string interfaceContractStatus;
    std::string stateSpaceBoundStatus;
    bool planningOnlyStatus;
    bool humanReviewRequired;
    std::size_t visitedStateCount;
    std::size_t exploredTransitionCount;
    std::string limitationNotice;
};

bool isNonEmpty(std::string_view value) {
    return !value.empty();
}

void requireNonEmpty(std::string_view value, std::string_view name) {
    if (!isNonEmpty(value)) {
        throw std::invalid_argument(std::string(name) + " must not be empty");
    }
}

int parseInt(const std::string& raw, std::string_view name) {
    try {
        std::size_t consumed = 0;
        const int value = std::stoi(raw, &consumed);
        if (consumed != raw.size()) {
            throw std::invalid_argument("invalid integer");
        }
        return value;
    } catch (const std::exception&) {
        throw std::invalid_argument(std::string(name) + " must be an integer");
    }
}

bool parseBoolean(const std::string& raw, std::string_view name) {
    if (raw == "true") {
        return true;
    }
    if (raw == "false") {
        return false;
    }
    throw std::invalid_argument(std::string(name) + " must be true or false");
}

std::vector<std::string> split(const std::string& line, char delimiter) {
    std::vector<std::string> values;
    std::stringstream stream(line);
    std::string value;

    while (std::getline(stream, value, delimiter)) {
        values.push_back(value);
    }

    if (!line.empty() && line.back() == delimiter) {
        values.emplace_back();
    }

    return values;
}

std::vector<long long> parseCoefficientVector(
    const std::string& raw,
    std::size_t expectedSize
) {
    const std::vector<std::string> fields = split(raw, ';');

    if (fields.size() != expectedSize) {
        throw std::invalid_argument(
            "invariant coefficient vector size must equal place count"
        );
    }

    std::vector<long long> values;
    values.reserve(fields.size());

    for (const std::string& field : fields) {
        try {
            std::size_t consumed = 0;
            const long long value = std::stoll(field, &consumed);
            if (consumed != field.size()) {
                throw std::invalid_argument("invalid invariant coefficient");
            }
            values.push_back(value);
        } catch (const std::exception&) {
            throw std::invalid_argument("invariant coefficient must be an integer");
        }
    }

    return values;
}

const char* toString(AnalysisStatus status) {
    switch (status) {
        case AnalysisStatus::CompleteWithinBound:
            return "complete_within_bound";
        case AnalysisStatus::Truncated:
            return "truncated";
        case AnalysisStatus::InvalidInput:
            return "invalid_input";
        case AnalysisStatus::HoldForReview:
            return "hold_for_review";
    }

    return "hold_for_review";
}

const char* toString(InvariantStatus status) {
    switch (status) {
        case InvariantStatus::Valid:
            return "valid";
        case InvariantStatus::Invalid:
            return "invalid";
        case InvariantStatus::Qualified:
            return "qualified";
        case InvariantStatus::NotProvided:
            return "not_provided";
    }

    return "qualified";
}

class PetriNetAnalyzer {
public:
    explicit PetriNetAnalyzer(NetModel model)
        : model_(std::move(model)) {
        validateModel();
        buildIndexes();
    }

    AnalysisResult analyze(std::size_t maximumStates) const {
        if (maximumStates == 0) {
            throw std::invalid_argument("maximumStates must be positive");
        }

        const InvariantStatus invariantStatus = validateInvariants();
        const bool interfaceContractsValid = validateInterfaceContracts();

        if (model_.modelReviewStatus != "approved"
            && model_.modelReviewStatus != "qualified") {
            return {
                AnalysisStatus::HoldForReview,
                false,
                {},
                invariantStatus,
                false,
                "hold_for_review: model review status is not approved or qualified",
                "not_started",
                true,
                true,
                0,
                0,
                "No reachability claim is made because the model is not reviewed."
            };
        }

        if (!interfaceContractsValid) {
            return {
                AnalysisStatus::HoldForReview,
                false,
                {},
                invariantStatus,
                true,
                "invalid_interface_contract",
                "not_started",
                true,
                true,
                0,
                0,
                "No reachability claim is made because subsystem interface contracts are invalid."
            };
        }

        if (invariantStatus == InvariantStatus::Invalid) {
            return {
                AnalysisStatus::HoldForReview,
                false,
                {},
                invariantStatus,
                true,
                "invariant_validation_failed",
                "not_started",
                true,
                true,
                0,
                0,
                "No reachability claim is made because a supplied invariant fails at the initial marking."
            };
        }

        std::queue<std::vector<int>> frontier;
        std::unordered_set<std::string> visited;
        std::vector<std::string> deadlocks;
        std::size_t exploredTransitions = 0;
        bool unsafeMarkingDetected = false;
        bool targetReachable = false;
        bool truncated = false;

        frontier.push(model_.initialMarking);
        visited.insert(serializeMarking(model_.initialMarking));

        while (!frontier.empty()) {
            if (visited.size() >= maximumStates) {
                truncated = true;
                break;
            }

            std::vector<int> marking = frontier.front();
            frontier.pop();

            if (matchesTarget(marking)) {
                targetReachable = true;
            }

            if (isUnsafeMarking(marking)) {
                unsafeMarkingDetected = true;
            }

            const std::vector<std::size_t> enabled = enabledTransitions(marking);

            if (enabled.empty()) {
                deadlocks.push_back(serializeMarking(marking));
            }

            for (const std::size_t transitionIndex : enabled) {
                ++exploredTransitions;

                const std::vector<int> next = fire(marking, transitionIndex);

                if (exceedsTokenBound(next)) {
                    truncated = true;
                    continue;
                }

                const std::string key = serializeMarking(next);

                if (visited.insert(key).second) {
                    if (visited.size() >= maximumStates) {
                        truncated = true;
                        break;
                    }

                    frontier.push(next);
                }
            }
        }

        const AnalysisStatus status =
            truncated
                ? AnalysisStatus::Truncated
                : AnalysisStatus::CompleteWithinBound;

        return {
            status,
            targetReachable,
            deadlocks,
            invariantStatus,
            unsafeMarkingDetected,
            "valid_typed_interfaces",
            truncated ? "truncated" : "complete_within_bound",
            true,
            true,
            visited.size(),
            exploredTransitions,
            truncated
                ? "State-space exploration reached a configured bound or token bound. "
                    "Results are bounded and do not establish exhaustive reachability."
                : "Analysis completed only for the supplied abstract net and configured token bounds. "
                    "Results do not establish real-world safety, authority, or ecological outcomes."
        };
    }

private:
    NetModel model_;
    std::unordered_map<std::string, std::size_t> placeIndex_;
    std::unordered_map<std::string, std::size_t> transitionIndex_;
    std::vector<std::vector<std::pair<std::size_t, int>>> preArcs_;
    std::vector<std::vector<std::pair<std::size_t, int>>> postArcs_;

    void validateModel() const {
        requireNonEmpty(model_.netVersion, "net_version");
        requireNonEmpty(model_.policyVersion, "policy_version");
        requireNonEmpty(model_.subsystemInterfaceSchema, "subsystem_interface_schema");
        requireNonEmpty(model_.modelReviewStatus, "model_review_status");

        if (model_.boundedTokenLimit <= 0) {
            throw std::invalid_argument("bounded_token_limit must be positive");
        }

        if (model_.places.empty()) {
            throw std::invalid_argument("at least one place is required");
        }

        if (model_.transitions.empty()) {
            throw std::invalid_argument("at least one transition is required");
        }

        if (model_.initialMarking.size() != model_.places.size()) {
            throw std::invalid_argument(
                "initial marking vector size must equal place count"
            );
        }

        for (const int tokens : model_.initialMarking) {
            if (tokens < 0 || tokens > model_.boundedTokenLimit) {
                throw std::invalid_argument(
                    "initial marking must be non-negative and within bounded token limit"
                );
            }
        }

        for (const Transition& transition : model_.transitions) {
            requireNonEmpty(transition.id, "transition_id");
            requireNonEmpty(transition.type, "transition_type");
            requireNonEmpty(transition.subsystem, "transition subsystem");

            if (transition.physicalActuationAuthority) {
                throw std::invalid_argument(
                    "physical actuation authority is prohibited in this analyzer"
                );
            }
        }

        for (const Place& place : model_.places) {
            requireNonEmpty(place.id, "place_id");
            requireNonEmpty(place.type, "place_type");
            requireNonEmpty(place.subsystem, "place subsystem");

            if (place.type == "sensitive_personal_data") {
                throw std::invalid_argument(
                    "sensitive personal data places are prohibited"
                );
            }
        }

        for (const Arc& arc : model_.arcs) {
            if (arc.weight <= 0) {
                throw std::invalid_argument("arc weight must be positive");
            }
        }
    }

    void buildIndexes() {
        for (std::size_t index = 0; index < model_.places.size(); ++index) {
            const auto [iterator, inserted] =
                placeIndex_.emplace(model_.places[index].id, index);

            if (!inserted) {
                throw std::invalid_argument(
                    "place_id must be unique: " + model_.places[index].id
                );
            }
        }

        for (std::size_t index = 0; index < model_.transitions.size(); ++index) {
            const auto [iterator, inserted] =
                transitionIndex_.emplace(model_.transitions[index].id, index);

            if (!inserted) {
                throw std::invalid_argument(
                    "transition_id must be unique: " + model_.transitions[index].id
                );
            }
        }

        preArcs_.resize(model_.transitions.size());
        postArcs_.resize(model_.transitions.size());

        for (const Arc& arc : model_.arcs) {
            const auto placeIterator = placeIndex_.find(arc.placeId);
            const auto transitionIterator = transitionIndex_.find(arc.transitionId);

            if (placeIterator == placeIndex_.end()) {
                throw std::invalid_argument(
                    "arc references unknown place_id: " + arc.placeId
                );
            }

            if (transitionIterator == transitionIndex_.end()) {
                throw std::invalid_argument(
                    "arc references unknown transition_id: " + arc.transitionId
                );
            }

            const std::size_t place = placeIterator->second;
            const std::size_t transition = transitionIterator->second;

            if (arc.kind == ArcKind::Pre) {
                preArcs_[transition].push_back({place, arc.weight});
            } else {
                postArcs_[transition].push_back({place, arc.weight});
            }
        }

        for (const TargetPredicate& predicate : model_.targetPredicates) {
            if (placeIndex_.find(predicate.placeId) == placeIndex_.end()) {
                throw std::invalid_argument(
                    "target predicate references unknown place_id: " + predicate.placeId
                );
            }

            if (predicate.minimumTokens < 0
                || predicate.maximumTokens < predicate.minimumTokens
                || predicate.maximumTokens > model_.boundedTokenLimit) {
                throw std::invalid_argument(
                    "target predicate token bounds are invalid"
                );
            }
        }

        for (const Invariant& invariant : model_.invariants) {
            requireNonEmpty(invariant.invariantId, "invariant_id");

            if (invariant.coefficients.size() != model_.places.size()) {
                throw std::invalid_argument(
                    "invariant coefficient vector size must equal place count"
                );
            }
        }
    }

    bool validateInterfaceContracts() const {
        for (const Place& place : model_.places) {
            if (place.interfacePlace
                && place.subsystem != "interface") {
                return false;
            }
        }

        for (const Transition& transition : model_.transitions) {
            if (transition.subsystem == "interface"
                && !transition.requiresHumanApproval) {
                return false;
            }
        }

        return true;
    }

    InvariantStatus validateInvariants() const {
        if (model_.invariants.empty()) {
            return InvariantStatus::NotProvided;
        }

        bool hasQualifiedInvariant = false;

        for (const Invariant& invariant : model_.invariants) {
            long long actual = 0;

            for (std::size_t index = 0; index < invariant.coefficients.size(); ++index) {
                actual += invariant.coefficients[index]
                    * static_cast<long long>(model_.initialMarking[index]);
            }

            if (actual != invariant.expectedValue) {
                return InvariantStatus::Invalid;
            }

            hasQualifiedInvariant = true;
        }

        return hasQualifiedInvariant
            ? InvariantStatus::Valid
            : InvariantStatus::Qualified;
    }

    std::vector<std::size_t> enabledTransitions(
        const std::vector<int>& marking
    ) const {
        std::vector<std::size_t> enabled;

        for (std::size_t transition = 0; transition < model_.transitions.size(); ++transition) {
            bool isEnabled = true;

            for (const auto& [place, weight] : preArcs_[transition]) {
                if (marking[place] < weight) {
                    isEnabled = false;
                    break;
                }
            }

            if (isEnabled) {
                enabled.push_back(transition);
            }
        }

        return enabled;
    }

    std::vector<int> fire(
        const std::vector<int>& marking,
        std::size_t transition
    ) const {
        std::vector<int> next = marking;

        for (const auto& [place, weight] : preArcs_[transition]) {
            next[place] -= weight;
        }

        for (const auto& [place, weight] : postArcs_[transition]) {
            if (next[place] > std::numeric_limits<int>::max() - weight) {
                throw std::overflow_error("token count overflow");
            }

            next[place] += weight;
        }

        return next;
    }

    bool exceedsTokenBound(const std::vector<int>& marking) const {
        for (const int tokens : marking) {
            if (tokens < 0 || tokens > model_.boundedTokenLimit) {
                return true;
            }
        }

        return false;
    }

    bool matchesTarget(const std::vector<int>& marking) const {
        if (model_.targetPredicates.empty()) {
            return false;
        }

        for (const TargetPredicate& predicate : model_.targetPredicates) {
            const std::size_t place = placeIndex_.at(predicate.placeId);
            const int tokens = marking[place];

            if (tokens < predicate.minimumTokens || tokens > predicate.maximumTokens) {
                return false;
            }
        }

        return true;
    }

    bool isUnsafeMarking(const std::vector<int>& marking) const {
        for (std::size_t index = 0; index < model_.places.size(); ++index) {
            const Place& place = model_.places[index];

            if (place.type == "unsafe_actuation"
                || place.type == "privacy_violation"
                || place.type == "essential_service_unavailable") {
                if (marking[index] > 0) {
                    return true;
                }
            }
        }

        return false;
    }

    static std::string serializeMarking(const std::vector<int>& marking) {
        std::ostringstream output;

        for (std::size_t index = 0; index < marking.size(); ++index) {
            if (index > 0) {
                output << ',';
            }
            output << marking[index];
        }

        return output.str();
    }
};

ArcKind parseArcKind(const std::string& raw) {
    if (raw == "pre") {
        return ArcKind::Pre;
    }
    if (raw == "post") {
        return ArcKind::Post;
    }

    throw std::invalid_argument("arc kind must be pre or post");
}

NetModel loadModel(
    const std::string& modelPath,
    int boundedTokenLimit,
    const std::string& policyVersion,
    const std::string& modelReviewStatus
) {
    std::ifstream input(modelPath);

    if (!input) {
        throw std::runtime_error("unable to open Petri-net model file");
    }

    NetModel model;
    model.boundedTokenLimit = boundedTokenLimit;
    model.policyVersion = policyVersion;
    model.modelReviewStatus = modelReviewStatus;

    std::string line;
    std::size_t lineNumber = 0;
    std::vector<std::string> placeOrder;

    while (std::getline(input, line)) {
        ++lineNumber;

        if (line.empty() || line.front() == '#') {
            continue;
        }

        const std::vector<std::string> fields = split(line, '|');

        if (fields.empty()) {
            continue;
        }

        const std::string& recordType = fields[0];

        if (recordType == "net") {
            if (fields.size() != 3) {
                throw std::invalid_argument(
                    "line " + std::to_string(lineNumber)
                    + ": net record requires net|net_version|subsystem_interface_schema"
                );
            }

            model.netVersion = fields[1];
            model.subsystemInterfaceSchema = fields[2];
            continue;
        }

        if (recordType == "place") {
            if (fields.size() != 5) {
                throw std::invalid_argument(
                    "line " + std::to_string(lineNumber)
                    + ": place record requires place|place_id|place_type|subsystem|interface_bool"
                );
            }

            model.places.push_back(
                {
                    fields[1],
                    fields[2],
                    fields[3],
                    parseBoolean(fields[4], "place interface_bool")
                }
            );
            placeOrder.push_back(fields[1]);
            continue;
        }

        if (recordType == "transition") {
            if (fields.size() != 6) {
                throw std::invalid_argument(
                    "line " + std::to_string(lineNumber)
                    + ": transition record requires transition|transition_id|transition_type|subsystem|human_approval_bool|physical_actuation_bool"
                );
            }

            model.transitions.push_back(
                {
                    fields[1],
                    fields[2],
                    fields[3],
                    parseBoolean(fields[4], "transition human_approval_bool"),
                    parseBoolean(fields[5], "transition physical_actuation_bool")
                }
            );
            continue;
        }

        if (recordType == "arc") {
            if (fields.size() != 5) {
                throw std::invalid_argument(
                    "line " + std::to_string(lineNumber)
                    + ": arc record requires arc|place_id|transition_id|pre_or_post|weight"
                );
            }

            model.arcs.push_back(
                {
                    fields[1],
                    fields[2],
                    parseArcKind(fields[3]),
                    parseInt(fields[4], "arc weight")
                }
            );
            continue;
        }

        if (recordType == "marking") {
            if (fields.size() != 3) {
                throw std::invalid_argument(
                    "line " + std::to_string(lineNumber)
                    + ": marking record requires marking|place_id|token_count"
                );
            }

            if (model.initialMarking.empty()) {
                model.initialMarking.assign(model.places.size(), 0);
            }

            const auto iterator = std::find(placeOrder.begin(), placeOrder.end(), fields[1]);

            if (iterator == placeOrder.end()) {
                throw std::invalid_argument(
                    "line " + std::to_string(lineNumber)
                    + ": marking references a place declared after marking or unknown place"
                );
            }

            const std::size_t placeIndex =
                static_cast<std::size_t>(std::distance(placeOrder.begin(), iterator));

            model.initialMarking.at(placeIndex) =
                parseInt(fields[2], "initial marking token_count");
            continue;
        }

        if (recordType == "target") {
            if (fields.size() != 4) {
                throw std::invalid_argument(
                    "line " + std::to_string(lineNumber)
                    + ": target record requires target|place_id|min_tokens|max_tokens"
                );
            }

            model.targetPredicates.push_back(
                {
                    fields[1],
                    parseInt(fields[2], "target min_tokens"),
                    parseInt(fields[3], "target max_tokens")
                }
            );
            continue;
        }

        if (recordType == "invariant") {
            if (fields.size() != 4) {
                throw std::invalid_argument(
                    "line " + std::to_string(lineNumber)
                    + ": invariant record requires invariant|invariant_id|coefficients:semicolon_separated|expected_value"
                );
            }

            model.invariants.push_back(
                {
                    fields[1],
                    parseCoefficientVector(fields[2], model.places.size()),
                    static_cast<long long>(parseInt(fields[3], "invariant expected_value"))
                }
            );
            continue;
        }

        throw std::invalid_argument(
            "line " + std::to_string(lineNumber)
            + ": unknown record type " + recordType
        );
    }

    if (model.initialMarking.empty()) {
        model.initialMarking.assign(model.places.size(), 0);
    }

    return model;
}

void printUsage(const char* program) {
    std::cerr
        << "Usage:\n"
        << "  " << program
        << " petri_net_model.txt bounded_token_limit maximum_states"
        << " policy_version model_review_status\n\n"
        << "The model file uses pipe-delimited records:\n"
        << "  net|net_version|subsystem_interface_schema\n"
        << "  place|place_id|place_type|subsystem|interface_bool\n"
        << "  transition|transition_id|transition_type|subsystem|human_approval_bool|physical_actuation_bool\n"
        << "  arc|place_id|transition_id|pre_or_post|weight\n"
        << "  marking|place_id|token_count\n"
        << "  target|place_id|min_tokens|max_tokens\n"
        << "  invariant|invariant_id|coefficients:semicolon_separated|expected_value\n\n"
        << "Constraints:\n"
        << "  physical_actuation_bool must always be false.\n"
        << "  sensitive_personal_data place types are prohibited.\n"
        << "  analysis is bounded, offline, and planning-only.\n";
}

}  // namespace

int main(int argc, char* argv[]) {
    constexpr int kExpectedArgumentCount = 6;

    if (argc != kExpectedArgumentCount) {
        printUsage(argv[0]);
        return 64;
    }

    try {
        const int boundedTokenLimit = parseInt(argv[2], "bounded_token_limit");
        const int maximumStates = parseInt(argv[3], "maximum_states");

        if (boundedTokenLimit <= 0 || maximumStates <= 0) {
            throw std::invalid_argument(
                "bounded_token_limit and maximum_states must be positive"
            );
        }

        NetModel model = loadModel(
            argv[1],
            boundedTokenLimit,
            argv[4],
            argv[5]
        );

        PetriNetAnalyzer analyzer(std::move(model));
        const AnalysisResult result = analyzer.analyze(
            static_cast<std::size_t>(maximumStates)
        );

        std::cout << "bounded_reachability_status="
                  << toString(result.boundedReachabilityStatus) << '\n';
        std::cout << "target_state_reachable="
                  << (result.targetStateReachable ? "true" : "false") << '\n';
        std::cout << "deadlock_candidate_states=";

        for (std::size_t index = 0; index < result.deadlockCandidateStates.size(); ++index) {
            if (index > 0) {
                std::cout << ';';
            }
            std::cout << result.deadlockCandidateStates[index];
        }

        std::cout << '\n';
        std::cout << "invariant_validation_status="
                  << toString(result.invariantValidationStatus) << '\n';
        std::cout << "unsafe_marking_detected="
                  << (result.unsafeMarkingDetected ? "true" : "false") << '\n';
        std::cout << "interface_contract_status="
                  << result.interfaceContractStatus << '\n';
        std::cout << "state_space_bound_status="
                  << result.stateSpaceBoundStatus << '\n';
        std::cout << "planning_only_status="
                  << (result.planningOnlyStatus ? "true" : "false") << '\n';
        std::cout << "human_review_required="
                  << (result.humanReviewRequired ? "true" : "false") << '\n';
        std::cout << "visited_state_count=" << result.visitedStateCount << '\n';
        std::cout << "explored_transition_count="
                  << result.exploredTransitionCount << '\n';
        std::cout << "limitation_notice=" << result.limitationNotice << '\n';
        std::cout << "connects_to_infrastructure=false\n";
        std::cout << "produces_actuator_commands=false\n";
        std::cout << "analysis_is_offline=true\n";

        return result.boundedReachabilityStatus
            == AnalysisStatus::CompleteWithinBound
            ? 0
            : 2;
    } catch (const std::exception& error) {
        std::cerr << "Input error: " << error.what() << '\n';
        return 65;
    }
}
