"""Finite declared-envelope review.

Python 3.10 or newer; standard library only.

Evaluates supplied declarations, not observed processing behavior.
No storage, publication, network access, or actuation occurs here.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

POLICY_KEYS = {
    "schema_version",
    "purposes",
    "recipients",
    "interfaces",
    "activities",
    "retention_min_seconds",
    "retention_max_seconds",
    "purpose_recipient_pairs",
    "interface_activity_pairs",
}

PROPOSAL_KEYS = {
    "purpose", "recipients", "interface",
    "activity", "retention_seconds",
}


def aggregate(states):
    if not states:
        return "U"
    if "F" in states:
        return "F"
    return "P" if all(state == "P" for state in states) else "U"


def text_or_unknown(value):
    return value is None or (
        type(value) is str and bool(value.strip())
    )


def set_or_unknown(value):
    return value is None or (
        type(value) is frozenset
        and all(type(item) is str and item.strip() for item in value)
    )


def seconds_or_unknown(value):
    return value is None or (
        type(value) is int and 0 <= value <= 2**53 - 1
    )


def assess(envelope, proposal, dependency_results=()):
    if type(envelope) is not dict or type(proposal) is not dict:
        raise TypeError("dictionary_inputs_required")
    if set(envelope) != POLICY_KEYS or set(proposal) != PROPOSAL_KEYS:
        raise ValueError("unsupported_profile_shape")
    if envelope["schema_version"] != "1.0.0":
        raise ValueError("unsupported_envelope_schema")

    for key in ("purposes", "recipients", "interfaces", "activities"):
        if not set_or_unknown(envelope[key]):
            raise ValueError("invalid_allowed_set")

    for key in ("purpose", "interface", "activity"):
        if not text_or_unknown(proposal[key]):
            raise ValueError("invalid_proposed_label")

    if not set_or_unknown(proposal["recipients"]):
        raise ValueError("invalid_proposed_recipients")

    for key in ("retention_min_seconds", "retention_max_seconds"):
        if not seconds_or_unknown(envelope[key]):
            raise ValueError("invalid_retention_bound")

    if not seconds_or_unknown(proposal["retention_seconds"]):
        raise ValueError("invalid_proposed_retention")

    minimum = envelope["retention_min_seconds"]
    maximum = envelope["retention_max_seconds"]
    if minimum is not None and maximum is not None and minimum > maximum:
        raise ValueError("inconsistent_retention_bounds")

    for key in ("purpose_recipient_pairs", "interface_activity_pairs"):
        pairs = envelope[key]
        if pairs is not None and (
            type(pairs) is not frozenset
            or any(
                type(pair) is not tuple
                or len(pair) != 2
                or any(type(x) is not str or not x.strip() for x in pair)
                for pair in pairs
            )
        ):
            raise ValueError("invalid_pair_conditions")

    if type(dependency_results) is not tuple or any(
        type(state) is not str or state not in {"P", "F", "U"}
        for state in dependency_results
    ):
        raise ValueError("invalid_dependency_results")

    checks = []

    def add(name, known, passed):
        checks.append({
            "condition": name,
            "result": "U" if not known else ("P" if passed else "F"),
        })

    for field, allowed in (
        ("purpose", "purposes"),
        ("interface", "interfaces"),
        ("activity", "activities"),
    ):
        value = proposal[field]
        permitted = envelope[allowed]
        known = value is not None and permitted is not None
        add(field, known, known and value in permitted)

    recipients = proposal["recipients"]
    permitted_recipients = envelope["recipients"]
    known = recipients is not None and permitted_recipients is not None
    add(
        "recipients",
        known,
        known and recipients <= permitted_recipients,
    )

    retention = proposal["retention_seconds"]
    known = retention is not None and minimum is not None
    add("retention_minimum", known, known and retention >= minimum)

    known = retention is not None and maximum is not None
    add("retention_maximum", known, known and retention <= maximum)

    pairs = envelope["purpose_recipient_pairs"]
    purpose = proposal["purpose"]
    known = purpose is not None and recipients is not None and pairs is not None
    add(
        "purpose_recipient",
        known,
        known and all((purpose, recipient) in pairs for recipient in recipients),
    )

    pairs = envelope["interface_activity_pairs"]
    interface = proposal["interface"]
    activity = proposal["activity"]
    known = interface is not None and activity is not None and pairs is not None
    add(
        "interface_activity",
        known,
        known and (interface, activity) in pairs,
    )

    scope_result = aggregate([check["result"] for check in checks])
    dependency_result = aggregate(dependency_results)
    transfer_result = aggregate([scope_result, dependency_result])

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "scope_membership": scope_result,
        "dependency_review": dependency_result,
        "assurance_transfer": transfer_result,
        "condition_results": checks,
        "authorization": "not_evaluated",
        "processing_behavior": "not_observed",
        "person_access": "not_decided",
    }
