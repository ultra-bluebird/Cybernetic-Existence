from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


ALLOWED_CONDITION_CLASSES = {
    "ramp_surface_crack",
    "ramp_surface_deformation",
    "ramp_obstruction",
    "ramp_water_or_debris",
    "handrail_damage",
    "tactile_paving_damage",
    "tactile_paving_obstruction",
    "tactile_paving_low_contrast",
    "automatic_door_misalignment",
    "automatic_door_obstruction",
    "automatic_door_sensor_fault_indicator",
    "path_surface_crack",
    "path_surface_heave",
    "path_surface_obstruction",
    "signage_damage",
    "unknown_condition",
}

PROHIBITED_ANNOTATIONS = {
    "face",
    "person_identity",
    "person_track",
    "body_landmarks",
    "gait_signature",
    "demographic_group",
    "health_status",
    "disability_status",
    "cybernetic_status",
    "augmentation_status",
    "license_plate",
    "device_identifier",
}


@dataclass(frozen=True)
class TrainingRecord:
    labels: tuple[str, ...]
    contains_face_crop: bool
    contains_identity_link: bool
    privacy_redaction_confirmed: bool


def validate_training_records(records: Iterable[TrainingRecord]) -> None:
    for index, record in enumerate(records):
        labels = set(record.labels)
        prohibited = labels.intersection(PROHIBITED_ANNOTATIONS)
        unsupported = labels.difference(ALLOWED_CONDITION_CLASSES).difference(
            PROHIBITED_ANNOTATIONS
        )

        if prohibited:
            raise ValueError(
                f"training record {index} contains prohibited labels: {sorted(prohibited)}"
            )
        if unsupported:
            raise ValueError(
                f"training record {index} contains unsupported labels: {sorted(unsupported)}"
            )
        if record.contains_face_crop:
            raise ValueError(f"training record {index} contains a face crop")
        if record.contains_identity_link:
            raise ValueError(f"training record {index} contains an identity link")
        if not record.privacy_redaction_confirmed:
            raise ValueError(
                f"training record {index} lacks privacy-redaction confirmation"
            )


def tflite_export_requirements() -> dict[str, object]:
    return {
        "input_width": 320,
        "input_height": 320,
        "quantization": "int8",
        "edge_inference_only": True,
        "camera_frame_retention": "zero_after_inference",
        "human_review_required": True,
        "prohibited_capabilities": sorted(PROHIBITED_ANNOTATIONS),
    }
