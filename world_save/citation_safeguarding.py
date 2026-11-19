"""Triage supplied milestone-citation review records.

Python 3.10 or newer; standard library only.

This is not an NLP detector, coercion adjudicator, authorization service,
or monitoring system. Input evidence states require separate review.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


@dataclass(frozen=True)
class CitationReview:
    citation_use: str
    specific_authorization: str
    pressure_evidence: str


def assess_citation(review):
    if type(review) is not CitationReview:
        raise TypeError("citation_review_required")

    uses = {
        "historical_context": "F",
        "claimed_execution_authority": "P",
        "unresolved": "U",
    }

    if (
        type(review.citation_use) is not str
        or review.citation_use not in uses
    ):
        raise ValueError("citation_use")

    if any(
        type(value) is not str or value not in {"P", "F", "U"}
        for value in (
            review.specific_authorization,
            review.pressure_evidence,
        )
    ):
        raise ValueError("evidence_state")

    misuse = uses[review.citation_use]
    signals = (misuse, review.pressure_evidence)

    concern = (
        "P" if "P" in signals
        else "U" if "U" in signals
        else "F"
    )

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "authority_inheritance_misuse": misuse,
        "pressure_evidence": review.pressure_evidence,
        "safeguarding_review_signal": concern,
        "specific_authorization": review.specific_authorization,
        "person_level_coercion_finding": "not_determined",
        "execution_authorization": "not_evaluated",
    }
