"""Logical replay for one already-accepted milestone event stream.

Python 3.10 or newer; standard library only.

Events must have passed the separate acceptance process.
This module does not authenticate that process or create commitments.
No storage, publication, network access, or actuation is performed here.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


@dataclass(frozen=True)
class Event:
    sequence: int
    kind: str
    expected_revision: int
    previous_text: str
    replacement_text: str
    reason: str
    schema_version: str = "1.0.0"


def replay(events):
    if type(events) is not tuple:
        raise ValueError("events_tuple_required")

    history = []
    text = None
    attribution = "not_recorded"
    review = "not_started"

    for position, event in enumerate(events, 1):
        if type(event) is not Event or event.schema_version != "1.0.0":
            raise ValueError("event_schema")

        if (
            type(event.sequence) is not int
            or type(event.expected_revision) is not int
            or event.sequence != position
            or event.expected_revision != position - 1
        ):
            raise ValueError("event_sequence")

        if (
            any(
                type(value) is not str
                for value in (
                    event.kind,
                    event.previous_text,
                    event.replacement_text,
                    event.reason,
                )
            )
            or not event.reason.strip()
        ):
            raise ValueError("event_text")

        if event.kind == "establish":
            if (
                position != 1
                or event.previous_text != ""
                or not event.replacement_text.strip()
            ):
                raise ValueError("invalid_establishment")

            text = event.replacement_text
            attribution = "accepted_in_record"
            review = "recorded_establishment_basis"

        else:
            if text is None:
                raise ValueError("establishment_required")

            if event.previous_text != text:
                raise ValueError("wording_revision_mismatch")

            if event.kind in {"correct_record", "wording_revision"}:
                if not event.replacement_text.strip():
                    raise ValueError("replacement_required")

                text = event.replacement_text

                if event.kind == "correct_record":
                    attribution = "record_corrected"

            elif event.kind in {"person_change", "material_change"}:
                if event.replacement_text != "":
                    raise ValueError("unexpected_replacement")

            else:
                raise ValueError("unsupported_event_kind")

            review = "current_review_required"

        history.append(event)

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "revision": len(history),
        "historical_acceptance_recorded": bool(history),
        "current_attribution": attribution,
        "current_wording": text,
        "current_review": review,
        "history": tuple(history),
        "authority_verified": False,
        "cryptographic_integrity_verified": False,
        "physical_or_external_action_authorized": False,
    }


def inspect_display(projection, displayed_text):
    if type(displayed_text) is not str:
        raise ValueError("display_text_required")

    if projection["current_wording"] is None:
        return "reference_unavailable"

    if displayed_text == projection["current_wording"]:
        return "matches_replayed_wording"

    return "unexplained_text_mismatch"
