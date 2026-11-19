"""Bounded same-language comparison against a supplied-history replay.

Python 3.10 or newer; standard library plus project-local replay module.

Exact policy:
No trimming, normalization, case folding, newline conversion,
or directionality-character removal.

Limits apply to this adapter, not to the surrounding storage system.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from research.world_save.correction_replay import Event, replay


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

PROFILE = "exact-wording-local-2"
MAX_EVENTS = 256
MAX_FIELD_UTF8_BYTES = 16384
MAX_TOTAL_UTF8_BYTES = 1048576

START_KIND = "establish"
SUFFIX_KINDS = frozenset({
    "wording_revision",
    "correct_record",
    "person_change",
    "material_change",
})

KNOWN_REPLAY_REJECTIONS = frozenset({
    "events_tuple_required",
    "event_schema",
    "event_sequence",
    "event_text",
    "invalid_establishment",
    "establishment_required",
    "wording_revision_mismatch",
    "replacement_required",
    "unexpected_replacement",
    "unsupported_event_kind",
})


class ComparisonInputError(ValueError):
    pass


class HistoryLimitError(ComparisonInputError):
    pass


class ReplayContractError(RuntimeError):
    pass


def checked_text(value, name):
    if type(value) is not str:
        raise ComparisonInputError(f"{name}: string required")
    try:
        size = len(value.encode("utf-8", errors="strict"))
    except UnicodeEncodeError as error:
        raise ComparisonInputError(
            f"{name}: invalid Unicode scalar sequence"
        ) from error

    if size > MAX_FIELD_UTF8_BYTES:
        raise HistoryLimitError(f"{name}: field limit exceeded")
    return size


def snapshot_inputs(events, displayed_text, reference_language, display_language):
    if type(events) is not tuple:
        raise ComparisonInputError("events: tuple required")
    if len(events) > MAX_EVENTS:
        raise HistoryLimitError("event count limit exceeded")

    total = checked_text(displayed_text, "displayed_text")
    total += checked_text(reference_language, "reference_language")
    total += checked_text(display_language, "display_language")

    if not reference_language.strip() or not display_language.strip():
        raise ComparisonInputError("language labels must be nonblank")

    copied = []

    for event in events:
        if type(event) is not Event:
            raise ComparisonInputError("event: exact Event type required")

        text_values = (
            event.kind,
            event.previous_text,
            event.replacement_text,
            event.reason,
            event.schema_version,
        )
        for value in text_values:
            total += checked_text(value, "event field")

        if (
            type(event.sequence) is not int
            or type(event.expected_revision) is not int
        ):
            raise ComparisonInputError("event revisions must be integers")

        if total > MAX_TOTAL_UTF8_BYTES:
            raise HistoryLimitError("aggregate text limit exceeded")

        copied.append(Event(
            sequence=event.sequence,
            kind=event.kind,
            expected_revision=event.expected_revision,
            previous_text=event.previous_text,
            replacement_text=event.replacement_text,
            reason=event.reason,
            schema_version=event.schema_version,
        ))

    return tuple(copied)


def validate_projection(projection, events):
    if type(projection) is not dict:
        raise ReplayContractError("projection must be a dictionary")

    required = {
        "schema_version",
        "revision",
        "historical_acceptance_recorded",
        "current_attribution",
        "current_wording",
        "current_review",
        "history",
    }
    if not required <= projection.keys():
        raise ReplayContractError("projection fields missing")

    if projection["schema_version"] != "1.0.0":
        raise ReplayContractError("unsupported replay projection schema")

    if (
        type(projection["revision"]) is not int
        or projection["revision"] != len(events)
        or type(projection["historical_acceptance_recorded"]) is not bool
        or projection["historical_acceptance_recorded"] != bool(events)
        or type(projection["history"]) is not tuple
        or projection["history"] != events
    ):
        raise ReplayContractError("projection/history disagreement")

    reference = projection["current_wording"]

    if not events:
        if reference is not None:
            raise ReplayContractError("empty history has unexpected wording")
    elif type(reference) is not str or not reference.strip():
        raise ReplayContractError("nonempty history has invalid wording")

    if projection["current_attribution"] not in {
        "not_recorded", "accepted_in_record", "record_corrected"
    }:
        raise ReplayContractError("unsupported attribution state")

    if projection["current_review"] not in {
        "not_started",
        "recorded_establishment_basis",
        "current_review_required",
    }:
        raise ReplayContractError("unsupported review state")


def inspect_history(
    events,
    displayed_text,
    *,
    reference_language,
    display_language,
):
    copied = snapshot_inputs(
        events, displayed_text, reference_language, display_language
    )

    result = {
        "schema_version": "2.0.0",
        "comparison_profile": PROFILE,
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "reference_language": reference_language,
        "display_language": display_language,
        "portable_event_commitment": "not_created",
        "reference_selection": "supplied_not_authenticated",
    }

    try:
        projection = replay(copied)
    except ValueError as error:
        code = str(error)
        if code not in KNOWN_REPLAY_REJECTIONS:
            raise ReplayContractError(
                "unrecognized replay rejection"
            ) from error
        return {
            **result,
            "comparison_outcome": "replay_rejected",
            "reason_code": code,
        }

    validate_projection(projection, copied)
    reference = projection["current_wording"]

    if reference is None:
        outcome = "reference_unavailable"
        reason = (
            "display_text_without_replay_reference"
            if displayed_text != ""
            else "both_reference_and_display_absent"
        )
    elif reference_language != display_language:
        outcome = "comparison_not_applicable"
        reason = "language_reference_mismatch"
    elif displayed_text == reference:
        outcome = "matches_replayed_wording"
        reason = "exact_codepoint_sequence_match"
    else:
        outcome = "unexplained_text_mismatch"
        reason = "different_codepoint_sequence"

    return {
        **result,
        "comparison_outcome": outcome,
        "reason_code": reason,
        "supplied_history_revision": projection["revision"],
        "historical_acceptance_recorded":
            projection["historical_acceptance_recorded"],
        "current_attribution": projection["current_attribution"],
        "current_review": projection["current_review"],
    }
