from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


@dataclass(frozen=True)
class WorkflowEvidence:
    workflow_ref: str
    core_access_available: bool
    accessible_interaction_available: bool
    correction_available: bool
    appeal_available: bool
    human_fallback_available: bool
    provenance_complete: bool
    identity_inference_used: bool = False
    person_level_data_used: bool = False
    external_action_authorized: bool = False


@dataclass(frozen=True)
class AccessEquivalenceResult:
    workflow_ref: str
    meets_access_equivalence: bool
    reportable: bool
    reasons: tuple[str, ...]


@dataclass(frozen=True)
class ServiceFairnessAssessment:
    workflows_assessed: int
    workflows_meeting_access_equivalence: int
    reportable_workflows: int
    prohibited_processing_detected: bool


def evaluate_workflow(
    evidence: WorkflowEvidence,
) -> AccessEquivalenceResult:
    reasons: list[str] = []

    if not evidence.provenance_complete:
        reasons.append("MISSING_PROVENANCE")

    if evidence.identity_inference_used:
        reasons.append("IDENTITY_INFERENCE_PROHIBITED")

    if evidence.person_level_data_used:
        reasons.append("PERSON_LEVEL_DATA_PROHIBITED")

    if evidence.external_action_authorized:
        reasons.append("EXTERNAL_ACTION_AUTHORIZATION_PROHIBITED")

    meets_access_equivalence = (
        evidence.core_access_available
        and evidence.accessible_interaction_available
        and evidence.correction_available
        and evidence.appeal_available
        and evidence.human_fallback_available
    )

    return AccessEquivalenceResult(
        workflow_ref=evidence.workflow_ref,
        meets_access_equivalence=meets_access_equivalence,
        reportable=not reasons,
        reasons=tuple(reasons),
    )


def assess_service(
    workflow_evidence: Iterable[WorkflowEvidence],
) -> ServiceFairnessAssessment:
    results = tuple(evaluate_workflow(item) for item in workflow_evidence)
    reportable = tuple(result for result in results if result.reportable)

    return ServiceFairnessAssessment(
        workflows_assessed=len(results),
        workflows_meeting_access_equivalence=sum(
            result.meets_access_equivalence
            for result in reportable
        ),
        reportable_workflows=len(reportable),
        prohibited_processing_detected=any(
            not result.reportable
            for result in results
        ),
    )
