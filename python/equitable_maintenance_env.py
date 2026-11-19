from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import gymnasium as gym
import numpy as np
from gymnasium import spaces


@dataclass(frozen=True)
class MaintenanceTask:
    district_index: int
    asset_index: int
    failure_risk: float
    consequence_severity: float
    predicted_uptime_gain: float
    accessibility_critical: bool
    travel_minutes: float
    energy_wh: float
    corridor_approved: bool
    route_accessible: bool


class EquitableMaintenanceEnv(gym.Env[np.ndarray, int]):
    metadata = {"render_modes": []}

    def __init__(
        self,
        tasks: list[MaintenanceTask],
        district_count: int,
        minimum_service_floor: float = 0.70,
        energy_budget_wh: float = 3000.0,
        maximum_travel_minutes: float = 45.0,
    ) -> None:
        super().__init__()

        if not tasks:
            raise ValueError("at least one maintenance task is required")
        if district_count < 1:
            raise ValueError("district_count must be positive")

        self.tasks = tasks
        self.district_count = district_count
        self.minimum_service_floor = float(minimum_service_floor)
        self.energy_budget_wh = float(energy_budget_wh)
        self.maximum_travel_minutes = float(maximum_travel_minutes)
        self.energy_used_wh = 0.0
        self.completed = np.zeros(len(tasks), dtype=np.bool_)
        self.service_levels = np.full(district_count, 0.80, dtype=np.float32)
        self.accessibility_risks = np.full(len(tasks), 0.50, dtype=np.float32)

        self.action_space = spaces.Discrete(len(tasks))
        state_size = district_count * 2 + len(tasks) * 3
        self.observation_space = spaces.Box(
            low=0.0,
            high=1.0,
            shape=(state_size,),
            dtype=np.float32,
        )

    def _observation(self) -> np.ndarray:
        task_features: list[float] = []
        for index, task in enumerate(self.tasks):
            task_features.extend([
                np.clip(task.failure_risk, 0.0, 1.0),
                np.clip(task.predicted_uptime_gain, 0.0, 1.0),
                1.0 if self.completed[index] else 0.0,
            ])

        district_backlog = np.zeros(self.district_count, dtype=np.float32)
        for index, task in enumerate(self.tasks):
            if not self.completed[index]:
                district_backlog[task.district_index] += task.failure_risk

        return np.concatenate([
            np.clip(self.service_levels, 0.0, 1.0),
            np.clip(district_backlog, 0.0, 1.0),
            np.asarray(task_features, dtype=np.float32),
        ])

    def valid_action_mask(self) -> np.ndarray:
        mask = np.zeros(len(self.tasks), dtype=np.bool_)
        for index, task in enumerate(self.tasks):
            if self.completed[index]:
                continue
            if not task.corridor_approved or not task.route_accessible:
                continue
            if task.travel_minutes > self.maximum_travel_minutes:
                continue
            if self.energy_used_wh + task.energy_wh > self.energy_budget_wh:
                continue
            mask[index] = True
        return mask

    def reset(
        self,
        *,
        seed: int | None = None,
        options: dict[str, Any] | None = None,
    ) -> tuple[np.ndarray, dict[str, Any]]:
        super().reset(seed=seed)
        self.energy_used_wh = 0.0
        self.completed.fill(False)
        self.service_levels.fill(0.80)
        self.accessibility_risks.fill(0.50)
        return self._observation(), {"action_mask": self.valid_action_mask()}

    def step(self, action: int) -> tuple[np.ndarray, float, bool, bool, dict[str, Any]]:
        if not self.action_space.contains(action):
            raise ValueError("action is outside the action space")

        mask = self.valid_action_mask()
        if not mask[action]:
            return self._observation(), -100.0, True, False, {
                "reason": "invalid_action_or_hard_constraint_violation",
                "action_mask": mask,
            }

        task = self.tasks[action]
        self.completed[action] = True
        self.energy_used_wh += task.energy_wh

        district = task.district_index
        self.service_levels[district] = min(
            1.0,
            self.service_levels[district] + task.predicted_uptime_gain,
        )

        if task.accessibility_critical:
            self.accessibility_risks[action] = max(
                0.0,
                self.accessibility_risks[action] - task.predicted_uptime_gain,
            )

        uptime_gain = task.predicted_uptime_gain
        district_burden = 1.0 - self.service_levels
        fairness = 1.0 - float(np.max(district_burden))
        accessibility_protection = 1.0 - float(np.max(self.accessibility_risks))
        prevention = task.failure_risk * task.consequence_severity
        energy_cost = task.energy_wh / max(self.energy_budget_wh, 1.0)
        travel_cost = task.travel_minutes / max(self.maximum_travel_minutes, 1.0)

        reward = (
            0.30 * uptime_gain
            + 0.25 * fairness
            + 0.20 * accessibility_protection
            + 0.15 * prevention
            - 0.05 * energy_cost
            - 0.05 * travel_cost
        )

        service_floor_violation = bool(
            np.any(self.service_levels < self.minimum_service_floor)
        )
        if service_floor_violation:
            reward -= 100.0

        terminated = bool(np.all(self.completed) or not np.any(self.valid_action_mask()))
        return self._observation(), float(reward), terminated, False, {
            "action_mask": self.valid_action_mask(),
            "uptime_gain": uptime_gain,
            "fairness": fairness,
            "accessibility_protection": accessibility_protection,
            "service_floor_violation": service_floor_violation,
        }
