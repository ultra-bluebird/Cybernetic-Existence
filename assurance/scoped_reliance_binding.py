# SPDX-License-Identifier: MIT OR Apache-2.0
"""Exact-scope reliance review. No authentication or external authority."""

from dataclasses import dataclass
from datetime import datetime
from enum import Enum


ENGINE_VERSION = "2.0.0"


class State(Enum):
    PENDING = "pending"
    SUPPORTED = "supported"
    NOT_SUPPORTED = "not_supported"


class Trigger(Enum):
    ABSENT = "absent"
    PRESENT = "present"
    UNRESOLVED = "unresolved"


@dataclass(frozen=True)
class Scope:
    historical_implementation: str
    historical_version: str
    historical_domain: str
    historical_property: str
    historical_execution_at: datetime | None
    proposed_version: str
    proposed_domain: str
    proposed_property: str
    proposed_use: str
    material_revision: int
    correction_revision: int
    trigger: Trigger


@dataclass(frozen=True)
class Review:
    scope: Scope
    category: str
    state: State
    reviewer_role: str
    reviewed_at: datetime


def assess(scope, reviews, as_of):
    """Assess declarations; never infer actual review or execution authority."""
    if (
        type(scope) is not Scope
        or type(reviews) is not tuple
        or type(as_of) is not datetime
        or as_of.utcoffset() is None
    ):
        raise ValueError("typed scope, tuple, and aware clock required")

    if type(scope.trigger) is not Trigger:
        raise ValueError("typed correction trigger required")

    for name in ("material_revision", "correction_revision"):
        value = getattr(scope, name)
        if type(value) is not int or value < 0:
            raise ValueError("nonnegative scope revisions required")

    for name in (
        "historical_implementation",
        "historical_version",
        "historical_domain",
        "historical_property",
        "proposed_version",
        "proposed_domain",
        "proposed_property",
        "proposed_use",
    ):
        value = getattr(scope, name)
        if (
            type(value) is not str
            or not 1 <= len(value) <= 256
            or value != value.strip()
            or any(ord(char) < 32 or ord(char) == 127 for char in value)
        ):
            raise ValueError("bounded scope text required")

    unresolved = []
    unsupported = []
    seen = {}

    execution_at = scope.historical_execution_at
    if execution_at is None:
        unresolved.append("historical_execution_time_unavailable")
    elif (
        type(execution_at) is not datetime
        or execution_at.utcoffset() is None
        or execution_at > as_of
    ):
        raise ValueError("invalid historical execution time")

    categories = ("applicability", "material_change", "downstream")
    for review in reviews:
        if (
            type(review) is not Review
            or review.category not in categories
            or type(review.state) is not State
        ):
            raise ValueError("invalid review")

        if review.category in seen:
            raise ValueError("multiple candidate reviews require reconciliation")
        seen[review.category] = review

        if (
            type(review.reviewer_role) is not str
            or not review.reviewer_role.strip()
        ):
            raise ValueError("reviewer role required")

        if (
            type(review.reviewed_at) is not datetime
            or review.reviewed_at.utcoffset() is None
            or review.reviewed_at > as_of
        ):
            raise ValueError("invalid review time")

    required = ["applicability", "material_change"]
    if scope.trigger is Trigger.PRESENT:
        required.append("downstream")
    elif scope.trigger is Trigger.UNRESOLVED:
        unresolved.append("correction_trigger_unresolved")

    for category in required:
        review = seen.get(category)
        if review is None:
            unresolved.append(category + "_review_absent")
        elif review.scope != scope:
            unresolved.append(category + "_review_scope_mismatch")
        elif (
            execution_at is not None
            and review.reviewed_at < execution_at
        ):
            unresolved.append(category + "_review_predates_execution")
        elif review.state is State.NOT_SUPPORTED:
            unsupported.append(category)
        elif review.state is State.PENDING:
            unresolved.append(category + "_review_pending")

    if unsupported:
        disposition = "proposed_reliance_not_supported"
    elif unresolved:
        disposition = "proposed_reliance_review_incomplete"
    else:
        disposition = (
            "bound_review_records_present_substance_not_authenticated"
        )

    return {
        "engine_version": ENGINE_VERSION,
        "disposition": disposition,
        "unsupported": unsupported,
        "unresolved": unresolved,
        "history_rewritten": False,
        "ordinary_support": "not_conditioned_on_assessment",
        "external_action_authorized": False,
    }
