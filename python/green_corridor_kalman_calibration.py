from __future__ import annotations

from dataclasses import dataclass
from enum import Enum

import numpy as np
import pandas as pd


class CalibrationStatus(str, Enum):
    CALIBRATION_AVAILABLE = "CALIBRATION_AVAILABLE"
    CALIBRATION_REVIEW_REQUIRED = "CALIBRATION_REVIEW_REQUIRED"
    INSUFFICIENT_CALIBRATION_CONTEXT = "INSUFFICIENT_CALIBRATION_CONTEXT"


@dataclass(frozen=True)
class GreenCorridorCalibrationConfig:
    process_noise_covariance: np.ndarray
    satellite_observation_covariance: np.ndarray
    ground_observation_covariance: np.ndarray
    maximum_allowed_uncertainty: float
    minimum_ground_observations: int
    advisory_only: bool = True
    human_review_required: bool = True
    provenance_required: bool = True


@dataclass(frozen=True)
class CalibrationResult:
    status: CalibrationStatus
    estimated_state: pd.DataFrame | None
    explanation: str


REQUIRED_COLUMNS = {
    "observed_at_utc",
    "satellite_temperature_k",
    "ground_temperature_k",
    "ground_humidity_fraction",
    "normalized_uv_context",
    "normalized_air_quality_context",
    "canopy_fraction",
    "vegetation_proxy",
    "impervious_fraction",
    "shade_fraction",
    "satellite_available",
    "ground_available",
    "provenance_available",
    "uncertainty_flag",
}


def _unit_interval(series: pd.Series, name: str) -> None:
    if series.isna().any():
        raise ValueError(f"{name} contains missing values.")
    if ((series < 0.0) | (series > 1.0)).any():
        raise ValueError(f"{name} must remain in [0, 1].")


def _validate_covariance(matrix: np.ndarray, name: str, width: int) -> None:
    if matrix.shape != (width, width):
        raise ValueError(f"{name} must have shape ({width}, {width}).")
    if not np.allclose(matrix, matrix.T):
        raise ValueError(f"{name} must be symmetric.")
    if np.any(np.linalg.eigvalsh(matrix) < -1.0e-10):
        raise ValueError(f"{name} must be positive semidefinite.")


def validate_calibration_frame(frame: pd.DataFrame) -> None:
    missing = REQUIRED_COLUMNS - set(frame.columns)
    if missing:
        raise ValueError(f"Missing required columns: {sorted(missing)}")

    if frame.empty:
        raise ValueError("Calibration frame must not be empty.")

    timestamps = pd.to_datetime(frame["observed_at_utc"], utc=True, errors="coerce")
    if timestamps.isna().any():
        raise ValueError("observed_at_utc must contain valid UTC timestamps.")

    if not timestamps.is_monotonic_increasing:
        raise ValueError("observed_at_utc must be ordered monotonically.")

    for column in (
        "ground_humidity_fraction",
        "normalized_uv_context",
        "normalized_air_quality_context",
        "canopy_fraction",
        "vegetation_proxy",
        "impervious_fraction",
        "shade_fraction",
    ):
        _unit_interval(frame[column], column)

    for column in (
        "satellite_temperature_k",
        "ground_temperature_k",
    ):
        usable = frame.loc[
            frame["satellite_available"] if column == "satellite_temperature_k"
            else frame["ground_available"],
            column,
        ]
        if usable.isna().any() or (usable <= 0.0).any():
            raise ValueError(f"{column} must be positive when available.")


def fuse_green_corridor_observations(
    frame: pd.DataFrame,
    config: GreenCorridorCalibrationConfig,
) -> CalibrationResult:
    state_width = 5
    observation_width = 5

    validate_calibration_frame(frame)
    _validate_covariance(
        config.process_noise_covariance,
        "process_noise_covariance",
        state_width,
    )
    _validate_covariance(
        config.satellite_observation_covariance,
        "satellite_observation_covariance",
        observation_width,
    )
    _validate_covariance(
        config.ground_observation_covariance,
        "ground_observation_covariance",
        observation_width,
    )

    if (
        not config.advisory_only
        or not config.human_review_required
        or not config.provenance_required
    ):
        return CalibrationResult(
            status=CalibrationStatus.CALIBRATION_REVIEW_REQUIRED,
            estimated_state=None,
            explanation=(
                "The calibration process must remain advisory-only, human-reviewed, "
                "and provenance-bound."
            ),
        )

    ground_count = int(frame["ground_available"].sum())
    if ground_count < config.minimum_ground_observations:
        return CalibrationResult(
            status=CalibrationStatus.INSUFFICIENT_CALIBRATION_CONTEXT,
            estimated_state=None,
            explanation=(
                "The minimum number of ground observations is unavailable. "
                "No fused calibration estimate is released."
            ),
        )

    if not frame["provenance_available"].all():
        return CalibrationResult(
            status=CalibrationStatus.CALIBRATION_REVIEW_REQUIRED,
            estimated_state=None,
            explanation=(
                "At least one observation lacks required provenance. "
                "Calibration requires human review."
            ),
        )

    transition = np.eye(state_width)
    observation_matrix = np.eye(observation_width)
    identity = np.eye(state_width)

    state = np.array(
        [
            float(frame["ground_temperature_k"].dropna().iloc[0]),
            float(frame["ground_humidity_fraction"].iloc[0]),
            float(frame["normalized_uv_context"].iloc[0]),
            float(frame["normalized_air_quality_context"].iloc[0]),
            float(frame["vegetation_proxy"].iloc[0]),
        ],
        dtype=np.float64,
    )

    covariance = np.eye(state_width, dtype=np.float64)
    rows: list[dict[str, float | str | bool]] = []

    for row in frame.itertuples(index=False):
        controls = np.array(
            [
                row.canopy_fraction,
                row.vegetation_proxy,
                row.impervious_fraction,
                row.shade_fraction,
                row.normalized_uv_context,
            ],
            dtype=np.float64,
        )

        control_matrix = np.array(
            [
                [-0.10, -0.08, 0.12, -0.10, 0.03],
                [0.02, 0.04, -0.01, 0.03, 0.00],
                [0.00, 0.00, 0.00, 0.00, 0.10],
                [0.00, 0.00, 0.02, 0.00, 0.00],
                [0.05, 0.10, -0.02, 0.04, 0.00],
            ],
            dtype=np.float64,
        )

        predicted_state = transition @ state + control_matrix @ controls
        predicted_covariance = (
            transition @ covariance @ transition.T
            + config.process_noise_covariance
        )

        satellite_observation = np.array(
            [
                row.satellite_temperature_k
                if row.satellite_available
                else predicted_state[0],
                predicted_state[1],
                row.normalized_uv_context,
                row.normalized_air_quality_context,
                row.vegetation_proxy,
            ],
            dtype=np.float64,
        )

        ground_observation = np.array(
            [
                row.ground_temperature_k
                if row.ground_available
                else predicted_state[0],
                row.ground_humidity_fraction,
                row.normalized_uv_context,
                row.normalized_air_quality_context,
                row.vegetation_proxy,
            ],
            dtype=np.float64,
        )

        satellite_residual = satellite_observation - observation_matrix @ predicted_state
        satellite_gain = (
            predicted_covariance
            @ observation_matrix.T
            @ np.linalg.inv(
                observation_matrix
                @ predicted_covariance
                @ observation_matrix.T
                + config.satellite_observation_covariance
            )
        )

        intermediate_state = predicted_state + satellite_gain @ satellite_residual
        intermediate_covariance = (
            identity - satellite_gain @ observation_matrix
        ) @ predicted_covariance

        ground_residual = ground_observation - observation_matrix @ intermediate_state
        ground_gain = (
            intermediate_covariance
            @ observation_matrix.T
            @ np.linalg.inv(
                observation_matrix
                @ intermediate_covariance
                @ observation_matrix.T
                + config.ground_observation_covariance
            )
        )

        state = intermediate_state + ground_gain @ ground_residual
        covariance = (identity - ground_gain @ observation_matrix) @ intermediate_covariance

        uncertainty = float(np.trace(covariance) / state_width)

        rows.append(
            {
                "observed_at_utc": str(row.observed_at_utc),
                "estimated_temperature_k": float(state[0]),
                "estimated_humidity_fraction": float(state[1]),
                "estimated_uv_context": float(state[2]),
                "estimated_air_quality_context": float(state[3]),
                "estimated_vegetation_moderation": float(state[4]),
                "state_uncertainty": uncertainty,
                "uncertainty_flag": bool(row.uncertainty_flag),
            }
        )

    result_frame = pd.DataFrame(rows)

    if (
        result_frame["state_uncertainty"] > config.maximum_allowed_uncertainty
    ).any() or result_frame["uncertainty_flag"].any():
        return CalibrationResult(
            status=CalibrationStatus.CALIBRATION_REVIEW_REQUIRED,
            estimated_state=result_frame,
            explanation=(
                "Fused estimates were computed, but uncertainty exceeds the reviewed "
                "limit or one or more source records are explicitly uncertain. "
                "Human review is required before planning use."
            ),
        )

    return CalibrationResult(
        status=CalibrationStatus.CALIBRATION_AVAILABLE,
        estimated_state=result_frame,
        explanation=(
            "This output is an uncertainty-aware, advisory fusion of supplied "
            "satellite and ground environmental observations. It is not a real-time "
            "control signal, individual exposure estimate, or automatic planning decision."
        ),
    )
