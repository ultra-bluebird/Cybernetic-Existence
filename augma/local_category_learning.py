# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local category signal preparation; public release intentionally disabled."""

from dataclasses import dataclass
from enum import Enum
from fractions import Fraction


ENGINE_VERSION = "1.0.0"

CATEGORIES = (
    "direct_aid",
    "capability",
    "public_commons",
    "cultural",
    "environmental",
    "epistemic",
    "relational",
    "locally_defined",
)


class Response(Enum):
    SELECTED = "selected"
    NO_CATEGORY_SELECTED = "no_category_selected"
    PREFER_NOT_TO_SHARE = "prefer_not_to_share"


@dataclass(frozen=True)
class LocalSelection:
    state: Response
    categories: frozenset[str]
    private_local_wording: str | None = None


def local_signal(selection, explicit_share_choice):
    """Prepare an in-memory candidate, never a transmission or publication.

    A participant-period contribution bound requires a separate reviewed
    intake/accounting workflow. This function does not establish uniqueness.
    """
    if type(selection) is not LocalSelection:
        raise ValueError("typed local selection required")
    if type(selection.state) is not Response:
        raise ValueError("typed response state required")
    if type(selection.categories) is not frozenset:
        raise ValueError("immutable category set required")
    if any(
        type(value) is not str or value not in CATEGORIES
        for value in selection.categories
    ):
        raise ValueError("unsupported categories")
    if (
        selection.private_local_wording is not None
        and type(selection.private_local_wording) is not str
    ):
        raise ValueError("private wording must be plain text")
    if type(explicit_share_choice) is not bool:
        raise ValueError("explicit Boolean share choice required")

    if selection.state is Response.SELECTED and not selection.categories:
        raise ValueError("selected response requires categories")
    if selection.state is not Response.SELECTED and selection.categories:
        raise ValueError("nonselected response must not contain categories")

    if (
        not explicit_share_choice
        or selection.state is Response.PREFER_NOT_TO_SHARE
    ):
        return {
            "status": "no_signal",
            "vector": None,
            "publication_authority": False,
        }

    if selection.state is Response.NO_CATEGORY_SELECTED:
        return {
            "status": "no_category_selected",
            "vector": None,
            "publication_authority": False,
        }

    weight = Fraction(1, len(selection.categories))
    vector = tuple(
        weight if category in selection.categories else Fraction(0)
        for category in CATEGORIES
    )
    return {
        "status": "private_summary_candidate",
        "vector": vector,
        "publication_authority": False,
    }


def public_release_decision():
    """A deliberate disabled capability, not an implemented privacy mechanism."""
    return {
        "engine_version": ENGINE_VERSION,
        "status": "release_disabled",
        "secure_aggregation": "not_implemented",
        "differential_privacy": "not_implemented",
        "reason": (
            "No reviewed public-release mechanism or privacy accounting "
            "is implemented."
        ),
    }
