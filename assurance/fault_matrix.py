"""Deterministic binary fault-campaign generator.

Python 3.10 or newer; standard library only.

Coverage applies to the declared factor model, not to actual fault exercise.
No runtime classifier, external service, or physical system is invoked.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from itertools import combinations, product


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

FACTORS = (
    "undeclared_recipient",
    "hidden_diagnostic_transfer",
    "contradictory_exclusion",
    "expired_review",
    "future_dated_reading",
    "clock_boundary_uncertainty",
    "unit_mismatch",
    "missing_calibration",
    "inaccessible_correction_route",
    "network_failure",
    "historical_reading_shown_current",
    "nondeterministic_mutant",
)


def interactions(row):
    return frozenset(
        (left, right, row[left], row[right])
        for left, right in combinations(range(len(row)), 2)
    )


def generate_matrix(max_simultaneous_faults=3):
    k = len(FACTORS)

    if (
        type(max_simultaneous_faults) is not int
        or not 2 <= max_simultaneous_faults <= k
    ):
        raise ValueError("supported_fault_limit_required")

    candidates = tuple(
        row
        for row in product((0, 1), repeat=k)
        if sum(row) <= max_simultaneous_faults
    )

    coverage = {row: interactions(row) for row in candidates}
    required = set().union(*(coverage[row] for row in candidates))

    selected = [(0,) * k]
    selected.extend(
        tuple(int(position == fault) for position in range(k))
        for fault in range(k)
    )
    selected_set = set(selected)

    covered = set().union(*(coverage[row] for row in selected))
    uncovered = required - covered

    while uncovered:
        remaining = (
            row for row in candidates if row not in selected_set
        )

        # Candidates have stable lexicographic order.
        # max() retains the first row on equal coverage gain.
        best = max(
            remaining,
            key=lambda row: len(coverage[row] & uncovered),
        )

        gain = coverage[best] & uncovered
        if not gain:
            raise RuntimeError("coverage_generation_stalled")

        selected.append(best)
        selected_set.add(best)
        uncovered -= gain

    # Independent direct pair/value verification.
    verified = 0
    for left, right in combinations(range(k), 2):
        for first, second in product((0, 1), repeat=2):
            feasible = any(
                row[left] == first and row[right] == second
                for row in candidates
            )
            if feasible:
                if not any(
                    row[left] == first and row[right] == second
                    for row in selected
                ):
                    raise RuntimeError("pair_coverage_mismatch")
                verified += 1

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "factors": FACTORS,
        "factor_values": {
            "0": "not_injected",
            "1": "requested_injection",
        },
        "maximum_simultaneous_faults": max_simultaneous_faults,
        "candidate_count": len(candidates),
        "suite_count": len(selected),
        "pair_value_combinations_required": len(required),
        "pair_value_combinations_verified": verified,
        "rows": tuple(
            dict(zip(FACTORS, row)) for row in selected
        ),
        "runtime_execution": "not_performed",
        "higher_order_coverage": "not_guaranteed",
        "statistical_frequency_interpretation": "not_applicable",
    }
