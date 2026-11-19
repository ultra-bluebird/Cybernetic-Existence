# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local recovery-disposition proposals from supplied review metadata.

No artifact inspection, execution, storage, reconstruction, or external action.

Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
Credit only; no consent, authentication, or external authority.
"""

from dataclasses import asdict, dataclass
import re


def text(value):
    return type(value) is str and 0 < len(value.strip()) <= 512


def sha256_text(value):
    return (
        type(value) is str
        and re.fullmatch(r"[0-9a-f]{64}", value) is not None
    )


@dataclass(frozen=True)
class ScreeningFinding:
    category: str
    basis_reference: str
    scope_reference: str
    limitation: str

    def __post_init__(self):
        if self.category not in {
            "url_policy_mismatch",
            "embedded_instruction_candidate",
            "script_token_candidate",
            "origin_unresolved",
            "container_structure_concern",
            "unsupported_encoding",
        }:
            raise ValueError("unsupported finding category")

        if not all(text(value) for value in (
            self.basis_reference,
            self.scope_reference,
            self.limitation,
        )):
            raise ValueError("finding basis, scope, and limitation required")


@dataclass(frozen=True)
class RecoveryReview:
    screening_state: str
    findings: tuple
    provenance_state: str
    recorded_use_state: str
    source_inventory_reference: str
    policy_sha256: str
    privacy_class: str
    retention_reference: str
    preservation_reference: str | None

    def __post_init__(self):
        if self.screening_state not in {
            "completed_as_recorded",
            "limited",
            "not_performed",
        }:
            raise ValueError("unsupported screening state")

        if not (
            type(self.findings) is tuple
            and len(self.findings) <= 128
            and all(type(item) is ScreeningFinding for item in self.findings)
        ):
            raise ValueError("bounded typed finding tuple required")

        if self.provenance_state not in {
            "content_consistent_as_recorded",
            "content_discrepancy",
            "unresolved",
        }:
            raise ValueError("unsupported provenance state")

        if self.recorded_use_state not in {
            "permitted_within_recorded_scope",
            "restricted",
            "withdrawn",
            "unresolved",
        }:
            raise ValueError("unsupported recorded use state")

        if not (
            text(self.source_inventory_reference)
            and text(self.retention_reference)
            and sha256_text(self.policy_sha256)
        ):
            raise ValueError("source, retention, and policy binding required")

        if self.privacy_class not in {
            "host-local",
            "primitives-only",
            "bounded-telemetry",
            "host-released",
        }:
            raise ValueError("unsupported privacy class")

        if (
            self.preservation_reference is not None
            and not text(self.preservation_reference)
        ):
            raise ValueError("invalid preservation reference")


def propose_recovery_disposition(review):
    """Return review routing only; do not grant permission or change trust."""
    if type(review) is not RecoveryReview:
        raise ValueError("typed recovery review required")

    reasons = []

    if review.recorded_use_state in {"restricted", "withdrawn"}:
        reasons.append("recorded_restriction_or_withdrawal")
    elif review.recorded_use_state == "unresolved":
        reasons.append("recorded_use_scope_unresolved")

    if review.provenance_state == "content_discrepancy":
        reasons.append("recorded_content_discrepancy")
    elif review.provenance_state == "unresolved":
        reasons.append("provenance_unresolved")

    if review.findings:
        reasons.append("screening_findings_require_disposition_review")

    if review.screening_state != "completed_as_recorded":
        reasons.append("screening_incomplete_or_limited")

    if "recorded_restriction_or_withdrawal" in reasons:
        route = "restriction_review"
    elif "recorded_content_discrepancy" in reasons:
        route = "content_discrepancy_review"
    elif review.findings:
        route = "screening_findings_review"
    elif reasons:
        route = "incomplete_assessment_review"
    else:
        route = "candidate_dossier_review_only"

    if review.screening_state == "not_performed":
        screening_statement = "screening not performed"
    elif review.findings:
        screening_statement = "declared screening findings recorded"
    elif review.screening_state == "limited":
        screening_statement = (
            "no declared pattern recorded within limited screening"
        )
    else:
        screening_statement = (
            "no declared screening pattern detected as recorded; "
            "not proof of safety"
        )

    return {
        "submitted_review": asdict(review),
        "proposed_review_route": route,
        "all_review_reasons": reasons,
        "screening_statement": screening_statement,
        "content_trust_status": "untrusted_input",
        "recorded_use_state": review.recorded_use_state,
        "recorded_use_decision_authenticated": False,
        "policy_origin_authenticated": False,
        "preservation_reference_verified": False,
        "preservation_performed_by_this_function": False,
        "quarantine_performed": False,
        "reconstruction_performed": False,
        "candidate_adoption_authorized": False,
        "scientific_support_established": False,
        "psychological_continuity_restoration_claimed": False,
        "ecological_debt_reduction_authorized": False,
        "publication_authorized": False,
        "external_action_authorized": False,
        "ordinary_assistance_remains_available": True,
    }
