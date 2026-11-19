"""Structured assurance projection for an already-reviewed bounded claim.

Python 3.10 or newer; standard library only.
No network access, storage, publication, or actuation.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


@dataclass(frozen=True)
class FindingView:
    outcome: str
    applicability: str


@dataclass(frozen=True)
class ReviewView:
    scope: str
    configuration: str
    lifecycle: str
    support_current: bool
    configuration_assessed: bool
    dispute_open: bool
    findings: tuple[FindingView, ...]
    schema_version: str = "1.0.0"


def project(view):
    """Return displayable facts without claiming history verification."""
    if type(view) is not ReviewView:
        raise ValueError("unsupported_view_schema")

    if view.schema_version != "1.0.0":
        raise ValueError("unsupported_view_schema")

    if any(
        type(value) is not str or not value.strip()
        for value in (view.scope, view.configuration)
    ):
        raise ValueError("missing_scope_or_configuration")

    if (
        type(view.lifecycle) is not str
        or view.lifecycle not in {"active", "retired"}
    ):
        raise ValueError("invalid_lifecycle")

    if any(
        type(value) is not bool
        for value in (
            view.support_current,
            view.configuration_assessed,
            view.dispute_open,
        )
    ):
        raise ValueError("invalid_flags")

    if type(view.findings) is not tuple:
        raise ValueError("findings_must_be_tuple")

    allowed_outcomes = {
        "open",
        "verified_corrected",
        "finding_error_corrected",
        "superseded",
    }

    for finding in view.findings:
        if (
            type(finding) is not FindingView
            or type(finding.outcome) is not str
            or type(finding.applicability) is not str
            or finding.outcome not in allowed_outcomes
            or finding.applicability not in {"yes", "no", "unknown"}
        ):
            raise ValueError("invalid_finding_view")

    open_findings = [
        finding
        for finding in view.findings
        if finding.outcome == "open"
    ]

    applicable = sum(
        finding.applicability == "yes"
        for finding in open_findings
    )
    uncertain = sum(
        finding.applicability == "unknown"
        for finding in open_findings
    )
    nonapplicable = sum(
        finding.applicability == "no"
        for finding in open_findings
    )

    active_conflict = view.support_current and applicable > 0
    reasons = []

    if view.lifecycle == "retired":
        assurance = "not_assessed_retired"
        reasons.append("deployment_retired")
    elif applicable:
        assurance = "nonconforming"
        reasons.append("applicable_open_finding")
    elif (
        not view.configuration_assessed
        or uncertain
        or view.dispute_open
        or not view.support_current
    ):
        assurance = "unknown"
    else:
        assurance = "conforming"

    if not view.configuration_assessed:
        reasons.append("configuration_not_assessed")
    if uncertain:
        reasons.append("open_finding_applicability_unknown")
    if view.dispute_open:
        reasons.append("historical_dispute_open")
    if not view.support_current:
        reasons.append("current_support_unavailable")
    if active_conflict:
        reasons.append("current_support_and_violation_coexist")

    return {
        "schema_version": "1.0.0",
        "provenance": {
            "sovereign_attribution": ATTRIBUTION,
            "use": "document_credit_only",
        },
        "scope": view.scope,
        "configuration": view.configuration,
        "lifecycle": view.lifecycle,
        "current_assurance": assurance,
        "open_finding_count": len(open_findings),
        "applicable_open_finding_count": applicable,
        "unknown_applicability_count": uncertain,
        "nonapplicable_open_finding_count": nonapplicable,
        "verified_correction_count": sum(
            finding.outcome == "verified_corrected"
            for finding in view.findings
        ),
        "erroneous_finding_correction_count": sum(
            finding.outcome == "finding_error_corrected"
            for finding in view.findings
        ),
        "superseded_count": sum(
            finding.outcome == "superseded"
            for finding in view.findings
        ),
        "active_conflict": active_conflict,
        "historical_dispute_open": view.dispute_open,
        "reasons": reasons,
        "authority_established_by_projection": False,
        "history_or_reachability_verified": False,
    }
