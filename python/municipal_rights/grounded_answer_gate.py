from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Sequence
import re


@dataclass(frozen=True)
class SourcePassage:
    source_title: str
    official_url: str
    jurisdiction: str
    section_label: str
    text: str
    effective_from: date | None
    effective_to: date | None
    reviewed_on: date
    primary_source: bool


@dataclass(frozen=True)
class CandidateClaim:
    text: str
    jurisdiction: str
    legal_topic: str
    source_index: int


@dataclass(frozen=True)
class Citation:
    source_title: str
    official_url: str
    section_label: str


@dataclass(frozen=True)
class GateDecision:
    accepted: bool
    citation: Citation | None
    reason: str


class GroundedAnswerGate:
    def evaluate(
        self,
        claim: CandidateClaim,
        sources: Sequence[SourcePassage],
        on_date: date,
    ) -> GateDecision:
        if not claim.text.strip():
            return GateDecision(False, None, "The candidate claim is empty.")

        if not 0 <= claim.source_index < len(sources):
            return GateDecision(False, None, "The claim has no resolved source passage.")

        source = sources[claim.source_index]

        if not source.primary_source:
            return GateDecision(
                False,
                None,
                "The source is not an approved primary municipal, statutory, regulatory, or court source.",
            )

        if source.jurisdiction.casefold() != claim.jurisdiction.casefold():
            return GateDecision(
                False,
                None,
                "The source jurisdiction does not match the claim jurisdiction.",
            )

        if source.effective_from is not None and source.effective_from > on_date:
            return GateDecision(
                False,
                None,
                "The source is not yet effective on the requested date.",
            )

        if source.effective_to is not None and source.effective_to < on_date:
            return GateDecision(
                False,
                None,
                "The source is no longer effective on the requested date.",
            )

        if not self._has_material_overlap(claim.text, source.text):
            return GateDecision(
                False,
                None,
                "The cited passage does not contain enough matching legal content to support the claim.",
            )

        if self._contains_outcome_prediction(claim.text):
            return GateDecision(
                False,
                None,
                "The system does not publish legal-outcome predictions.",
            )

        return GateDecision(
            True,
            Citation(
                source_title=source.source_title,
                official_url=source.official_url,
                section_label=source.section_label,
            ),
            "The claim has a jurisdiction-matched, effective primary source and a citation.",
        )

    @staticmethod
    def _has_material_overlap(claim_text: str, source_text: str) -> bool:
        claim_terms = GroundedAnswerGate._meaningful_terms(claim_text)
        source_terms = GroundedAnswerGate._meaningful_terms(source_text)

        if len(claim_terms) < 3 or not source_terms:
            return False

        overlap = claim_terms.intersection(source_terms)
        return len(overlap) / len(claim_terms) >= 0.45

    @staticmethod
    def _contains_outcome_prediction(claim_text: str) -> bool:
        prohibited_patterns = (
            r"\byou will win\b",
            r"\bguaranteed\b",
            r"\bcertainly succeed\b",
            r"\bmust pay you\b",
            r"\byou will receive\b",
        )
        normalized = claim_text.casefold()
        return any(re.search(pattern, normalized) for pattern in prohibited_patterns)

    @staticmethod
    def _meaningful_terms(text: str) -> set[str]:
        stop_words = {
            "a", "an", "and", "are", "as", "at", "be", "by", "for",
            "from", "in", "is", "it", "of", "on", "or", "that", "the",
            "to", "with", "you", "your",
        }
        tokens = re.findall(r"[a-zA-Z]{3,}", text.casefold())
        return {token for token in tokens if token not in stop_words}
