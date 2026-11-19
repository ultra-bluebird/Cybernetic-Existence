"""Joint resource coverage for one declared planning period.

Python 3.10 or newer.
Dependencies: numpy, scipy.

All resource pools and obligations use the same declared workload unit.
Work is divisible across eligible pools; scheduling is not modeled.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

import numpy as np
from scipy.optimize import linprog


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
TOLERANCE = 1e-7


def validate_intervals(values, name):
    raw = np.asarray(values)

    if raw.dtype.kind not in "iuf":
        raise ValueError(f"{name}: numeric intervals required")

    array = np.asarray(values, dtype=float)

    if (
        array.ndim != 2
        or array.shape[1] != 2
        or not 1 <= array.shape[0] <= 64
        or not np.all(np.isfinite(array))
        or np.any(array < 0)
        or np.any(array > 1_000_000)
        or np.any(array[:, 0] > array[:, 1])
    ):
        raise ValueError(f"{name}: unsupported interval model")

    return array


def allocation_test(capacity, demand, eligible):
    pairs = np.argwhere(eligible)

    if len(pairs) == 0:
        return {
            "state": "P" if np.all(demand == 0) else "F",
            "reason": "no_eligible_allocation_edges",
        }

    pool_count = len(capacity)
    obligation_count = len(demand)

    matrix = np.zeros((
        pool_count + obligation_count,
        len(pairs),
    ))

    for column, (pool, obligation) in enumerate(pairs):
        matrix[pool, column] = 1
        matrix[pool_count + obligation, column] = -1

    limits = np.concatenate((capacity, -demand))

    fit = linprog(
        np.zeros(len(pairs)),
        A_ub=matrix,
        b_ub=limits,
        bounds=(0, None),
        method="highs",
        options={"time_limit": 10.0},
    )

    if fit.success:
        residual = float(np.max(matrix @ fit.x - limits))
        negative = float(max(0.0, -np.min(fit.x)))

        if residual > TOLERANCE or negative > TOLERANCE:
            return {
                "state": "U",
                "reason": "solution_residual_exceeded_tolerance",
            }

        return {
            "state": "P",
            "reason": "numerically_feasible",
            "maximum_constraint_residual": residual,
        }

    if fit.status == 2:
        return {
            "state": "F",
            "reason": "solver_reports_infeasible",
        }

    return {
        "state": "U",
        "reason": "solver_did_not_establish_feasibility_or_infeasibility",
    }


def review_shared_capacity(capacity_bounds, demand_bounds, eligible, *, unit):
    capacity = validate_intervals(capacity_bounds, "capacity")
    demand = validate_intervals(demand_bounds, "demand")

    permitted = np.asarray(eligible)
    if (
        permitted.dtype.kind != "b"
        or permitted.shape != (len(capacity), len(demand))
    ):
        raise ValueError("eligibility must be a matching Boolean matrix")

    if type(unit) is not str or not unit.strip():
        raise ValueError("declared_workload_unit_required")

    conservative = allocation_test(
        capacity[:, 0], demand[:, 1], permitted
    )
    optimistic = allocation_test(
        capacity[:, 1], demand[:, 0], permitted
    )

    if conservative["state"] == "P" and optimistic["state"] == "F":
        state = "U"
        reason = "inconsistent_solver_results_require_review"
    elif conservative["state"] == "P":
        state = "P"
        reason = "conservative_allocation_supported"
    elif optimistic["state"] == "F":
        state = "F"
        reason = "optimistic_allocation_infeasible"
    else:
        state = "U"
        reason = "coverage_depends_on_unresolved_capacity_or_workload"

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "unit": unit,
        "joint_resource_result": state,
        "reason": reason,
        "conservative_test": conservative,
        "optimistic_test": optimistic,
        "pool_distinctness": "supplied_not_verified",
        "eligibility_basis": "supplied_not_verified",
        "schedule_and_queue_deadlines": "not_evaluated",
        "successor_acceptance": "not_evaluated",
        "existing_obligations": "not_modified",
    }
