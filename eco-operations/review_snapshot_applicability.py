# SPDX-License-Identifier: MIT OR Apache-2.0
"""Compare declared review bindings without rewriting the review snapshot.

No storage, source inspection, consent adjudication, or external action.

Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
Credit only; no consent, authentication, or external authority.
"""

from dataclasses import asdict, dataclass


REQUIRED_BINDINGS = frozenset({
    "claim",
    "intended_use",
    "boundaries",
    "observation_support",
    "evidence_revision",
    "manifest_revision",
    "method_revision",
    "dependency_revision",
    "conditions_revision",
    "restrictions_revision",
    "governance_revision",
})

DECISION_STATES = frozenset({
    "permitted_within_recorded_scope",
    "restricted",
    "withdrawn",
    "disputed",
    "not_disclosed",
    "unresolved",
})

LIFECYCLE_STATES = frozenset({
    "active_as_recorded",
    "superseded",
    "withdrawn",
    "disputed",
    "unresolved",
})


def text(value):
    return type(value) is str and 0 < len(value.strip()) <= 512


@dataclass(frozen=True)
class ContextBinding:
    name: str
    availability: str
    revision_reference: str | None

    def __post_init__(self):
        if type(self.name) is not str or self.name not in REQUIRED_BINDINGS:
            raise ValueError("unsupported binding name")

        if self.availability not in {
            "available",
            "unresolved",
            "not_disclosed",
        }:
            raise ValueError("unsupported binding availability")

        if self.availability == "available":
            if not text(self.revision_reference):
                raise ValueError("available binding needs a reference")
        elif self.revision_reference is not None:
            raise ValueError("unavailable reference must remain null")


def binding_map(bindings):
    if not (
        type(bindings) is tuple
        and len(bindings) == len(REQUIRED_BINDINGS)
        and all(type(item) is ContextBinding for item in bindings)
    ):
        raise ValueError("complete typed binding inventory required")

    result = {item.name: item for item in bindings}
    if len(result) != len(bindings) or set(result) != REQUIRED_BINDINGS:
        raise ValueError("duplicate or missing context binding")
    return result


@dataclass(frozen=True)
class ReviewSnapshot:
    bindings: tuple
    findings_reference: str
    limitations_reference: str
    review_basis_reference: str
    recorded_decision_state: str
    access_reference: str
    retention_reference: str

    def __post_init__(self):
        binding_map(self.bindings)

        if not all(text(value) for value in (
            self.findings_reference,
            self.limitations_reference,
            self.review_basis_reference,
            self.access_reference,
            self.retention_reference,
        )):
            raise ValueError("review and privacy references required")

        if self.recorded_decision_state not in DECISION_STATES:
            raise ValueError("unsupported recorded decision state")


def assess_current_applicability(
    snapshot,
    current_bindings,
    *,
    snapshot_lifecycle,
    current_recorded_decision_state,
):
    """Compare assertions; do not authenticate referenced content or decisions.

    Equal references establish only declared-reference agreement.
    A caller must not reuse a reference for materially changed content.
    """
    if type(snapshot) is not ReviewSnapshot:
        raise ValueError("typed snapshot required")
    if snapshot_lifecycle not in LIFECYCLE_STATES:
        raise ValueError("explicit snapshot lifecycle required")
    if current_recorded_decision_state not in DECISION_STATES:
        raise ValueError("explicit current decision state required")

    previous = binding_map(snapshot.bindings)
    current = binding_map(current_bindings)

    changes = []
    unresolved = []

    for name in sorted(REQUIRED_BINDINGS):
        old = previous[name]
        new = current[name]

        if (
            old.availability != "available"
            or new.availability != "available"
        ):
            unresolved.append({
                "binding": name,
                "snapshot_availability": old.availability,
                "current_availability": new.availability,
            })
        elif old.revision_reference != new.revision_reference:
            changes.append(name)

    decision_changed = (
        snapshot.recorded_decision_state
        != current_recorded_decision_state
    )
    if decision_changed:
        changes.append("recorded_decision_state")

    if changes:
        status = "does_not_match_current_declared_context"
    elif snapshot_lifecycle != "active_as_recorded":
        status = "review_required_snapshot_lifecycle"
    elif unresolved:
        status = "applicability_unresolved"
    else:
        status = "same_declared_bindings_not_approval"

    return {
        "historical_snapshot": asdict(snapshot),
        "snapshot_lifecycle_as_recorded": snapshot_lifecycle,
        "current_bindings": [
            asdict(binding) for binding in current_bindings
        ],
        "current_recorded_decision_state": (
            current_recorded_decision_state
        ),
        "changed_bindings": changes,
        "unresolved_bindings": unresolved,
        "applicability_status": status,
        "historical_snapshot_modified": False,
        "snapshot_authenticity": "not established",
        "referenced_content_compared": False,
        "lifecycle_authenticity": "not established",
        "rights_holder_decision_adjudicated": False,
        "scientific_support_established": False,
        "psychological_continuity_verified": False,
        "publication_authorized": False,
        "external_action_authorized": False,
        "ordinary_assistance_remains_available": True,
    }
