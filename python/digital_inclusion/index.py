from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


class DigitalInclusionValidationError(ValueError):
    pass


@dataclass(frozen=True)
class InclusionComponents:
    internet_access: float
    device_access: float
    digital_support: float
    accessibility: float
    public_wifi_mac_addresses_retained: bool = False
    public_wifi_browsing_history_retained: bool = False
    kiosk_search_history_retained: bool = False
    identity_or_health_data_used: bool = False
    augmentation_or_cybernetic_host_data_used: bool = False

    def __post_init__(self) -> None:
        for field_name, value in (
            ("internet_access", self.internet_access),
            ("device_access", self.device_access),
            ("digital_support", self.digital_support),
            ("accessibility", self.accessibility),
        ):
            if not isfinite(value) or not 0.0 <= value <= 1.0:
                raise DigitalInclusionValidationError(
                    f"{field_name} must be a finite value from zero through one."
                )


@dataclass(frozen=True)
class DigitalInclusionResult:
    index: float | None
    essential_access_gap_review_required: bool
    privacy_compliant: bool
    reason: str


def evaluate_digital_inclusion(
    components: InclusionComponents,
    minimum_component_floor: float = 0.40,
    accessibility_weight: float = 0.25,
) -> DigitalInclusionResult:
    if (
        not isfinite(minimum_component_floor)
        or not 0.0 <= minimum_component_floor <= 1.0
    ):
        raise DigitalInclusionValidationError(
            "minimum_component_floor must be from zero through one."
        )

    if (
        not isfinite(accessibility_weight)
        or not 0.25 <= accessibility_weight <= 1.0
    ):
        raise DigitalInclusionValidationError(
            "accessibility_weight must be from 0.25 through one."
        )

    privacy_violation = any(
        (
            components.public_wifi_mac_addresses_retained,
            components.public_wifi_browsing_history_retained,
            components.kiosk_search_history_retained,
            components.identity_or_health_data_used,
            components.augmentation_or_cybernetic_host_data_used,
        )
    )

    if privacy_violation:
        return DigitalInclusionResult(
            index=None,
            essential_access_gap_review_required=True,
            privacy_compliant=False,
            reason=(
                "The assessment is blocked because it includes prohibited tracking, "
                "identity, health, or augmentation-related data."
            ),
        )

    remaining_weight = 1.0 - accessibility_weight
    base_weight = remaining_weight / 3.0

    index = (
        base_weight * components.internet_access
        + base_weight * components.device_access
        + base_weight * components.digital_support
        + accessibility_weight * components.accessibility
    )

    essential_gap = any(
        value < minimum_component_floor
        for value in (
            components.internet_access,
            components.device_access,
            components.digital_support,
            components.accessibility,
        )
    )

    return DigitalInclusionResult(
        index=index,
        essential_access_gap_review_required=essential_gap,
        privacy_compliant=True,
        reason=(
            "The index is based on aggregate access conditions and preserves a separate "
            "essential-access review when any component falls below the required floor."
        ),
    )
