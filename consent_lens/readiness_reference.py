"""Deterministic six-prerequisite decision reference.

Python 3.10 or newer; standard library only.

This is a syntactic decision-reference domain, not observed data.
Enumeration does not assert independence, probability, or reachability.

Excluded:
applicability decisions, retirement, history, conflict adjudication,
freshness evaluation, publication authorization, and journey composition.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

import csv
import io
from itertools import product


SCHEMA_VERSION = "2.0.0"
POLICY_REVISION = "readiness-reference-2"
ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

CHECKS = (
    "schema_compatibility",
    "replay_consistency",
    "processing_scope",
    "requirement_support",
    "access_claim_fidelity",
    "explanation_fidelity",
)

# Serialization order only; not assurance or information order.
STATES = ("pass", "fail", "unknown")

COLUMNS = (
    "schema_version",
    "policy_revision",
    "attribution",
    *CHECKS,
    "vector_base3",
    "passed_count",
    "failed_count",
    "unknown_count",
    "failed_mask",
    "unknown_mask",
    "all_checks_pass",
    "reason_code",
    "display_key",
    "count_identity_holds",
)


def classify(vector):
    """Classify exactly six named-state values; establish no authority."""
    if type(vector) is not tuple or len(vector) != len(CHECKS):
        raise ValueError("six_state_tuple_required")

    if any(type(state) is not str or state not in STATES
           for state in vector):
        raise ValueError("unsupported_state")

    passed = vector.count("pass")
    failed = vector.count("fail")
    unknown = vector.count("unknown")

    if failed:
        reason = "failed_present"
    elif unknown:
        reason = "evidence_incomplete"
    else:
        reason = "all_checks_pass"

    encoded = sum(
        STATES.index(state) * 3 ** (len(CHECKS) - 1 - position)
        for position, state in enumerate(vector)
    )

    failed_mask = sum(
        1 << position
        for position, state in enumerate(vector)
        if state == "fail"
    )
    unknown_mask = sum(
        1 << position
        for position, state in enumerate(vector)
        if state == "unknown"
    )

    return {
        "vector_base3": encoded,
        "passed_count": passed,
        "failed_count": failed,
        "unknown_count": unknown,
        "failed_mask": failed_mask,
        "unknown_mask": unknown_mask,
        "all_checks_pass": int(passed == len(CHECKS)),
        "reason_code": reason,
        "display_key": "readiness." + reason,
        "count_identity_holds": int(
            passed + failed + unknown == len(CHECKS)
        ),
    }


def reference_rows():
    """Yield every syntactically valid vector in declared order."""
    for vector in product(STATES, repeat=len(CHECKS)):
        yield {
            "schema_version": SCHEMA_VERSION,
            "policy_revision": POLICY_REVISION,
            "attribution": ATTRIBUTION,
            **dict(zip(CHECKS, vector)),
            **classify(vector),
        }


def reference_csv_bytes():
    """Return deterministic UTF-8 CSV with CRLF records."""
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(
        stream,
        fieldnames=COLUMNS,
        lineterminator="\r\n",
        quoting=csv.QUOTE_MINIMAL,
    )
    writer.writeheader()
    writer.writerows(reference_rows())
    return stream.getvalue().encode("utf-8")


def verify_reference():
    """Check serialization and independently derived row properties."""
    first = reference_csv_bytes()
    second = reference_csv_bytes()

    if first != second:
        raise RuntimeError("nondeterministic_serialization")

    reader = csv.DictReader(
        io.StringIO(first.decode("utf-8"), newline="")
    )
    if tuple(reader.fieldnames or ()) != COLUMNS:
        raise RuntimeError("column_mismatch")

    rows = list(reader)
    if len(rows) != len(STATES) ** len(CHECKS):
        raise RuntimeError("row_count_mismatch")

    encodings = set()
    all_pass_rows = 0

    for row in rows:
        vector = tuple(row[name] for name in CHECKS)
        expected = classify(vector)

        for key, value in expected.items():
            if row[key] != str(value):
                raise RuntimeError(
                    f"derived_field_mismatch:{row['vector_base3']}:{key}"
                )

        # Independent all-pass comparison through failure-dominant ranking.
        rank = {"fail": 0, "unknown": 1, "pass": 2}
        independently_all_pass = int(
            min(rank[state] for state in vector) == rank["pass"]
        )
        if int(row["all_checks_pass"]) != independently_all_pass:
            raise RuntimeError("classifier_disagreement")

        encodings.add(int(row["vector_base3"]))
        all_pass_rows += independently_all_pass

    if encodings != set(range(len(rows))):
        raise RuntimeError("encoding_coverage_mismatch")

    return {
        "schema_version": SCHEMA_VERSION,
        "policy_revision": POLICY_REVISION,
        "attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "row_count": len(rows),
        "column_count": len(COLUMNS),
        "byte_count": len(first),
        "all_pass_rows": all_pass_rows,
        "byte_identical_regeneration": True,
        "role": "decision_reference_not_measurement",
        "authorization_evaluated": False,
        "cryptographic_commitment_created": False,
    }
