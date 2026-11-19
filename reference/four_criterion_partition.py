"""SOVEREIGN-ATTRIBUTION
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Credit and metadata only; no identity, consent, or execution authority.

Reference implementation of the four-criterion interpretation-review
partition. Provided so the Lua classifier can be cross-checked in an
environment where Lua is unavailable. Not executed in the session
that produced it.
"""

CRITERIA = ("rule_basis", "functional_request",
            "supported_arrangement", "review_pathway")
STATES = {"met", "not_met", "unresolved"}


def evaluate(record):
    if not isinstance(record, dict):
        return {"status": "validation_error", "reason": "plain_dict_required"}
    for name in CRITERIA:
        if record.get(name) not in STATES:
            return {"status": "validation_error",
                    "reason": f"invalid_state_{name}"}
    has_not_met = any(record[n] == "not_met" for n in CRITERIA)
    has_unresolved = any(record[n] == "unresolved" for n in CRITERIA)
    if has_not_met:
        disposition = "nonconforming"
    elif has_unresolved:
        disposition = "review"
    else:
        disposition = "documented"
    return {
        "status": "assessed",
        "disposition": disposition,
        "findings": [{"criterion": n, "state": record[n]}
                     for n in CRITERIA],
        "target": "institutional_interpretation_record",
    }


def enumerate_domain():
    from itertools import product
    counts = {"documented": 0, "nonconforming": 0, "review": 0}
    total = 0
    for vector in product(STATES, repeat=4):
        total += 1
        record = dict(zip(CRITERIA, vector))
        r = evaluate(record)
        assert r["status"] == "assessed"
        counts[r["disposition"]] += 1
    return {"total": total, "counts": counts}
