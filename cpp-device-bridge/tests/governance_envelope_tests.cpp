#include "governance_envelope.hpp"

#include <cassert>
#include <stdexcept>
#include <string>

using augmented_hub::environmental_metrics::GovernanceEnvelope;
using augmented_hub::environmental_metrics::attach_governance_envelope;
using augmented_hub::environmental_metrics::governance_envelope_json;
using augmented_hub::environmental_metrics::is_valid_governance_envelope;
using augmented_hub::environmental_metrics::standard_governance_envelope;

int main() {
    const GovernanceEnvelope envelope = standard_governance_envelope();

    assert(is_valid_governance_envelope(envelope));

    const std::string envelope_json = governance_envelope_json(envelope);

    assert(
        envelope_json.find(
            "\"scope\":\"aggregate_environmental_decision_support_only\""
        ) != std::string::npos
    );
    assert(
        envelope_json.find("\"individual_profiling\":false")
        != std::string::npos
    );
    assert(
        envelope_json.find("\"automated_adverse_action\":false")
        != std::string::npos
    );
    assert(
        envelope_json.find("\"external_action\":false")
        != std::string::npos
    );

    const std::string response = attach_governance_envelope(
        "{\"metric\":\"surface_burn_clock\",\"result\":{}}",
        envelope
    );

    assert(
        response.find("\"governance\":{")
        != std::string::npos
    );

    GovernanceEnvelope invalid = standard_governance_envelope();
    invalid.external_action = true;

    assert(!is_valid_governance_envelope(invalid));

    bool rejected = false;
    try {
        static_cast<void>(governance_envelope_json(invalid));
    } catch (const std::invalid_argument&) {
        rejected = true;
    }

    assert(rejected);

    return 0;
}
