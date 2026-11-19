"""Declared-purpose comparison and finite joint-input reachability.

Python 3.10 or newer; standard library only.

SOVEREIGN-ATTRIBUTION:
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is document credit only, not identity, consent, or authority.

No collection, network access, publication, storage, or actuation is
performed by this module. Integrations require separate governance.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass, fields


SCHEMA_VERSION = "1.0.0"
ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


@dataclass(frozen=True)
class Activity:
    purpose: str
    operation: str
    inputs: frozenset[str]
    outputs: frozenset[str]
    recipients: frozenset[str]
    context: str
    retention_policy: str
    inference_rules: frozenset[str]
    authority_scope: str


@dataclass(frozen=True)
class Rule:
    required: frozenset[str]
    output: str
    explanation: str


def validate_text(value, name):
    if type(value) is not str or not value.strip():
        raise ValueError(f"{name}: nonempty text required")
    if len(value) > 2048:
        raise ValueError(f"{name}: text exceeds local limit")


def validate_atoms(value, name, *, allow_empty=True):
    if type(value) is not frozenset:
        raise ValueError(f"{name}: frozenset required")
    if len(value) > 512 or (not allow_empty and not value):
        raise ValueError(f"{name}: invalid set size")
    for item in value:
        validate_text(item, name)


def validate_activity(activity):
    if type(activity) is not Activity:
        raise ValueError("activity_type")

    set_fields = {
        "inputs", "outputs", "recipients", "inference_rules"
    }
    for field in fields(Activity):
        value = getattr(activity, field.name)
        if field.name in set_fields:
            validate_atoms(value, field.name)
        else:
            validate_text(value, field.name)


def compare_activities(reviewed, proposed):
    validate_activity(reviewed)
    validate_activity(proposed)

    changes = [
        {
            "component": field.name,
            "reviewed": serialize(getattr(reviewed, field.name)),
            "proposed": serialize(getattr(proposed, field.name)),
        }
        for field in fields(Activity)
        if getattr(reviewed, field.name)
        != getattr(proposed, field.name)
    ]

    return {
        "schema_version": SCHEMA_VERSION,
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "status": (
            "declared_metadata_changed"
            if changes
            else "declared_metadata_unchanged"
        ),
        "review_triggered_by_diff": bool(changes),
        "changes": changes,
        "input_fields_changed": reviewed.inputs != proposed.inputs,
        "operational_equivalence_established": False,
        "processing_authorized": False,
    }


def serialize(value):
    return sorted(value) if type(value) is frozenset else value


def inference_closure(initial, rules, prohibited):
    validate_atoms(initial, "initial")
    validate_atoms(prohibited, "prohibited")

    if type(rules) is not tuple or len(rules) > 256:
        raise ValueError("rules: tuple of at most 256 rules required")

    universe = set(initial) | set(prohibited)

    for rule in rules:
        if type(rule) is not Rule:
            raise ValueError("rule_type")
        validate_atoms(rule.required, "required", allow_empty=False)
        validate_text(rule.output, "output")
        validate_text(rule.explanation, "explanation")
        universe.update(rule.required)
        universe.add(rule.output)

    if len(universe) > 512:
        raise ValueError("fact_universe_limit")

    reachable = set(initial)
    derivations = []

    while True:
        changed = False

        for rule in rules:
            if (
                rule.output not in reachable
                and rule.required <= reachable
            ):
                reachable.add(rule.output)
                derivations.append({
                    "output": rule.output,
                    "required": sorted(rule.required),
                    "explanation": rule.explanation,
                })
                changed = True

        if not changed:
            break

    reached_prohibited = sorted(reachable & prohibited)

    return {
        "schema_version": SCHEMA_VERSION,
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "reachable": sorted(reachable),
        "prohibited_reached": reached_prohibited,
        "one_derivation_per_new_fact": derivations,
        "model_result": (
            "modeled_prohibited_conclusion_reachable"
            if reached_prohibited
            else "not_derived_in_supplied_model"
        ),
        "scope": "One jointly feasible, positive-rule model.",
        "actual_inference_established": False,
        "inference_accuracy_established": False,
        "pipeline_coverage_established": False,
    }
