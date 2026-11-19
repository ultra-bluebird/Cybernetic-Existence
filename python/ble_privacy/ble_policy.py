from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping


class BlePrivacyValidationError(ValueError):
    pass


ESSENTIAL_SERVICE_KINDS = frozenset(
    {
        "emergency_shelter",
        "cooling",
        "warming",
        "drinking_water",
        "sanitation",
        "safety_information",
        "emergency_communications",
        "transit_access",
        "appeal_intake",
        "public_assistance",
    }
)

PROHIBITED_BLE_RECORD_FIELDS = frozenset(
    {
        "ble_identifier",
        "ble_address",
        "ble_device_name",
        "ble_signal_strength_history",
        "ble_pairing_record",
        "ble_presence_history",
        "ble_location_history",
        "wifi_mac_address",
        "wifi_session_identifier",
        "ip_address",
        "browser_fingerprint",
        "identity",
        "health",
        "disability",
        "augmentation",
        "cybernetic_host_status",
        "assistive_technology",
        "reputation_score",
        "social_rank",
        "financial_rank",
    }
)


@dataclass(frozen=True)
class BleFeatureRequest:
    feature_name: str
    service_kind: str
    is_optional: bool
    visible_disable_control: bool
    non_ble_equivalent_available: bool
    ble_identifier_persisted: bool
    ble_identifier_transmitted_off_device: bool
    ble_correlated_with_wifi: bool
    ble_presence_metric_created: bool
    essential_service_available_without_ble: bool
    explicit_consent_received: bool


@dataclass(frozen=True)
class BleFeatureDecision:
    approved: bool
    decision: str
    reason: str


def evaluate_ble_feature(request: BleFeatureRequest) -> BleFeatureDecision:
    if not request.feature_name.strip():
        raise BlePrivacyValidationError("feature_name must be non-empty.")
    if not request.service_kind.strip():
        raise BlePrivacyValidationError("service_kind must be non-empty.")

    if not request.is_optional:
        return BleFeatureDecision(
            approved=False,
            decision="BLE_NOT_OPTIONAL",
            reason="BLE interaction must remain optional.",
        )

    if not request.visible_disable_control:
        return BleFeatureDecision(
            approved=False,
            decision="BLE_DISABLE_CONTROL_MISSING",
            reason="An accessible visible BLE disable control is required.",
        )

    if not request.non_ble_equivalent_available:
        return BleFeatureDecision(
            approved=False,
            decision="NON_BLE_EQUIVALENT_MISSING",
            reason="An equivalent non-BLE pathway is required.",
        )

    if request.service_kind in ESSENTIAL_SERVICE_KINDS and not request.essential_service_available_without_ble:
        return BleFeatureDecision(
            approved=False,
            decision="ESSENTIAL_SERVICE_BLE_DEPENDENCY",
            reason="Essential service access must remain fully available without BLE.",
        )

    if request.ble_identifier_persisted:
        return BleFeatureDecision(
            approved=False,
            decision="BLE_PERSISTENCE_PROHIBITED",
            reason="BLE identifiers must have zero persistent retention.",
        )

    if request.ble_identifier_transmitted_off_device:
        return BleFeatureDecision(
            approved=False,
            decision="BLE_OFF_DEVICE_TRANSMISSION_PROHIBITED",
            reason="BLE identifiers must not leave the local interaction boundary.",
        )

    if request.ble_correlated_with_wifi:
        return BleFeatureDecision(
            approved=False,
            decision="BLE_WIFI_CORRELATION_PROHIBITED",
            reason="BLE identifiers must not be correlated with Wi-Fi or network activity.",
        )

    if request.ble_presence_metric_created:
        return BleFeatureDecision(
            approved=False,
            decision="BLE_PRESENCE_METRIC_PROHIBITED",
            reason="BLE presence counts, dwell metrics, and area-level BLE analytics are prohibited.",
        )

    if not request.explicit_consent_received:
        return BleFeatureDecision(
            approved=False,
            decision="BLE_CONSENT_REQUIRED",
            reason="Explicit consent is required before optional BLE interaction.",
        )

    return BleFeatureDecision(
        approved=True,
        decision="BLE_FEATURE_APPROVED",
        reason=(
            "The feature is optional, consented, local, non-persistent, non-correlated, "
            "and provides an equivalent non-BLE pathway."
        ),
    )


def audit_record_is_ble_safe(record: Mapping[str, object]) -> bool:
    return not bool(PROHIBITED_BLE_RECORD_FIELDS.intersection(record.keys()))


def sanitize_cooperative_upload(upload: Mapping[str, object]) -> dict[str, object]:
    required_fields = {
        "region",
        "metric",
        "value",
        "time_window",
        "privacy_class",
    }
    missing = required_fields.difference(upload.keys())
    if missing:
        raise BlePrivacyValidationError(
            "Upload is missing required aggregate fields: " + ", ".join(sorted(missing))
        )

    if not audit_record_is_ble_safe(upload):
        raise BlePrivacyValidationError(
            "The cooperative upload contains prohibited BLE, identity, network, or ranking fields."
        )

    sanitized = {
        "region": upload["region"],
        "metric": upload["metric"],
        "value": upload["value"],
        "time_window": upload["time_window"],
        "privacy_class": upload["privacy_class"],
        "ble_id_present": False,
    }

    if not all(isinstance(value, str) and value.strip() for value in sanitized.values() if isinstance(value, str)):
        raise BlePrivacyValidationError("String upload fields must be non-empty.")

    return sanitized
