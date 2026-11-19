from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

import numpy as np


@dataclass(frozen=True)
class SensorMeasurement:
    temperature_c: float
    humidity_percent: float
    temperature_variance: float
    humidity_variance: float


@dataclass(frozen=True)
class NeighborEstimate:
    bias_temperature_c: float
    bias_humidity_percent: float
    bias_covariance: np.ndarray
    link_confidence: float
    fresh: bool
    gradient_model_version: str


class CorridorKalmanNode:
    def __init__(
        self,
        state: np.ndarray | None = None,
        covariance: np.ndarray | None = None,
        process_covariance: np.ndarray | None = None,
        gradient_model_version: str = "1.0.0",
        consensus_gain: float = 0.20,
    ) -> None:
        self.state = np.zeros(4, dtype=float) if state is None else np.array(state, dtype=float)
        self.covariance = np.eye(4, dtype=float) if covariance is None else np.array(covariance, dtype=float)
        self.process_covariance = (
            np.diag([0.02, 0.05, 0.001, 0.002])
            if process_covariance is None
            else np.array(process_covariance, dtype=float)
        )
        self.gradient_model_version = gradient_model_version
        self.consensus_gain = float(consensus_gain)
        self.transition = np.eye(4, dtype=float)
        self.measurement_matrix = np.array(
            [[1.0, 0.0, 1.0, 0.0], [0.0, 1.0, 0.0, 1.0]],
            dtype=float,
        )

        if self.state.shape != (4,) or self.covariance.shape != (4, 4):
            raise ValueError("state must have length 4 and covariance must be 4x4")
        if self.process_covariance.shape != (4, 4):
            raise ValueError("process_covariance must be 4x4")
        if not 0.0 <= self.consensus_gain <= 1.0:
            raise ValueError("consensus_gain must be in [0, 1]")

    def predict(self) -> None:
        self.state = self.transition @ self.state
        self.covariance = (
            self.transition @ self.covariance @ self.transition.T
            + self.process_covariance
        )

    def update(self, measurement: SensorMeasurement) -> None:
        if measurement.temperature_variance <= 0.0 or measurement.humidity_variance <= 0.0:
            raise ValueError("measurement variances must be positive")

        observation = np.array(
            [measurement.temperature_c, measurement.humidity_percent],
            dtype=float,
        )
        noise = np.diag(
            [measurement.temperature_variance, measurement.humidity_variance]
        )
        innovation = observation - self.measurement_matrix @ self.state
        innovation_covariance = (
            self.measurement_matrix @ self.covariance @ self.measurement_matrix.T
            + noise
        )
        gain = self.covariance @ self.measurement_matrix.T @ np.linalg.inv(
            innovation_covariance
        )
        identity = np.eye(4, dtype=float)
        self.state = self.state + gain @ innovation
        self.covariance = (
            (identity - gain @ self.measurement_matrix)
            @ self.covariance
            @ (identity - gain @ self.measurement_matrix).T
            + gain @ noise @ gain.T
        )

    def consensus_bias_update(self, neighbors: Iterable[NeighborEstimate]) -> None:
        accepted = [
            neighbor
            for neighbor in neighbors
            if (
                neighbor.fresh
                and neighbor.gradient_model_version == self.gradient_model_version
                and neighbor.bias_covariance.shape == (2, 2)
                and 0.0 <= neighbor.link_confidence <= 1.0
            )
        ]
        if not accepted:
            return

        raw_weights = []
        for neighbor in accepted:
            trace = float(np.trace(neighbor.bias_covariance))
            raw_weights.append(
                neighbor.link_confidence / max(trace, 1e-9)
            )

        total_weight = sum(raw_weights)
        if total_weight <= 0.0:
            return

        local_bias = self.state[2:4].copy()
        correction = np.zeros(2, dtype=float)

        for neighbor, raw_weight in zip(accepted, raw_weights):
            weight = raw_weight / total_weight
            neighbor_bias = np.array(
                [neighbor.bias_temperature_c, neighbor.bias_humidity_percent],
                dtype=float,
            )
            correction += weight * (neighbor_bias - local_bias)

        self.state[2:4] = local_bias + self.consensus_gain * correction
        consensus_uncertainty = 1.0 / total_weight
        self.covariance[2, 2] = min(
            self.covariance[2, 2],
            max(consensus_uncertainty, 1e-9),
        )
        self.covariance[3, 3] = min(
            self.covariance[3, 3],
            max(consensus_uncertainty, 1e-9),
        )

    def calibrated_reading(self, measurement: SensorMeasurement) -> tuple[float, float]:
        return (
            measurement.temperature_c - self.state[2],
            measurement.humidity_percent - self.state[3],
        )

    def calibration_confidence(self) -> float:
        bias_variance = float(np.trace(self.covariance[2:4, 2:4]))
        return float(np.clip(np.exp(-bias_variance), 0.0, 1.0))
