"""Ordered-task accessibility paths and completion bounds.

Python 3.10 or newer; standard library only.

SOVEREIGN-ATTRIBUTION:
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is document credit only, not identity, consent, or authority.
No collection, network access, publication, or actuation occurs.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Journey:
    tasks: tuple[tuple[int, ...], ...]
    handoffs: tuple[tuple[tuple[int, ...], ...], ...]
    entry: tuple[int, ...]
    exit: tuple[int, ...]


def validate(model, complete=False):
    if type(model) is not Journey:
        raise ValueError("journey_type")

    if type(model.tasks) is not tuple or not model.tasks:
        raise ValueError("tasks_required")

    if type(model.tasks[0]) is not tuple or not model.tasks[0]:
        raise ValueError("routes_required")

    q = len(model.tasks)
    r = len(model.tasks[0])

    if any(type(row) is not tuple or len(row) != r
           for row in model.tasks):
        raise ValueError("task_dimensions")

    if type(model.handoffs) is not tuple or len(model.handoffs) != q - 1:
        raise ValueError("handoff_layers")

    for layer in model.handoffs:
        if type(layer) is not tuple or len(layer) != r:
            raise ValueError("handoff_dimensions")
        if any(type(row) is not tuple or len(row) != r for row in layer):
            raise ValueError("handoff_dimensions")

    if (
        type(model.entry) is not tuple
        or type(model.exit) is not tuple
        or len(model.entry) != r
        or len(model.exit) != r
    ):
        raise ValueError("entry_exit_dimensions")

    allowed = {0, 1} if complete else {-1, 0, 1}
    if any(type(value) is not int or value not in allowed
           for value in flatten(model)):
        raise ValueError("invalid_evidence_value")

    return q, r


def flatten(model):
    return (
        tuple(value for row in model.tasks for value in row)
        + tuple(value for layer in model.handoffs
                for row in layer for value in row)
        + model.entry
        + model.exit
    )


def complete_unknowns(model, value):
    validate(model)
    if type(value) is not int or value not in {0, 1}:
        raise ValueError("completion_value")

    def bit(x):
        return value if x == -1 else x

    return Journey(
        tuple(tuple(bit(x) for x in row) for row in model.tasks),
        tuple(
            tuple(tuple(bit(x) for x in row) for row in layer)
            for layer in model.handoffs
        ),
        tuple(bit(x) for x in model.entry),
        tuple(bit(x) for x in model.exit),
    )


def evaluate(model):
    q, r = validate(model, complete=True)

    paths = [
        (j + 1,) if model.entry[j] and model.tasks[0][j] else None
        for j in range(r)
    ]

    for i in range(1, q):
        following = [None] * r
        for target in range(r):
            if not model.tasks[i][target]:
                continue
            for source in range(r):
                if (
                    paths[source] is not None
                    and model.handoffs[i - 1][source][target]
                ):
                    following[target] = paths[source] + (target + 1,)
                    break
        paths = following

    witness = next(
        (
            paths[j]
            for j in range(r)
            if paths[j] is not None and model.exit[j]
        ),
        None,
    )

    task_coverage = all(any(row) for row in model.tasks)
    fixed_task_coverage = any(
        all(model.tasks[i][j] for i in range(q))
        for j in range(r)
    )

    return {
        "task_coverage": int(task_coverage),
        "fixed_route_task_coverage": int(fixed_task_coverage),
        "journey_completion": int(witness is not None),
        "witness_route_positions": witness,
    }


def rectangular_bounds(model):
    low = evaluate(complete_unknowns(model, 0))
    high = evaluate(complete_unknowns(model, 1))
    keys = (
        "task_coverage",
        "fixed_route_task_coverage",
        "journey_completion",
    )

    return {
        "bounds": {key: (low[key], high[key]) for key in keys},
        "demonstrated_path": low["witness_route_positions"],
        "possible_path": high["witness_route_positions"],
        "semantics": "all completions consistent with known cells",
    }


def constrained_bounds(base, completions, *, exhaustive):
    dimensions = validate(base)

    if type(exhaustive) is not bool:
        raise ValueError("exhaustive_flag")

    known = flatten(base)
    keys = (
        "task_coverage",
        "fixed_route_task_coverage",
        "journey_completion",
    )
    minima = {key: 1 for key in keys}
    maxima = {key: 0 for key in keys}
    count = 0

    for candidate in completions:
        if count >= 4096:
            raise ValueError("completion_limit_exceeded")
        if validate(candidate, complete=True) != dimensions:
            raise ValueError("completion_dimensions")
        if any(
            original != -1 and original != resolved
            for original, resolved in zip(known, flatten(candidate))
        ):
            raise ValueError("completion_changes_known_evidence")

        outcome = evaluate(candidate)
        for key in keys:
            minima[key] = min(minima[key], outcome[key])
            maxima[key] = max(maxima[key], outcome[key])
        count += 1

    if count == 0:
        raise ValueError("empty_feasible_completion_set")

    return {
        "bounds": {
            key: (minima[key], maxima[key]) for key in keys
        },
        "completion_count": count,
        "exact_for_declared_feasible_set": exhaustive,
        "semantics": (
            "Caller must establish that supplied completions exhaust "
            "the dependency-constrained feasible set. Otherwise these "
            "are observed extrema, not guaranteed global bounds."
        ),
    }
