# SPDX-License-Identifier: MIT OR Apache-2.0
"""Non-compensatory documentary review of proposed protection changes.

No personal scoring, private-system inspection, floor updates, or external action.

Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
Credit only; no consent, authentication, or external authority.
"""

from dataclasses import asdict, dataclass


def text(value):
    return type(value) is str and 0 < len(value.strip()) <= 512


def optional_reference(value):
    return value is None or text(value)


@dataclass(frozen=True)
class ProtectionRequirement:
    name: str
    established_reference: str | None
    comparison_rule_reference: str | None

    def __post_init__(self):
        if not text(self.name):
            raise ValueError("descriptive protection name required")
        if not all(optional_reference(value) for value in (
            self.established_reference,
            self.comparison_rule_reference,
        )):
            raise ValueError("references must be bounded text or null")


@dataclass(frozen=True)
class ProtectionFinding:
    name: str
    relation: str
    established_reference: str | None
    comparison_rule_reference: str | None
    basis_reference: str | None

    def __post_init__(self):
        if not text(self.name):
            raise ValueError("descriptive protection name required")
        if self.relation not in {
            "preserves", "strengthens", "weakens", "unresolved"
        }:
            raise ValueError("unsupported protection relation")
        if not all(optional_reference(value) for value in (
            self.established_reference,
            self.comparison_rule_reference,
            self.basis_reference,
        )):
            raise ValueError("references must be bounded text or null")


def review_protection_change(
    requirements,
    findings,
    *,
    purpose_reference,
    retention_reference,
):
    """Review supplied assertions, not actual psychological or system effects.

    The required inventory must come from a separately reviewed context.
    Its adequacy, authenticity, and tightening-only history are not verified.
    """
    if not (
        type(requirements) is tuple
        and 0 < len(requirements) <= 64
        and all(type(item) is ProtectionRequirement for item in requirements)
    ):
        raise ValueError("nonempty bounded protection inventory required")

    if not (
        type(findings) is tuple
        and len(findings) <= 64
        and all(type(item) is ProtectionFinding for item in findings)
    ):
        raise ValueError("bounded typed findings required")

    if not (
        text(purpose_reference)
        and text(retention_reference)
    ):
        raise ValueError("purpose and retention references required")

    required = {item.name: item for item in requirements}
    supplied = {item.name: item for item in findings}

    if len(required) != len(requirements):
        raise ValueError("duplicate protection requirement")
    if len(supplied) != len(findings):
        raise ValueError("duplicate protection finding")

    reported_weakening = [
        item.name for item in findings if item.relation == "weakens"
    ]
    undeclared = sorted(set(supplied) - set(required))
    unresolved = []
    documented_preservation = []

    for name, requirement in required.items():
        finding = supplied.get(name)

        if finding is None:
            unresolved.append((name, "finding_missing"))
            continue

        if (
            requirement.established_reference is None
            or requirement.comparison_rule_reference is None
        ):
            unresolved.append((name, "requirement_binding_unavailable"))
            continue

        if (
            finding.established_reference
            != requirement.established_reference
            or finding.comparison_rule_reference
            != requirement.comparison_rule_reference
        ):
            unresolved.append((name, "floor_or_comparison_binding_mismatch"))
            continue

        if finding.basis_reference is None:
            unresolved.append((name, "finding_basis_unavailable"))
        elif finding.relation == "unresolved":
            unresolved.append((name, "impact_unresolved"))
        elif finding.relation in {"preserves", "strengthens"}:
            documented_preservation.append(name)

    if reported_weakening:
        status = "do_not_accept_proposal_as_submitted"
    elif unresolved or undeclared:
        status = "protection_review_unresolved"
    else:
        status = "documentary_preservation_findings_present"

    return {
        "submitted_requirements": [asdict(item) for item in requirements],
        "submitted_findings": [asdict(item) for item in findings],
        "review_status": status,
        "reported_weakening": reported_weakening,
        "unresolved_findings": [
            {"protection": name, "reason": reason}
            for name, reason in unresolved
        ],
        "undeclared_findings": undeclared,
        "documented_preservation": documented_preservation,
        "purpose_reference": purpose_reference,
        "retention_reference": retention_reference,
        "report_scope": "local documentary review only",
        "inventory_adequacy_verified": False,
        "finding_authenticity_verified": False,
        "psychological_continuity_measured": False,
        "protection_floors_modified": False,
        "personal_standing_assessed": False,
        "contribution_required_for_assistance": False,
        "ordinary_assistance_remains_available": True,
        "publication_authorized": False,
        "external_action_authorized": False,
    }
