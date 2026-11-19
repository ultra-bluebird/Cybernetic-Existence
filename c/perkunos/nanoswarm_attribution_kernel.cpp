#include "nanoswarm_attribution_kernel.hpp"

#include <algorithm>
#include <cmath>
#include <sstream>
#include <utility>

namespace cybercore::perkunos {
namespace {

[[nodiscard]] bool is_normalized(const double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

[[nodiscard]] AttributionRequest make_valid_request() {
    AttributionRequest request;
    request.request_identifier = "diagnostic-self-check-001";
    request.host_did = kHostDid;
    request.bostrom_address = kBostromAddress;
    request.migration_authority = kMigrationAuthority;
    request.narrative = "Bounded diagnostic attribution request.";
    request.provenance = ProvenanceStatus::Valid;
    request.consent = ConsentStatus::Active;
    request.intent = IntentKind::Diagnostic;
    request.evidence_count = 1U;
    request.evidence[0] = {
        "evidence-self-check-001",
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

[[nodiscard]] SelfCheckResult check(
    std::string name,
    const DiagnosticDecision& decision,
    const RejectionReason expected_reason) {
    const bool passed =
        decision.disposition == DiagnosticDisposition::Rejected &&
        decision.reason == expected_reason;

    std::ostringstream detail;
    detail << "expected=" << to_string(expected_reason)
           << ", actual=" << to_string(decision.reason)
           << ", disposition=" << to_string(decision.disposition);

    return {std::move(name), passed, detail.str()};
}

}  // namespace

DiagnosticDecision NanoswarmAttributionKernel::evaluate(
    const AttributionRequest& request) const {
    const RejectionReason validation_result = validate(request);
    if (validation_result != RejectionReason::None) {
        DiagnosticDecision decision;
        decision.disposition = DiagnosticDisposition::Rejected;
        decision.reason = validation_result;
        decision.report.request_identifier = request.request_identifier;
        decision.report.summary =
            "Diagnostic attribution withheld because the bounded "
            "host-local validation contract was not satisfied.";
        return decision;
    }

    const bool reduced_detail = requires_reduced_detail(request.psych_risk);

    DiagnosticDecision decision;
    decision.disposition = reduced_detail
        ? DiagnosticDisposition::ReducedDetail
        : DiagnosticDisposition::Observation;
    decision.reason = RejectionReason::None;
    decision.report = build_report(request, reduced_detail);
    return decision;
}

std::vector<SelfCheckResult> NanoswarmAttributionKernel::run_self_checks() const {
    std::vector<SelfCheckResult> results;
    results.reserve(7U);

    const AttributionRequest valid_request = make_valid_request();
    const DiagnosticDecision valid_decision = evaluate(valid_request);

    results.push_back({
        "valid_diagnostic_observation",
        valid_decision.disposition == DiagnosticDisposition::Observation &&
            valid_decision.reason == RejectionReason::None &&
            !valid_decision.report.accepted_evidence_identifiers.empty(),
        "A bounded valid diagnostic request yields an observation only."
    });

    AttributionRequest local_only = valid_request;
    local_only.provenance = ProvenanceStatus::LocalOnly;
    results.push_back(check(
        "local_only_provenance_rejected",
        evaluate(local_only),
        RejectionReason::InvalidProvenance));

    AttributionRequest unresolved = valid_request;
    unresolved.provenance = ProvenanceStatus::Unresolved;
    results.push_back(check(
        "unresolved_provenance_rejected",
        evaluate(unresolved),
        RejectionReason::InvalidProvenance));

    AttributionRequest expired_consent = valid_request;
    expired_consent.consent = ConsentStatus::Expired;
    results.push_back(check(
        "expired_consent_rejected",
        evaluate(expired_consent),
        RejectionReason::InvalidConsent));

    AttributionRequest revoked_evidence = valid_request;
    revoked_evidence.evidence[0].status = EvidenceStatus::Revoked;
    results.push_back(check(
        "revoked_evidence_rejected",
        evaluate(revoked_evidence),
        RejectionReason::RevokedEvidence));

    AttributionRequest non_diagnostic = valid_request;
    non_diagnostic.intent = IntentKind::NonDiagnostic;
    results.push_back(check(
        "non_diagnostic_intent_rejected",
        evaluate(non_diagnostic),
        RejectionReason::NonDiagnosticIntent));

    AttributionRequest oversized_narrative = valid_request;
    oversized_narrative.narrative.assign(kMaximumNarrativeLength + 1U, 'x');
    results.push_back(check(
        "bounded_input_rejected",
        evaluate(oversized_narrative),
        RejectionReason::NarrativeTooLong));

    return results;
}

RejectionReason NanoswarmAttributionKernel::validate(
    const AttributionRequest& request) const {
    if (request.host_did != kHostDid ||
        request.bostrom_address != kBostromAddress) {
        return RejectionReason::InvalidIdentityBinding;
    }

    if (request.migration_authority != kMigrationAuthority) {
        return RejectionReason::InvalidMigrationAuthority;
    }

    if (request.request_identifier.empty()) {
        return RejectionReason::EmptyRequestIdentifier;
    }

    if (request.request_identifier.size() > kMaximumRequestIdentifierLength) {
        return RejectionReason::RequestIdentifierTooLong;
    }

    if (request.narrative.size() > kMaximumNarrativeLength) {
        return RejectionReason::NarrativeTooLong;
    }

    if (request.intent != IntentKind::Diagnostic) {
        return RejectionReason::NonDiagnosticIntent;
    }

    if (request.provenance != ProvenanceStatus::Valid) {
        return RejectionReason::InvalidProvenance;
    }

    if (request.consent != ConsentStatus::Active) {
        return RejectionReason::InvalidConsent;
    }

    if (request.evidence_count == 0U ||
        request.evidence_count > kMaximumEvidenceItems) {
        return RejectionReason::MissingEvidence;
    }

    for (std::size_t index = 0U; index < request.evidence_count; ++index) {
        const EvidenceReference& evidence = request.evidence[index];

        if (evidence.identifier.empty() ||
            evidence.identifier.size() > kMaximumEvidenceIdentifierLength) {
            return RejectionReason::EvidenceIdentifierTooLong;
        }

        if (evidence.status == EvidenceStatus::Revoked) {
            return RejectionReason::RevokedEvidence;
        }

        if (evidence.status == EvidenceStatus::Expired ||
            evidence.valid_until_unix_seconds <= request.evaluation_unix_seconds) {
            return RejectionReason::ExpiredEvidence;
        }

        if (evidence.status != EvidenceStatus::Current) {
            return RejectionReason::InvalidEvidence;
        }
    }

    const PsychRiskProfile& profile = request.psych_risk;
    if (!is_normalized(profile.cognitive_load) ||
        !is_normalized(profile.emotional_destabilization) ||
        !is_normalized(profile.identity_drift) ||
        !is_normalized(profile.blood_drain_impact) ||
        !is_normalized(profile.roh) ||
        !is_normalized(profile.biocompatibility) ||
        !is_normalized(profile.pain_index) ||
        !is_normalized(profile.fear_index)) {
        return RejectionReason::InvalidPsychRiskProfile;
    }

    if (profile.roh > kRohCeiling) {
        return RejectionReason::RohCeilingExceeded;
    }

    if (profile.biocompatibility <= kMinimumBiocompatibility ||
        profile.pain_index > kMaximumPainIndex ||
        profile.fear_index < kMinimumFearIndex ||
        profile.fear_index > kMaximumFearIndex) {
        return RejectionReason::BiophysicalEnvelopeViolation;
    }

    return RejectionReason::None;
}

bool NanoswarmAttributionKernel::requires_reduced_detail(
    const PsychRiskProfile& profile) const {
    return profile.cognitive_load > 0.75 ||
           profile.emotional_destabilization > 0.70 ||
           profile.identity_drift > 0.45 ||
           profile.blood_drain_impact > 0.50 ||
           profile.roh >= 0.24;
}

DiagnosticReport NanoswarmAttributionKernel::build_report(
    const AttributionRequest& request,
    const bool reduced_detail) const {
    DiagnosticReport report;
    report.request_identifier = request.request_identifier;
    report.detail_reduced = reduced_detail;
    report.continuity_margin = kRohCeiling - request.psych_risk.roh;
    report.biocompatibility_margin =
        request.psych_risk.biocompatibility - kMinimumBiocompatibility;

    report.accepted_evidence_identifiers.reserve(request.evidence_count);
    for (std::size_t index = 0U; index < request.evidence_count; ++index) {
        report.accepted_evidence_identifiers.push_back(
            request.evidence[index].identifier);
    }

    if (reduced_detail) {
        report.summary =
            "Diagnostic evidence accepted with reduced detail under the "
            "current psychological-continuity envelope.";
    } else {
        report.summary =
            "Diagnostic evidence accepted within the current bounded "
            "psychological-continuity envelope.";
    }

    return report;
}

const char* to_string(const ProvenanceStatus value) noexcept {
    switch (value) {
        case ProvenanceStatus::LocalOnly:
            return "LocalOnly";
        case ProvenanceStatus::Unresolved:
            return "Unresolved";
        case ProvenanceStatus::Valid:
            return "Valid";
        case ProvenanceStatus::Invalid:
            return "Invalid";
        case ProvenanceStatus::Revoked:
            return "Revoked";
    }
    return "UnknownProvenanceStatus";
}

const char* to_string(const EvidenceStatus value) noexcept {
    switch (value) {
        case EvidenceStatus::Current:
            return "Current";
        case EvidenceStatus::Expired:
            return "Expired";
        case EvidenceStatus::Revoked:
            return "Revoked";
        case EvidenceStatus::Invalid:
            return "Invalid";
    }
    return "UnknownEvidenceStatus";
}

const char* to_string(const ConsentStatus value) noexcept {
    switch (value) {
        case ConsentStatus::Active:
            return "Active";
        case ConsentStatus::Expired:
            return "Expired";
        case ConsentStatus::Revoked:
            return "Revoked";
        case ConsentStatus::Unresolved:
            return "Unresolved";
    }
    return "UnknownConsentStatus";
}

const char* to_string(const IntentKind value) noexcept {
    switch (value) {
        case IntentKind::Diagnostic:
            return "Diagnostic";
        case IntentKind::NonDiagnostic:
            return "NonDiagnostic";
    }
    return "UnknownIntentKind";
}

const char* to_string(const DiagnosticDisposition value) noexcept {
    switch (value) {
        case DiagnosticDisposition::Observation:
            return "Observation";
        case DiagnosticDisposition::ReducedDetail:
            return "ReducedDetail";
        case DiagnosticDisposition::Rejected:
            return "Rejected";
    }
    return "UnknownDiagnosticDisposition";
}

const char* to_string(const RejectionReason value) noexcept {
    switch (value) {
        case RejectionReason::None:
            return "None";
        case RejectionReason::InvalidIdentityBinding:
            return "InvalidIdentityBinding";
        case RejectionReason::InvalidMigrationAuthority:
            return "InvalidMigrationAuthority";
        case RejectionReason::EmptyRequestIdentifier:
            return "EmptyRequestIdentifier";
        case RejectionReason::RequestIdentifierTooLong:
            return "RequestIdentifierTooLong";
        case RejectionReason::NarrativeTooLong:
            return "NarrativeTooLong";
        case RejectionReason::NonDiagnosticIntent:
            return "NonDiagnosticIntent";
        case RejectionReason::InvalidProvenance:
            return "InvalidProvenance";
        case RejectionReason::InvalidConsent:
            return "InvalidConsent";
        case RejectionReason::MissingEvidence:
            return "MissingEvidence";
        case RejectionReason::InvalidEvidence:
            return "InvalidEvidence";
        case RejectionReason::ExpiredEvidence:
            return "ExpiredEvidence";
        case RejectionReason::RevokedEvidence:
            return "RevokedEvidence";
        case RejectionReason::EvidenceIdentifierTooLong:
            return "EvidenceIdentifierTooLong";
        case RejectionReason::InvalidPsychRiskProfile:
            return "InvalidPsychRiskProfile";
        case RejectionReason::RohCeilingExceeded:
            return "RohCeilingExceeded";
        case RejectionReason::BiophysicalEnvelopeViolation:
            return "BiophysicalEnvelopeViolation";
    }
    return "UnknownRejectionReason";
}

}  // namespace cybercore::perkunos
