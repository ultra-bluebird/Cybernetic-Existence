#include <cctype>
#include <iostream>
#include <string>
#include <vector>

namespace cyboquatics {

enum class ReviewStatus {
    Pending,
    NotRequired,
    InReview,
    Complete,
    Appealed
};

struct RoutingAuditProvenance {
    std::string auditEventId;
    std::string observationId;
    std::string nodePseudonym;
    std::string routeCode;
    std::string explanationCode;
    std::string explanationText;
    ReviewStatus reviewStatus;
    std::string observedAtUtc;
    std::string policyId;
    std::string inputSchemaVersion;
    bool rawSensitiveDataPresent;
    bool exactPersonalLocationPresent;
    bool directIdentityPresent;
    bool unboundedFreeTextPresent;
};

struct ValidationResult {
    bool valid;
    std::vector<std::string> reasons;
};

bool token(const std::string& value, std::size_t minimum, std::size_t maximum) {
    if (value.size() < minimum || value.size() > maximum) {
        return false;
    }
    for (const char character : value) {
        const unsigned char byte = static_cast<unsigned char>(character);
        if (!(std::isalnum(byte) || character == '-' || character == '_' || character == '.')) {
            return false;
        }
    }
    return true;
}

bool boundedPlainText(const std::string& value) {
    return !value.empty() && value.size() <= 240;
}

ValidationResult validate(const RoutingAuditProvenance& record) {
    std::vector<std::string> reasons;

    if (!token(record.auditEventId, 8, 128)) reasons.emplace_back("Invalid audit event identifier.");
    if (!token(record.observationId, 8, 128)) reasons.emplace_back("Invalid observation identifier.");
    if (!token(record.nodePseudonym, 12, 96)) reasons.emplace_back("Invalid node pseudonym.");
    if (!token(record.routeCode, 3, 80)) reasons.emplace_back("Invalid route code.");
    if (!token(record.explanationCode, 3, 80)) reasons.emplace_back("Invalid explanation code.");
    if (!boundedPlainText(record.explanationText)) reasons.emplace_back("Explanation text must be present and bounded.");
    if (record.observedAtUtc.empty()) reasons.emplace_back("Observation timestamp is required.");
    if (!token(record.policyId, 3, 128)) reasons.emplace_back("Invalid policy identifier.");
    if (!token(record.inputSchemaVersion, 1, 64)) reasons.emplace_back("Invalid input schema version.");
    if (record.rawSensitiveDataPresent) reasons.emplace_back("Raw sensitive data is prohibited.");
    if (record.exactPersonalLocationPresent) reasons.emplace_back("Exact personal location is prohibited.");
    if (record.directIdentityPresent) reasons.emplace_back("Direct identity data is prohibited.");
    if (record.unboundedFreeTextPresent) reasons.emplace_back("Unbounded free text is prohibited.");

    return {reasons.empty(), reasons};
}

}  // namespace cyboquatics

int main() {
    const cyboquatics::RoutingAuditProvenance record{
        "audit-20260826-0001",
        "observation-20260826-0001",
        "canal-node-v9q3r8m2",
        "FOG_REVIEW",
        "CONFIDENCE_BELOW_700",
        "The water sample needs a human review because confidence is below the configured minimum.",
        cyboquatics::ReviewStatus::Pending,
        "2026-08-26T01:22:00Z",
        "fog-acceptance-identity-2026-08-26",
        "routing-input-v1",
        false,
        false,
        false,
        false
    };

    const auto result = cyboquatics::validate(record);
    std::cout << (result.valid ? "VALID" : "INVALID") << '\n';
    return result.valid ? 0 : 1;
}
