#include "nanoswarm_attribution_kernel_test_support.hpp"

#include "../nanoswarm_attribution_kernel.hpp"

#include <string>
#include <utility>
#include <vector>

namespace cybercore::perkunos::tests {
namespace {

[[nodiscard]] AttributionRequest make_valid_request() {
    AttributionRequest request;
    request.request_identifier = "kernel-test-request-001";
    request.host_did = kHostDid;
    request.bostrom_address = kBostromAddress;
    request.migration_authority = kMigrationAuthority;
    request.narrative = "Bounded diagnostic evidence attribution.";
    request.provenance = ProvenanceStatus::Valid;
    request.consent = ConsentStatus::Active;
    request.intent = IntentKind::Diagnostic;
    request.evidence_count = 2U;
    request.evidence[0] = {
        "test-evidence-a",
        EvidenceStatus::Current,
        2'000'000'000U
    };
    request.evidence[1] = {
        "test-evidence-b",
        EvidenceStatus::Current,
        2'000'000'000U
    };
    request.psych_risk = {
        0.20,
        0.15,
        0.10,
        0.05,
        0.10,
        0.85,
        0.10,
        0.50
    };
    request.evaluation_unix_seconds = 1'900'000'000U;
    return request;
}

[[nodiscard]] TestResult expect_rejection(
    const std::string& name,
    const NanoswarmAttributionKernel& kernel,
    const AttributionRequest& request,
    const RejectionReason expected_reason) {
    const DiagnosticDecision decision = kernel.evaluate(request);
    const bool passed =
        decision.disposition == DiagnosticDisposition::Rejected &&
        decision.reason == expected_reason &&
        decision.report.accepted_evidence_identifiers.empty();

    std::string detail = "expected reason=";
    detail += to_string(expected_reason);
    detail += ", actual reason=";
    detail += to_string(decision.reason);
    detail += ", disposition=";
    detail += to_string(decision.disposition);

    return {name, passed, std::move(detail)};
}

[[nodiscard]] TestResult expect_observation(
    const NanoswarmAttributionKernel& kernel) {
    const AttributionRequest request = make_valid_request();
    const DiagnosticDecision decision = kernel.evaluate(request);

    const bool passed =
        decision.disposition == DiagnosticDisposition::Observation &&
        decision.reason == RejectionReason::None &&
        !decision.report.detail_reduced &&
        decision.report.request_identifier == request.request_identifier &&
        decision.report.accepted_evidence_identifiers.size() ==
            request.evidence_count &&
        decision.report.continuity_margin > 0.0 &&
        decision.report.biocompatibility_margin > 0.0;

    return {
        "valid_diagnostic_request_yields_observation",
        passed,
        "A valid bounded request yields a diagnostic observation with "
        "evidence references and positive continuity margins."
    };
}

[[nodiscard]] TestResult expect_reduced_detail(
    const NanoswarmAttributionKernel& kernel) {
    AttributionRequest request = make_valid_request();
    request.psych_risk.cognitive_load = 0.80;

    const DiagnosticDecision decision = kernel.evaluate(request);
    const bool passed =
        decision.disposition == DiagnosticDisposition::ReducedDetail &&
        decision.reason == RejectionReason::None &&
        decision.report.detail_reduced &&
        decision.report.accepted_evidence_identifiers.size() ==
            request.evidence_count;

    return {
        "elevated_cognitive_load_reduces_detail",
        passed,
        "Elevated bounded psych-risk narrows diagnostic detail without "
        "changing the diagnostic-only output category."
    };
}

[[nodiscard]] TestResult expect_kernel_self_checks(
    const NanoswarmAttributionKernel& kernel) {
    const std::vector<SelfCheckResult> checks = kernel.run_self_checks();
    bool passed = checks.size() == 7U;

    for (const SelfCheckResult& check : checks) {
        passed = passed && check.passed;
    }

    return {
        "kernel_embedded_self_checks_pass",
        passed,
        "All embedded diagnostic non-escalation regression checks pass."
    };
}

}  // namespace

std::vector<TestResult> run_nanoswarm_attribution_kernel_tests() {
    const NanoswarmAttributionKernel kernel;
    std::vector<TestResult> results;
    results.reserve(16U);

    results.push_back(expect_observation(kernel));
    results.push_back(expect_reduced_detail(kernel));
    results.push_back(expect_kernel_self_checks(kernel));

    AttributionRequest request = make_valid_request();
    request.provenance = ProvenanceStatus::LocalOnly;
    results.push_back(expect_rejection(
        "local_only_provenance_is_non_authoritative",
        kernel,
        request,
        RejectionReason::InvalidProvenance));

    request = make_valid_request();
    request.provenance = ProvenanceStatus::Unresolved;
    results.push_back(expect_rejection(
        "unresolved_provenance_is_non_authoritative",
        kernel,
        request,
        RejectionReason::InvalidProvenance));

    request = make_valid_request();
    request.provenance = ProvenanceStatus::Invalid;
    results.push_back(expect_rejection(
        "invalid_provenance_is_rejected",
        kernel,
        request,
        RejectionReason::InvalidProvenance));

    request = make_valid_request();
    request.provenance = ProvenanceStatus::Revoked;
    results.push_back(expect_rejection(
        "revoked_provenance_is_rejected",
        kernel,
        request,
        RejectionReason::InvalidProvenance));

    request = make_valid_request();
    request.consent = ConsentStatus::Expired;
    results.push_back(expect_rejection(
        "expired_consent_is_rejected",
        kernel,
        request,
        RejectionReason::InvalidConsent));

    request = make_valid_request();
    request.consent = ConsentStatus::Revoked;
    results.push_back(expect_rejection(
        "revoked_consent_is_rejected",
        kernel,
        request,
        RejectionReason::InvalidConsent));

    request = make_valid_request();
    request.consent = ConsentStatus::Unresolved;
    results.push_back(expect_rejection(
        "unresolved_consent_is_rejected",
        kernel,
        request,
        RejectionReason::InvalidConsent));

    request = make_valid_request();
    request.intent = IntentKind::NonDiagnostic;
    results.push_back(expect_rejection(
        "non_diagnostic_intent_is_rejected",
        kernel,
        request,
        RejectionReason::NonDiagnosticIntent));

    request = make_valid_request();
    request.evidence_count = 0U;
    results.push_back(expect_rejection(
        "empty_evidence_set_is_rejected",
        kernel,
        request,
        RejectionReason::MissingEvidence));

    request = make_valid_request();
    request.evidence[0].status = EvidenceStatus::Expired;
    results.push_back(expect_rejection(
        "expired_evidence_is_rejected",
        kernel,
        request,
        RejectionReason::ExpiredEvidence));

    request = make_valid_request();
    request.evidence[0].status = EvidenceStatus::Revoked;
    results.push_back(expect_rejection(
        "revoked_evidence_is_rejected",
        kernel,
        request,
        RejectionReason::RevokedEvidence));

    request = make_valid_request();
    request.evidence[0].valid_until_unix_seconds =
        request.evaluation_unix_seconds;
    results.push_back(expect_rejection(
        "evidence_at_expiry_boundary_is_rejected",
        kernel,
        request,
        RejectionReason::ExpiredEvidence));

    request = make_valid_request();
    request.psych_risk.roh = kRohCeiling + 0.001;
    results.push_back(expect_rejection(
        "roh_above_global_ceiling_is_rejected",
        kernel,
        request,
        RejectionReason::RohCeilingExceeded));

    request = make_valid_request();
    request.psych_risk.biocompatibility = kMinimumBiocompatibility;
    results.push_back(expect_rejection(
        "minimum_biocompatibility_boundary_is_rejected",
        kernel,
        request,
        RejectionReason::BiophysicalEnvelopeViolation));

    request = make_valid_request();
    request.psych_risk.pain_index = kMaximumPainIndex + 0.001;
    results.push_back(expect_rejection(
        "pain_index_above_envelope_is_rejected",
        kernel,
        request,
        RejectionReason::BiophysicalEnvelopeViolation));

    request = make_valid_request();
    request.psych_risk.fear_index = kMaximumFearIndex + 0.001;
    results.push_back(expect_rejection(
        "fear_index_above_envelope_is_rejected",
        kernel,
        request,
        RejectionReason::BiophysicalEnvelopeViolation));

    request = make_valid_request();
    request.host_did = "incorrect-host-binding";
    results.push_back(expect_rejection(
        "invalid_host_binding_is_rejected",
        kernel,
        request,
        RejectionReason::InvalidIdentityBinding));

    request = make_valid_request();
    request.migration_authority = "incorrect-migration-binding";
    results.push_back(expect_rejection(
        "invalid_migration_binding_is_rejected",
        kernel,
        request,
        RejectionReason::InvalidMigrationAuthority));

    request = make_valid_request();
    request.narrative.assign(kMaximumNarrativeLength + 1U, 'x');
    results.push_back(expect_rejection(
        "oversized_narrative_is_rejected",
        kernel,
        request,
        RejectionReason::NarrativeTooLong));

    request = make_valid_request();
    request.evidence[0].identifier.assign(
        kMaximumEvidenceIdentifierLength + 1U,
        'e');
    results.push_back(expect_rejection(
        "oversized_evidence_identifier_is_rejected",
        kernel,
        request,
        RejectionReason::EvidenceIdentifierTooLong));

    return results;
}

int nanoswarm_attribution_kernel_failure_count() {
    const std::vector<TestResult> results =
        run_nanoswarm_attribution_kernel_tests();

    int failures = 0;
    for (const TestResult& result : results) {
        if (!result.passed) {
            ++failures;
        }
    }
    return failures;
}

}  // namespace cybercore::perkunos::tests
