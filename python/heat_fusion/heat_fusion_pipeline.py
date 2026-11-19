from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Sequence
import math

import numpy as np
import tensorflow as tf


@dataclass(frozen=True)
class RasterObservation:
    timestamp: datetime
    temperature_kelvin: np.ndarray
    quality_mask: np.ndarray
    uncertainty_kelvin: np.ndarray


@dataclass(frozen=True)
class GroundObservation:
    timestamp: datetime
    row: int
    column: int
    temperature_kelvin: float
    uncertainty_kelvin: float
    healthy: bool


@dataclass(frozen=True)
class HeatMapResult:
    temperature_kelvin: np.ndarray
    uncertainty_kelvin: np.ndarray
    confidence: np.ndarray
    satellite_age_minutes: float


class HeatFusionModel:
    def __init__(self, model: tf.keras.Model) -> None:
        self._model = model

    def infer(
        self,
        satellite: RasterObservation,
        ground: Sequence[GroundObservation],
        static_features: np.ndarray,
        requested_at: datetime,
    ) -> HeatMapResult:
        _validate_raster(satellite)
        _validate_requested_at(requested_at)

        if static_features.ndim != 3:
            raise ValueError(
                "static_features must have shape [height, width, feature_count]."
            )

        height, width = satellite.temperature_kelvin.shape
        if static_features.shape[:2] != (height, width):
            raise ValueError(
                "static_features spatial dimensions must match the working raster."
            )

        age_minutes = (
            requested_at.astimezone(timezone.utc)
            - satellite.timestamp.astimezone(timezone.utc)
        ).total_seconds() / 60.0

        if age_minutes < 0.0:
            raise ValueError("Satellite observation cannot be from the future.")

        satellite_temperature = np.where(
            satellite.quality_mask,
            satellite.temperature_kelvin,
            np.nan,
        )

        ground_grid, ground_uncertainty = _rasterize_ground(
            ground,
            height,
            width,
        )

        feature_cube = np.concatenate(
            [
                np.nan_to_num(
                    satellite_temperature,
                    nan=0.0,
                )[..., np.newaxis],
                satellite.quality_mask.astype(np.float32)[..., np.newaxis],
                satellite.uncertainty_kelvin[..., np.newaxis],
                np.nan_to_num(ground_grid, nan=0.0)[..., np.newaxis],
                np.isfinite(ground_grid).astype(np.float32)[..., np.newaxis],
                np.nan_to_num(ground_uncertainty, nan=0.0)[..., np.newaxis],
                static_features.astype(np.float32),
            ],
            axis=-1,
        )

        prediction = self._model(
            feature_cube[np.newaxis, ...],
            training=False,
        ).numpy()[0]

        if prediction.shape[-1] != 2:
            raise ValueError(
                "The model must return temperature and log-variance channels."
            )

        temperature = prediction[..., 0]
        log_variance = np.clip(prediction[..., 1], -12.0, 8.0)
        model_uncertainty = np.sqrt(np.exp(log_variance))

        temporal_gap_uncertainty = min(15.0, age_minutes / 60.0)
        uncertainty = np.sqrt(
            model_uncertainty**2
            + np.nan_to_num(satellite.uncertainty_kelvin, nan=5.0) ** 2
            + np.nan_to_num(ground_uncertainty, nan=2.0) ** 2
            + temporal_gap_uncertainty**2
        )

        confidence = np.clip(
            1.0 - uncertainty / 20.0,
            0.0,
            1.0,
        )

        return HeatMapResult(
            temperature_kelvin=temperature,
            uncertainty_kelvin=uncertainty,
            confidence=confidence,
            satellite_age_minutes=age_minutes,
        )


def _rasterize_ground(
    observations: Sequence[GroundObservation],
    height: int,
    width: int,
) -> tuple[np.ndarray, np.ndarray]:
    values = np.full((height, width), np.nan, dtype=np.float32)
    uncertainties = np.full((height, width), np.nan, dtype=np.float32)

    for observation in observations:
        if not observation.healthy:
            continue
        if not 0 <= observation.row < height or not 0 <= observation.column < width:
            continue
        if not math.isfinite(observation.temperature_kelvin):
            continue
        if not math.isfinite(observation.uncertainty_kelvin):
            continue
        if observation.uncertainty_kelvin < 0.0:
            continue

        values[observation.row, observation.column] = observation.temperature_kelvin
        uncertainties[observation.row, observation.column] = observation.uncertainty_kelvin

    return values, uncertainties


def _validate_raster(observation: RasterObservation) -> None:
    if observation.timestamp.tzinfo is None:
        raise ValueError("Satellite timestamp must be timezone-aware.")
    if observation.temperature_kelvin.ndim != 2:
        raise ValueError("temperature_kelvin must be two-dimensional.")
    if observation.quality_mask.shape != observation.temperature_kelvin.shape:
        raise ValueError("quality_mask shape must match temperature raster shape.")
    if observation.uncertainty_kelvin.shape != observation.temperature_kelvin.shape:
        raise ValueError("uncertainty shape must match temperature raster shape.")


def _validate_requested_at(requested_at: datetime) -> None:
    if requested_at.tzinfo is None:
        raise ValueError("requested_at must be timezone-aware.")
