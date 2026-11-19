# SPDX-License-Identifier: MIT OR Apache-2.0
"""Pure ecological-debt accounting preview; no ledger writes or verification.

Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
Credit only; no consent, authentication, or operational authority.
"""

from dataclasses import asdict, dataclass
from fractions import Fraction
import re


REQUIRED_FINDINGS = frozenset({
    "component_compatibility",
    "observed_outcome",
    "attribution",
    "uncertainty_treatment",
    "persistence",
    "cross_boundary_effects",
    "no_duplicate_allocation",
    "rights",
    "accessibility",
    "ecological_integrity",
})


def text(value):
    return type(value) is str and 0 < len(value.strip()) <= 512


def commitment(value):
    return (
        type(value) is str
        and re.fullmatch(r"[0-9a-f]{64}", value) is not None
    )


def quantity(value):
    pattern = r"(?:0|[1-9][0-9]{0,29})(?:\.[0-9]{1,12})?"
    if type(value) is not str or re.fullmatch(pattern, value) is None:
        raise ValueError("bounded nonnegative decimal text required")
    return Fraction(value)


@dataclass(frozen=True)
class RepairAllocation:
    amount: str
    component: str
    unit: str
    boundary_reference: str
    stage: str
    allocation_sha256: str | None
    governance_sha256: str | None
    outcome_reference: str | None
    review_reference: str | None
    findings: tuple

    def __post_init__(self):
        quantity(self.amount)
        if not all(text(v) for v in (
            self.component, self.unit, self.boundary_reference
        )):
            raise ValueError("component, unit, and boundary required")

        if self.stage not in {
            "planned", "implemented", "measured",
            "reviewed", "rejected", "expired", "suspended"
        }:
            raise ValueError("unsupported repair stage")

        for value in (self.allocation_sha256, self.governance_sha256):
            if value is not None and not commitment(value):
                raise ValueError("invalid SHA-256 commitment")

        for value in (self.outcome_reference, self.review_reference):
            if value is not None and not text(value):
                raise ValueError("invalid evidence reference")

        if not (
            type(self.findings) is tuple
            and len(self.findings) <= len(REQUIRED_FINDINGS)
        ):
            raise ValueError("bounded finding tuple required")

        names = []
        for item in self.findings:
            if not (
                type(item) is tuple
                and len(item) == 3
                and type(item[0]) is str
                and item[0] in REQUIRED_FINDINGS
                and type(item[1]) is str
                and item[1] in {"supported", "not_supported", "unresolved"}
                and (item[2] is None or text(item[2]))
            ):
                raise ValueError("invalid finding")
            names.append(item[0])

        if len(set(names)) != len(names):
            raise ValueError("duplicate finding")


def preview_debt_update(
    current_debt,
    new_loss,
    component,
    unit,
    boundary_reference,
    governance_sha256,
    repairs,
    accounted_allocations,
    *,
    allocation_history_complete,
):
    """Return an advisory proposal for one compatible debt component.

    Commitments and references are supplied assertions, not authenticated.
    Each commitment must describe one component-specific incremental
    allocation, not a cumulative repair stock or a whole project package.
    """
    debt = quantity(current_debt)
    loss = quantity(new_loss)

    if not all(text(v) for v in (component, unit, boundary_reference)):
        raise ValueError("accounting scope required")
    if not commitment(governance_sha256):
        raise ValueError("pinned governance commitment required")
    if type(allocation_history_complete) is not bool:
        raise ValueError("explicit history-completeness assertion required")
    if not (
        type(repairs) is tuple
        and len(repairs) <= 256
        and all(type(r) is RepairAllocation for r in repairs)
    ):
        raise ValueError("bounded repair tuple required")
    if not (
        type(accounted_allocations) is tuple
        and len(accounted_allocations) <= 4096
        and all(commitment(v) for v in accounted_allocations)
        and len(set(accounted_allocations)) == len(accounted_allocations)
    ):
        raise ValueError("distinct supplied allocation history required")

    base = debt + loss
    seen = set(accounted_allocations)
    eligible = Fraction(0)
    decisions = []
    newly_accounted = []

    for repair in repairs:
        if (
            repair.component != component
            or repair.unit != unit
            or repair.boundary_reference != boundary_reference
        ):
            raise ValueError("repair does not match accounting component")

        findings = {
            name: (state, reference)
            for name, state, reference in repair.findings
        }

        if not allocation_history_complete:
            reason = "history_unresolved_not_applied"
        elif repair.stage != "reviewed":
            reason = "not_reviewed_and_eligible_not_applied"
        elif repair.governance_sha256 != governance_sha256:
            reason = "governance_mismatch_not_applied"
        elif (
            repair.allocation_sha256 is None
            or repair.outcome_reference is None
            or repair.review_reference is None
        ):
            reason = "documentation_incomplete_not_applied"
        elif set(findings) != REQUIRED_FINDINGS or any(
            state != "supported" or reference is None
            for state, reference in findings.values()
        ):
            reason = "safeguard_or_evidence_unresolved_not_applied"
        elif repair.allocation_sha256 in seen:
            reason = "previously_accounted_or_replayed_not_applied"
        else:
            eligible += quantity(repair.amount)
            seen.add(repair.allocation_sha256)
            newly_accounted.append(repair.allocation_sha256)
            reason = "documentary_prerequisites_met_for_preview_only"

        decisions.append({
            "submitted_repair": asdict(repair),
            "finding": reason,
        })

    retired = min(base, eligible)
    unclamped = base - eligible

    return {
        "component": component,
        "unit": unit,
        "boundary_reference": boundary_reference,
        "governance_sha256": governance_sha256,
        "submitted_current_debt": current_debt,
        "submitted_new_loss": new_loss,
        "balance_before_new_repair_exact": str(base),
        "documentarily_eligible_repair_exact": str(eligible),
        "proposed_retirement_exact": (
            str(retired) if allocation_history_complete else None
        ),
        "pre_clamp_balance_exact": (
            str(unclamped) if allocation_history_complete else None
        ),
        "proposed_next_debt_exact": (
            str(max(Fraction(0), unclamped))
            if allocation_history_complete else None
        ),
        "eligible_amount_not_retired_exact": (
            str(eligible - retired)
            if allocation_history_complete else None
        ),
        "unretired_amount_available_for_automatic_reuse": False,
        "newly_accounted_allocations_if_proposal_is_adopted": (
            newly_accounted if allocation_history_complete else []
        ),
        "repair_decisions": decisions,
        "allocation_history_complete_as_declared": (
            allocation_history_complete
        ),
        "allocation_history_completeness_verified": False,
        "allocation_commitments_authenticated": False,
        "ecological_verification_performed": False,
        "ledger_modified": False,
        "full_ecological_recovery_established": False,
        "publication_authorized": False,
        "external_action_authorized": False,
    }
