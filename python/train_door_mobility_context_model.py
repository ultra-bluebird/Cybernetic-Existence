from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class DatasetPolicy:
    allowed_classes: tuple[str, ...] = (
        "standard_approach",
        "wheeled_mobility_context",
        "walking_aid_context",
        "cane_or_long_object_context",
        "mobility_assist_device_context",
        "multiple_or_uncertain_context",
    )
    prohibited_annotations: tuple[str, ...] = (
        "face",
        "person_name",
        "identity",
        "age",
        "gender",
        "race",
        "ethnicity",
        "health_status",
        "disability_diagnosis",
        "augmentation_status",
        "biometric_template",
        "gait_signature",
    )


def validate_dataset_manifest(records: Iterable[dict[str, object]], policy: DatasetPolicy) -> None:
    allowed = set(policy.allowed_classes)
    prohibited = set(policy.prohibited_annotations)

    for index, record in enumerate(records):
        labels = set(record.get("labels", []))
        forbidden = labels.intersection(prohibited)
        unknown = labels.difference(allowed).difference(prohibited)

        if forbidden:
            raise ValueError(
                f"record {index} contains prohibited annotations: {sorted(forbidden)}"
            )
        if unknown:
            raise ValueError(
                f"record {index} contains unsupported labels: {sorted(unknown)}"
            )
        if record.get("contains_face_crop", False):
            raise ValueError(f"record {index} contains a prohibited face crop")
        if record.get("contains_identity_link", False):
            raise ValueError(f"record {index} contains a prohibited identity link")


def export_onnx_command(
    training_script: Path,
    checkpoint: Path,
    output_model: Path,
    input_size: int = 320,
) -> list[str]:
    if input_size < 128 or input_size > 1024:
        raise ValueError("input_size must be in the interval [128, 1024]")
    return [
        "python",
        str(training_script),
        "--weights",
        str(checkpoint),
        "--imgsz",
        str(input_size),
        "--format",
        "onnx",
        "--output",
        str(output_model),
    ]


def required_evaluation_metrics() -> tuple[str, ...]:
    return (
        "doorway_context_recall",
        "extended_hold_false_negative_rate",
        "benign_assistance_false_positive_rate",
        "p95_inference_latency_ms",
        "low_light_parity",
        "glare_parity",
        "device_context_parity",
        "privacy_retention_audit_passed",
    )
