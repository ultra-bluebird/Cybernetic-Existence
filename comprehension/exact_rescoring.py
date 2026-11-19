# SPDX-License-Identifier: MIT OR Apache-2.0
"""Exact five-task arithmetic and immutable rubric-based recoding."""

from fractions import Fraction


ENGINE_VERSION = "1.0.0"
TASKS = ("meaning", "derived", "inference", "consent", "correction")
CATEGORIES = ("correct", "incorrect", "explicit_uncertainty", "missing")
MAX_COUNT = 2**53 - 1


def validate_cell(cell):
    expected = {"assigned", "rubric_revision", *CATEGORIES}
    if type(cell) is not dict or set(cell) != expected:
        raise ValueError("unsupported cell fields")

    rubric = cell["rubric_revision"]
    if (
        type(rubric) is not str
        or not 1 <= len(rubric) <= 128
        or rubric != rubric.strip()
    ):
        raise ValueError("invalid rubric revision")

    for name in ("assigned", *CATEGORIES):
        value = cell[name]
        if type(value) is not int or not 0 <= value <= MAX_COUNT:
            raise ValueError("invalid count")

    if sum(cell[name] for name in CATEGORIES) != cell["assigned"]:
        raise ValueError("partition mismatch")


def ratio(numerator, denominator):
    if type(numerator) is not int or type(denominator) is not int:
        raise ValueError("plain integer ratio inputs required")
    if not 0 <= numerator <= denominator <= MAX_COUNT:
        raise ValueError("invalid bounded proportion")
    if denominator == 0:
        return {"status": "undefined", "value": None}
    value = Fraction(numerator, denominator)
    return {
        "status": "defined",
        "value": {
            "numerator": value.numerator,
            "denominator": value.denominator,
        },
    }


def summarize(tasks):
    if type(tasks) is not dict or set(tasks) != set(TASKS):
        raise ValueError("exact task set required")

    result = {}
    for task in TASKS:
        cell = tasks[task]
        validate_cell(cell)
        scorable = cell["correct"] + cell["incorrect"]
        result[task] = {
            "counts": dict(cell),
            "correct_rate": ratio(cell["correct"], scorable),
            "scorable_coverage": ratio(scorable, cell["assigned"]),
        }
    return result


def rescore(cell, source, destination, amount, new_rubric):
    """Return a revised cell; preserve the original and its assignment count."""
    validate_cell(cell)
    if (
        type(source) is not str
        or type(destination) is not str
        or source not in CATEGORIES
        or destination not in CATEGORIES
        or source == destination
    ):
        raise ValueError("unsupported recoding categories")
    if type(amount) is not int or not 1 <= amount <= cell[source]:
        raise ValueError("invalid recoding amount")
    if new_rubric == cell["rubric_revision"]:
        raise ValueError("new rubric revision required")

    result = dict(cell)
    result[source] -= amount
    result[destination] += amount
    result["rubric_revision"] = new_rubric
    validate_cell(result)
    return result
