from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from math import sqrt
from secrets import token_bytes
from typing import Iterable, Sequence


@dataclass(frozen=True)
class PrivacyRoundConfig:
    minimum_cohort_size: int
    clipping_norm: float
    noise_multiplier: float
    maximum_epsilon: float
    epsilon_increment: float


@dataclass(frozen=True)
class ProtectedUpdate:
    cohort_pseudonym: str
    model_version: str
    clipped_l2_norm: float
    privacy_epsilon_used: float
    masked_update: tuple[float, ...]
    protocol_compliant: bool
    accessibility_parity_evidence: bool


@dataclass(frozen=True)
class RoundOutcome:
    accepted: bool
    reason: str
    aggregate_update: tuple[float, ...] | None
    cumulative_epsilon: float
    commitment: str


def l2_norm(values: Sequence[float]) -> float:
    return sqrt(sum(value * value for value in values))


def clip_update(values: Sequence[float], clipping_norm: float) -> tuple[float, ...]:
    if clipping_norm <= 0.0:
        raise ValueError("clipping_norm must be greater than zero")
    norm = l2_norm(values)
    if norm == 0.0 or norm <= clipping_norm:
        return tuple(values)
    scale = clipping_norm / norm
    return tuple(value * scale for value in values)


def deterministic_noise(seed: bytes, dimension: int, scale: float) -> tuple[float, ...]:
    if dimension < 1:
        raise ValueError("dimension must be positive")
    output: list[float] = []
    material = seed
    while len(output) < dimension:
        material = sha256(material).digest()
        left = int.from_bytes(material[:8], "big") / 2**64
        right = int.from_bytes(material[8:16], "big") / 2**64
        output.append((left - right) * scale)
    return tuple(output[:dimension])


def create_protected_update(
    cohort_pseudonym: str,
    model_version: str,
    local_delta: Sequence[float],
    config: PrivacyRoundConfig,
    privacy_epsilon_used: float,
    accessibility_parity_evidence: bool,
) -> ProtectedUpdate:
    if privacy_epsilon_used + config.epsilon_increment > config.maximum_epsilon:
        raise ValueError("privacy budget exhausted")
    if not local_delta:
        raise ValueError("local_delta must not be empty")

    clipped = clip_update(local_delta, config.clipping_norm)
    noise_seed = token_bytes(32)
    noise = deterministic_noise(
        noise_seed,
        len(clipped),
        config.noise_multiplier * config.clipping_norm,
    )
    protected = tuple(value + noise_value for value, noise_value in zip(clipped, noise))

    return ProtectedUpdate(
        cohort_pseudonym=cohort_pseudonym,
        model_version=model_version,
        clipped_l2_norm=l2_norm(clipped),
        privacy_epsilon_used=privacy_epsilon_used + config.epsilon_increment,
        masked_update=protected,
        protocol_compliant=True,
        accessibility_parity_evidence=accessibility_parity_evidence,
    )


def aggregate_round(
    updates: Iterable[ProtectedUpdate],
    config: PrivacyRoundConfig,
    expected_model_version: str,
) -> RoundOutcome:
    valid_updates = [
        update
        for update in updates
        if (
            update.protocol_compliant
            and update.accessibility_parity_evidence
            and update.model_version == expected_model_version
            and update.privacy_epsilon_used <= config.maximum_epsilon
        )
    ]

    if len(valid_updates) < config.minimum_cohort_size:
        return RoundOutcome(
            accepted=False,
            reason="minimum secure-aggregation cohort not met",
            aggregate_update=None,
            cumulative_epsilon=0.0,
            commitment=sha256(b"aborted:minimum-cohort").hexdigest(),
        )

    dimensions = {len(update.masked_update) for update in valid_updates}
    if len(dimensions) != 1:
        return RoundOutcome(
            accepted=False,
            reason="inconsistent update dimensions",
            aggregate_update=None,
            cumulative_epsilon=0.0,
            commitment=sha256(b"aborted:dimension-mismatch").hexdigest(),
        )

    count = len(valid_updates)
    aggregate = tuple(
        sum(update.masked_update[index] for update in valid_updates) / count
        for index in range(len(valid_updates[0].masked_update))
    )
    cumulative_epsilon = max(update.privacy_epsilon_used for update in valid_updates)
    commitment_material = (
        f"{expected_model_version}|{count}|{cumulative_epsilon:.8f}|"
        f"{','.join(f'{value:.8f}' for value in aggregate)}"
    ).encode("utf-8")

    return RoundOutcome(
        accepted=True,
        reason="aggregate accepted pending independent validation and human release",
        aggregate_update=aggregate,
        cumulative_epsilon=cumulative_epsilon,
        commitment=sha256(commitment_material).hexdigest(),
    )
