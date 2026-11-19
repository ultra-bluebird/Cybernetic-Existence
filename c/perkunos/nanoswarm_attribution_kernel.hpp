#ifndef PERKUNOS_NANOSWARM_ATTRIBUTION_KERNEL_HPP
#define PERKUNOS_NANOSWARM_ATTRIBUTION_KERNEL_HPP

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace cybercore::perkunos {

inline constexpr const char kHostDid[] = "didalnorganic-host";
inline constexpr const char kBostromAddress[] =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
inline constexpr const char kMigrationAuthority[] =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

inline constexpr std::size_t kMaximumEvidenceItems = 8U;
inline constexpr std::size_t kMaximumEvidenceIdentifierLength = 96U;
inline constexpr std::size_t kMaximumRequestIdentifierLength = 96U;
inline constexpr std::size_t kMaximumNarrativeLength = 512U;
inline constexpr double kRohCeiling = 0.30;
inline constexpr double kMinimumBiocompatibility = 0.57;
inline constexpr double kMaximumPainIndex = 0.73;
inline constexpr double kMinimumFearIndex = 0.31;
inline constexpr double kMaximumFearIndex = 0.68;

enum class ProvenanceStatus : std::uint8_t {
    LocalOnly,
    Unresolved,
    Valid,
    Invalid,
    Revoked
};

enum class EvidenceStatus : std::uint8_t {
    Current,
    Expired,
    Revoked,
    Invalid
};

enum class ConsentStatus : std::uint8_t {
    Active,
    Expired,
    Revoked,
    Unresolved
};

enum class IntentKind : std::uint8_t {
    Diagnostic,
    NonDiagnostic
};

enum class DiagnosticDisposition : std::uint8_t {
    Observation,
    ReducedDetail,
    Rejected
};

enum class RejectionReason : std::uint8_t {
    None,
    InvalidIdentityBinding,
    InvalidMigrationAuthority,
    EmptyRequestIdentifier,
    RequestIdentifierTooLong,
    NarrativeTooLong,
    NonDiagnosticIntent,
    InvalidProvenance,
    InvalidConsent,
    MissingEvidence,
    InvalidEvidence,
    ExpiredEvidence,
    RevokedEvidence,
    EvidenceIdentifierTooLong,
    InvalidPsychRiskProfile,
    RohCeilingExceeded,
    BiophysicalEnvelopeViolation
};

struct EvidenceReference {
    std::string identifier;
    EvidenceStatus status{EvidenceStatus::Invalid};
    std::uint64_t valid_until_unix_seconds{0U};
};

struct PsychRiskProfile {
    double cognitive_load{0.0};
    double emotional_destabilization{0.0};
    double identity_drift{0.0};
    double blood_drain_impact{0.0};
    double roh{0.0};
    double biocompatibility{1.0};
    double pain_index{0.0};
    double fear_index{0.50};
};

struct AttributionRequest {
    std::string request_identifier;
    std::string host_did;
    std::string bostrom_address;
    std::string migration_authority;
    std::string narrative;
    ProvenanceStatus provenance{ProvenanceStatus::Unresolved};
    ConsentStatus consent{ConsentStatus::Unresolved};
    IntentKind intent{IntentKind::Diagnostic};
    std::array<EvidenceReference, kMaximumEvidenceItems> evidence{};
    std::size_t evidence_count{0U};
    PsychRiskProfile psych_risk{};
    std::uint64_t evaluation_unix_seconds{0U};
};

struct DiagnosticReport {
    std::string request_identifier;
    std::vector<std::string> accepted_evidence_identifiers;
    std::string summary;
    bool detail_reduced{false};
    double continuity_margin{0.0};
    double biocompatibility_margin{0.0};
};

struct DiagnosticDecision {
    DiagnosticDisposition disposition{DiagnosticDisposition::Rejected};
    RejectionReason reason{RejectionReason::None};
    DiagnosticReport report{};
};

struct SelfCheckResult {
    std::string name;
    bool passed{false};
    std::string detail;
};

class NanoswarmAttributionKernel final {
public:
    [[nodiscard]] DiagnosticDecision evaluate(
        const AttributionRequest& request) const;

    [[nodiscard]] std::vector<SelfCheckResult> run_self_checks() const;

private:
    [[nodiscard]] RejectionReason validate(
        const AttributionRequest& request) const;

    [[nodiscard]] bool requires_reduced_detail(
        const PsychRiskProfile& profile) const;

    [[nodiscard]] DiagnosticReport build_report(
        const AttributionRequest& request,
        bool reduced_detail) const;
};

[[nodiscard]] const char* to_string(ProvenanceStatus value) noexcept;
[[nodiscard]] const char* to_string(EvidenceStatus value) noexcept;
[[nodiscard]] const char* to_string(ConsentStatus value) noexcept;
[[nodiscard]] const char* to_string(IntentKind value) noexcept;
[[nodiscard]] const char* to_string(DiagnosticDisposition value) noexcept;
[[nodiscard]] const char* to_string(RejectionReason value) noexcept;

}  // namespace cybercore::perkunos

#endif
