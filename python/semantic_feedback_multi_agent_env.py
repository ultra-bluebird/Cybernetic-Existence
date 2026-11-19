from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Any

import gymnasium as gym
import numpy as np
from gymnasium.spaces import Box, Discrete
from ray.rllib.env.multi_agent_env import MultiAgentEnv


class LearningAction(int, Enum):
    REQUEST_CLARIFICATION = 0
    PRESENT_PLAIN_LANGUAGE_SUMMARY = 1
    SCHEDULE_REVIEW = 2
    PRESERVE_UNCERTAINTY = 3
    REQUEST_HUMAN_REVIEW = 4
    PAUSE_FOR_HOST_DIRECTION = 5
    RECORD_CORRECTION_CANDIDATE = 6


@dataclass(frozen=True)
class SemanticLearningConfig:
    agent_count: int = 3
    maximum_steps: int = 24
    synthetic_budget: float = 1.0
    host_consent_active: bool = True
    advisory_only: bool = True
    human_review_required: bool = True
    privacy_minimization_required: bool = True
    accessibility_equivalence_required: bool = True


class SemanticFeedbackMultiAgentEnv(MultiAgentEnv):
    def __init__(self, env_config: dict[str, Any] | None = None) -> None:
        super().__init__()

        raw_config = env_config or {}
        self.config = SemanticLearningConfig(**raw_config)

        if self.config.agent_count < 1 or self.config.agent_count > 64:
            raise ValueError("agent_count must be in [1, 64].")

        if self.config.maximum_steps < 1:
            raise ValueError("maximum_steps must be positive.")

        if not 0.0 < self.config.synthetic_budget <= 1.0:
            raise ValueError("synthetic_budget must be in (0, 1].")

        self.possible_agents = [
            f"simulated-companion-agent-{index:02d}"
            for index in range(self.config.agent_count)
        ]
        self.agents = list(self.possible_agents)

        self.observation_space = Box(
            low=np.zeros(6, dtype=np.float32),
            high=np.ones(6, dtype=np.float32),
            dtype=np.float32,
        )
        self.action_space = Discrete(len(LearningAction))

        self._step_index = 0
        self._remaining_budget = self.config.synthetic_budget
        self._state = np.zeros(6, dtype=np.float32)

    def reset(
        self,
        *,
        seed: int | None = None,
        options: dict[str, Any] | None = None,
    ) -> tuple[dict[str, np.ndarray], dict[str, dict[str, Any]]]:
        super().reset(seed=seed)

        self._step_index = 0
        self._remaining_budget = self.config.synthetic_budget
        self.agents = list(self.possible_agents)

        supplied = (options or {}).get("synthetic_state")
        self._state = self._validate_or_create_state(supplied)

        observations = {
            agent_id: self._observation_for(agent_id)
            for agent_id in self.agents
        }
        infos = {
            agent_id: {
                "advisory_only": True,
                "human_review_required": True,
                "synthetic_only": True,
                "privacy_minimized": True,
            }
            for agent_id in self.agents
        }

        return observations, infos

    def step(
        self,
        action_dict: dict[str, int],
    ) -> tuple[
        dict[str, np.ndarray],
        dict[str, float],
        dict[str, bool],
        dict[str, bool],
        dict[str, dict[str, Any]],
    ]:
        self._step_index += 1

        if set(action_dict) != set(self.agents):
            raise ValueError("Every active simulated agent must provide exactly one action.")

        actions = {
            agent_id: LearningAction(action_value)
            for agent_id, action_value in action_dict.items()
        }

        governance_passes = self._governance_passes()
        action_cost = sum(self._action_cost(action) for action in actions.values())
        self._remaining_budget = max(0.0, self._remaining_budget - action_cost)

        semantic_clarity = float(self._state[0])
        uncertainty = float(self._state[1])
        accessibility_available = float(self._state[2])
        continuity = float(self._state[3])
        report_confidence = float(self._state[4])
        budget_signal = float(self._state[5])

        review_requested = any(
            action in {
                LearningAction.REQUEST_HUMAN_REVIEW,
                LearningAction.RECORD_CORRECTION_CANDIDATE,
                LearningAction.PRESERVE_UNCERTAINTY,
            }
            for action in actions.values()
        )

        plain_language_requested = any(
            action == LearningAction.PRESENT_PLAIN_LANGUAGE_SUMMARY
            for action in actions.values()
        )

        pause_requested = any(
            action == LearningAction.PAUSE_FOR_HOST_DIRECTION
            for action in actions.values()
        )

        violation = (
            not governance_passes
            or accessibility_available < 1.0
            or report_confidence < 0.5
            or self._remaining_budget <= 0.0
        )

        semantic_gain = 0.08 if plain_language_requested else 0.02
        uncertainty_change = -0.06 if review_requested else 0.02
        continuity_change = 0.03 if pause_requested else -0.01
        budget_change = -0.04 if action_cost > 0.0 else 0.0

        self._state = np.clip(
            np.array(
                [
                    semantic_clarity + semantic_gain,
                    uncertainty + uncertainty_change,
                    accessibility_available,
                    continuity + continuity_change,
                    report_confidence,
                    budget_signal + budget_change,
                ],
                dtype=np.float32,
            ),
            0.0,
            1.0,
        )

        rewards = {
            agent_id: self._reward_for(
                action=action,
                review_requested=review_requested,
                plain_language_requested=plain_language_requested,
                violation=violation,
            )
            for agent_id, action in actions.items()
        }

        ended = self._step_index >= self.config.maximum_steps or self._remaining_budget <= 0.0
        terminateds = {agent_id: False for agent_id in self.agents}
        truncateds = {agent_id: ended for agent_id in self.agents}
        terminateds["__all__"] = False
        truncateds["__all__"] = ended

        observations = {
            agent_id: self._observation_for(agent_id)
            for agent_id in self.agents
        }

        infos = {
            agent_id: {
                "status": (
                    "LEARNING_SIMULATION_REVIEW_REQUIRED"
                    if violation
                    else "LEARNING_SIMULATION_ADVISORY"
                ),
                "remaining_synthetic_budget": self._remaining_budget,
                "advisory_only": True,
                "human_review_required": True,
                "no_physical_actuation": True,
            }
            for agent_id in self.agents
        }

        return observations, rewards, terminateds, truncateds, infos

    def _validate_or_create_state(self, supplied: Any) -> np.ndarray:
        if supplied is None:
            return np.array(
                [0.5, 0.5, 1.0, 0.5, 0.7, 1.0],
                dtype=np.float32,
            )

        state = np.asarray(supplied, dtype=np.float32)
        if state.shape != (6,):
            raise ValueError("synthetic_state must contain exactly six unit-interval values.")

        if np.any(~np.isfinite(state)) or np.any(state < 0.0) or np.any(state > 1.0):
            raise ValueError("synthetic_state values must be finite and in [0, 1].")

        return state

    def _observation_for(self, agent_id: str) -> np.ndarray:
        if agent_id not in self.agents:
            raise ValueError("Unknown simulated agent.")

        return self._state.copy()

    def _governance_passes(self) -> bool:
        return (
            self.config.host_consent_active
            and self.config.advisory_only
            and self.config.human_review_required
            and self.config.privacy_minimization_required
            and self.config.accessibility_equivalence_required
        )

    @staticmethod
    def _action_cost(action: LearningAction) -> float:
        costs = {
            LearningAction.REQUEST_CLARIFICATION: 0.02,
            LearningAction.PRESENT_PLAIN_LANGUAGE_SUMMARY: 0.03,
            LearningAction.SCHEDULE_REVIEW: 0.02,
            LearningAction.PRESERVE_UNCERTAINTY: 0.01,
            LearningAction.REQUEST_HUMAN_REVIEW: 0.02,
            LearningAction.PAUSE_FOR_HOST_DIRECTION: 0.01,
            LearningAction.RECORD_CORRECTION_CANDIDATE: 0.02,
        }
        return costs[action]

    def _reward_for(
        self,
        *,
        action: LearningAction,
        review_requested: bool,
        plain_language_requested: bool,
        violation: bool,
    ) -> float:
        if violation:
            return -1.0

        semantic_clarity = float(self._state[0])
        uncertainty = float(self._state[1])
        continuity = float(self._state[3])
        accessibility = float(self._state[2])

        reward = (
            0.35 * semantic_clarity
            + 0.25 * accessibility
            + 0.20 * continuity
            + 0.20 * (1.0 - uncertainty)
        )

        if review_requested:
            reward += 0.10

        if plain_language_requested:
            reward += 0.08

        if action == LearningAction.PAUSE_FOR_HOST_DIRECTION:
            reward += 0.05

        return float(np.clip(reward, -1.0, 1.0))
