from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
import math


class DataClass(str, Enum):
    ENVIRONMENTAL_AGGREGATE = "environmental_aggregate"
    COMMUNITY_SENSOR_FEED = "community_sensor_feed"
    DERIVED_PUBLIC_INTEREST_INDICATOR = "derived_public_interest_indicator"
    SENSITIVE_PERSONAL = "sensitive_personal"
    ESSENTIAL_SERVICE_RECORD = "essential_service_record"


@dataclass(frozen=True)
class DataProduct:
    product_code: str
    data_class: DataClass
    calibration_quality: float
    completeness_quality: float
    freshness_quality: float
    provenance_quality: float
    uncertainty_quality: float
    public_interest_usefulness: float
    stewardship_effort: float
    underserved_observation_gap: float
    privacy_risk: float
    sensitive_data_present: bool
    community_authority_confirmed: bool
    purpose_bound_license_present: bool
    minimum_quality_met: bool
    redistribution_prohibited: bool
    reidentification_prohibited: bool
    automated_decision_use_prohibited: bool


@dataclass(frozen=True)
class CompensationPolicy:
    base_payment: float
    underserved_gap_multiplier: float
    maximum_privacy_risk: float


@dataclass(frozen=True)
class CompensationDecision:
    eligible: bool
    payment: float
    quality_score: float
    underserved_multiplier: float
    reason: str


def calculate_compensation(
    product: DataProduct,
    policy: CompensationPolicy,
) -> CompensationDecision:
    _validate_product(product)
    _validate_policy(policy)

    quality = _quality_score(product)
    underserved_multiplier = 1.0 + (
        policy.underserved_gap_multiplier
        * product.underserved_observation_gap
    )

    if product.data_class in {
        DataClass.SENSITIVE_PERSONAL,
        DataClass.ESSENTIAL_SERVICE_RECORD,
    }:
        return _rejected(
            quality,
            underserved_multiplier,
            "Sensitive personal and essential-service records are excluded from exchange.",
        )

    if product.sensitive_data_present:
        return _rejected(
            quality,
            underserved_multiplier,
            "The product contains prohibited sensitive personal data.",
        )

    if not product.community_authority_confirmed:
        return _rejected(
            quality,
            underserved_multiplier,
            "Community authority or contributor authorization is not confirmed.",
        )

    if not product.purpose_bound_license_present:
        return _rejected(
            quality,
            underserved_multiplier,
            "A purpose-bound license is required.",
        )

    if not product.minimum_quality_met:
        return _rejected(
            quality,
            underserved_multiplier,
            "The product does not meet the minimum declared quality standard.",
        )

    if product.privacy_risk > policy.maximum_privacy_risk:
        return _rejected(
            quality,
            underserved_multiplier,
            "Privacy or disclosure risk exceeds the exchange threshold.",
        )

    if not (
        product.redistribution_prohibited
        and product.reidentification_prohibited
        and product.automated_decision_use_prohibited
    ):
        return _rejected(
            quality,
            underserved_multiplier,
            "The license must prohibit redistribution, reidentification, and automated decision use.",
        )

    payment = (
        policy.base_payment
        * quality
        * product.public_interest_usefulness
        * product.stewardship_effort
        * underserved_multiplier
        * (1.0 - product.privacy_risk)
    )

    return CompensationDecision(
        eligible=True,
        payment=round(payment, 2),
        quality_score=quality,
        underserved_multiplier=underserved_multiplier,
        reason=(
            "Eligible environmental data product. Payment recognizes quality, "
            "public-interest usefulness, stewardship effort, and environmental "
            "observation gaps without pricing personal identity or cybernetic data."
        ),
    )


def _quality_score(product: DataProduct) -> float:
    return (
        product.calibration_quality
        * product.completeness_quality
        * product.freshness_quality
        * product.provenance_quality
        * product.uncertainty_quality
    ) ** (1.0 / 5.0)


def _rejected(
    quality: float,
    underserved_multiplier: float,
    reason: str,
) -> CompensationDecision:
    return CompensationDecision(
        eligible=False,
        payment=0.0,
        quality_score=quality,
        underserved_multiplier=underserved_multiplier,
        reason=reason,
    )


def _validate_product(product: DataProduct) -> None:
    if not product.product_code.strip():
        raise ValueError("product_code is required.")

    normalized_fields = {
        "calibration_quality": product.calibration_quality,
        "completeness_quality": product.completeness_quality,
        "freshness_quality": product.freshness_quality,
        "provenance_quality": product.provenance_quality,
        "uncertainty_quality": product.uncertainty_quality,
        "public_interest_usefulness": product.public_interest_usefulness,
        "stewardship_effort": product.stewardship_effort,
        "underserved_observation_gap": product.underserved_observation_gap,
        "privacy_risk": product.privacy_risk,
    }

    for name, value in normalized_fields.items():
        if not math.isfinite(value) or not 0.0 <= value <= 1.0:
            raise ValueError(f"{name} must be finite and within [0, 1].")


def _validate_policy(policy: CompensationPolicy) -> None:
    if not math.isfinite(policy.base_payment) or policy.base_payment < 0.0:
        raise ValueError("base_payment must be finite and non-negative.")

    if (
        not math.isfinite(policy.underserved_gap_multiplier)
        or policy.underserved_gap_multiplier < 0.0
        or policy.underserved_gap_multiplier > 2.0
    ):
        raise ValueError(
            "underserved_gap_multiplier must be finite and within [0, 2]."
        )

    if (
        not math.isfinite(policy.maximum_privacy_risk)
        or not 0.0 <= policy.maximum_privacy_risk <= 1.0
    ):
        raise ValueError(
            "maximum_privacy_risk must be finite and within [0, 1]."
        )
