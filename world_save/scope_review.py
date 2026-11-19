"""Finite scope review and transitive dependency impact.

Python 3.10 or newer.
Dependency: jsonschema with Draft 2020-12 support.

No authentication, publication, storage, network access, or actuation.
The caller supplies the schema and proposed records.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from jsonschema import Draft202012Validator


FIELDS = (
    "purpose", "recipients", "interface",
    "activity", "retention_seconds",
)
CLAIMS = (
    "privacy_assurance",
    "continuity_assurance",
    "public_summary",
)
ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


def validate_configuration(value):
    if type(value) is not dict or set(value) != set(FIELDS):
        raise ValueError("configuration_fields")

    for field in ("purpose", "interface", "activity"):
        item = value[field]
        if item is not None and (
            type(item) is not str or not item.strip()
        ):
            raise ValueError("configuration_label")

    recipients = value["recipients"]
    if recipients is not None and (
        type(recipients) is not list
        or len(recipients) > 128
        or any(type(x) is not str or not x.strip() for x in recipients)
        or len(set(recipients)) != len(recipients)
    ):
        raise ValueError("configuration_recipients")

    seconds = value["retention_seconds"]
    if seconds is not None and (
        type(seconds) is not int
        or not 0 <= seconds <= 9007199254740991
    ):
        raise ValueError("configuration_retention")


def aggregate(states):
    return (
        "F" if "F" in states
        else "P" if all(x == "P" for x in states)
        else "U"
    )


def impact_closure(changed_fields, edges):
    reached = set(changed_fields)
    while True:
        following = reached | {
            edge["dependent"]
            for edge in edges
            if edge["source"] in reached
        }
        if following == reached:
            return reached
        reached = following


def review_scope(schema, envelope, before, proposed, period_status):
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(envelope)
    validate_configuration(before)
    validate_configuration(proposed)

    if period_status not in ("current", "expired", "unknown"):
        raise ValueError("period_status")

    bounds = envelope["bounds"]
    lower = bounds["retention_min_seconds"]
    upper = bounds["retention_max_seconds"]

    if lower is not None and upper is not None and lower > upper:
        raise ValueError("contradictory_retention_bounds")

    checks = {}

    for field in FIELDS[:-1]:
        value = proposed[field]
        allowed = bounds[field]

        if value is None or allowed is None:
            checks[field] = "U"
        elif field == "recipients":
            checks[field] = (
                "P" if set(value) <= set(allowed) else "F"
            )
        else:
            checks[field] = "P" if value in allowed else "F"

    seconds = proposed["retention_seconds"]

    checks["retention_min_seconds"] = (
        "U" if seconds is None or lower is None
        else "P" if seconds >= lower else "F"
    )
    checks["retention_max_seconds"] = (
        "U" if seconds is None or upper is None
        else "P" if seconds <= upper else "F"
    )

    for position, rule in enumerate(envelope["forbidden_pairs"]):
        purpose = proposed["purpose"]
        recipients = proposed["recipients"]

        known_not_triggered = (
            purpose is not None and purpose != rule["purpose"]
        ) or (
            recipients is not None
            and rule["recipient"] not in recipients
        )

        checks[f"forbidden_pair_position_{position}"] = (
            "P" if known_not_triggered
            else "F" if purpose is not None and recipients is not None
            else "U"
        )

    if not envelope["condition_inventory_complete"]:
        checks["condition_inventory"] = "U"

    if envelope["review_status"] != "established":
        checks = {name: "U" for name in checks}

    scope_state = aggregate(tuple(checks.values()))

    def comparable(field, value):
        if field == "recipients" and value is not None:
            return frozenset(value)
        return value

    changed = {
        field for field in FIELDS
        if comparable(field, before[field])
        != comparable(field, proposed[field])
    }

    affected = impact_closure(changed, envelope["dependencies"])
    dependency_complete = envelope["dependency_inventory_complete"]

    if scope_state == "F":
        outcome = "review_required_beyond_bounds"
    elif period_status == "expired":
        outcome = "review_required_renewal"
    elif (
        scope_state == "U"
        or period_status == "unknown"
        or not dependency_complete
    ):
        outcome = "unknown_unresolved_evidence"
    else:
        outcome = "within_declared_envelope"

    return {
        "schema_version": "1.0.0",
        "outcome_vocabulary_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "outcome": outcome,
        "scope_state": scope_state,
        "period_status": period_status,
        "checks": checks,
        "failed_checks": sorted(k for k, v in checks.items() if v == "F"),
        "unknown_checks": sorted(k for k, v in checks.items() if v == "U"),
        "changed_fields": sorted(changed),
        "affected_claims": sorted(set(CLAIMS) & affected),
        "potentially_affected_claims": (
            [] if dependency_complete
            else sorted(set(CLAIMS) - affected)
        ),
        "envelope_review_origin": "supplied_not_authenticated",
        "historical_acceptance": "not_modified",
        "execution_authorization": "not_evaluated",
        "publication_authorization": "not_evaluated",
    }
