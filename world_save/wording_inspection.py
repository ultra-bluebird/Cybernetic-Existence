"""Compare a designated display string with a freshly replayed history.

Python 3.10 or newer; standard library only.
Depends on the project-local correction_replay module.

No storage, publication, network access, or actuation occurs here.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from research.world_save.correction_replay import replay


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


def inspect_history(events, displayed_text):
    """Replay first; reject invalid history rather than compare against it."""
    if type(displayed_text) is not str:
        raise ValueError("display_text_required")

    projection = replay(events)
    reference = projection["current_wording"]

    if reference is None:
        outcome = "reference_unavailable"
    elif displayed_text == reference:
        outcome = "matches_replayed_wording"
    else:
        outcome = "unexplained_text_mismatch"

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "comparison_outcome": outcome,
        "supplied_history_revision": projection["revision"],
        "historical_acceptance_recorded":
            projection["historical_acceptance_recorded"],
        "current_attribution": projection["current_attribution"],
        "current_review": projection["current_review"],
        "reference_source": "fresh_replay_of_supplied_history",
        "history_completeness_established": False,
        "accepted_origin_authenticated": False,
        "cryptographic_integrity_verified": False,
        "semantic_equivalence_verified": False,
        "accessible_rendering_verified": False,
        "real_world_milestone_established": False,
        "external_action_authorized": False,
    }
