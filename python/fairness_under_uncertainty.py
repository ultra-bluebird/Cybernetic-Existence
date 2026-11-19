from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class AccessPathResult:
    workflow_ref: str
    core_access_available: bool
    accessible_communication_available: bool
    human_fallback_available: bool
    correction_available: bool
    appeal_available: bool
    certification_required: bool
    documentation_required: bool
    identity_inference_used: bool
    person_level_data_used: bool


@dataclass(frozen=True)
class AccessEquivalenceAssessment:
    workflows_assessed: int
    workflows_meeting_equivalence: int
    failing_workflows: tuple[str, ...]
    prohibited_processing_detected: bool


def assess_access_equivalence(
    results: Iterable[AccessPathResult],
) -> AccessEquivalenceAssessment:
    assessed = 0
    meeting_equivalence = 0
    failures: list[str] = []
    prohibited_processing_detected = False

    for result in results:
        assessed += 1

        workflow_is_equivalent = (
            result.core_access_available
            and result.accessible_communication_available
            and result.human_fallback_available
            and result.correction_available
            and result.appeal_available
            and not result.certification_required
            and not result.documentation_required
        )

        if workflow_is_equivalent:
            meeting_equivalence += 1
        else:
            failures.append(result.workflow_ref)

        if result.identity_inference_used or result.person_level_data_used:
            prohibited_processing_detected = True

    return AccessEquivalenceAssessment(
        workflows_assessed=assessed,
        workflows_meeting_equivalence=meeting_equivalence,
        failing_workflows=tuple(failures),
        prohibited_processing_detected=prohibited_processing_detected,
    )
