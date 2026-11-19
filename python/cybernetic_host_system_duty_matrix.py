from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class SystemDutyEvidence:
    duty: str
    implemented: bool
    evidence_ref: str
    person_level_data_used: bool = False
    identity_inference_used: bool = False
    external_action_authorized: bool = False


@dataclass(frozen=True)
class SystemDutyAssessment:
    total_duties: int
    implemented_duties: int
    missing_duties: tuple[str, ...]
    prohibited_data_use_detected: bool
    external_action_authorized: bool = False


REQUIRED_DUTIES = (
    "ACKNOWLEDGMENT_WITHOUT_PROOF",
    "MINIMAL_DISCLOSURE_ACCESS",
    "ACCESSIBLE_COMMUNICATION",
    "HUMAN_FALLBACK",
    "CORRECTION_PATH",
    "APPEAL_PATH",
    "MATERIAL_CHANGE_REVIEW",
    "CONTINUITY_PROTECTION",
    "NON_INTERFERENCE"
)


def assess_system_duties(
    evidence: Iterable[SystemDutyEvidence],
) -> SystemDutyAssessment:
    evidence_by_duty = {item.duty: item for item in evidence}
    missing = []
    prohibited_data_use_detected = False
    implemented = 0

    for duty in REQUIRED_DUTIES:
        item = evidence_by_duty.get(duty)

        if item is None or not item.implemented:
            missing.append(duty)
            continue

        implemented += 1

        if (
            item.person_level_data_used
            or item.identity_inference_used
            or item.external_action_authorized
        ):
            prohibited_data_use_detected = True

    return SystemDutyAssessment(
        total_duties=len(REQUIRED_DUTIES),
        implemented_duties=implemented,
        missing_duties=tuple(missing),
        prohibited_data_use_detected=prohibited_data_use_detected
    )
