from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


class QosPolicyValidationError(ValueError):
    pass


@dataclass(frozen=True)
class QosConfiguration:
    total_backhaul_mbps: float
    essential_reservation_mbps: float
    general_minimum_connection_mbps: float = 1.0

    def __post_init__(self) -> None:
        for field_name, value in (
            ("total_backhaul_mbps", self.total_backhaul_mbps),
            ("essential_reservation_mbps", self.essential_reservation_mbps),
            ("general_minimum_connection_mbps", self.general_minimum_connection_mbps),
        ):
            if not isfinite(value) or value <= 0.0:
                raise QosPolicyValidationError(
                    f"{field_name} must be a finite positive number."
                )

        if self.essential_reservation_mbps > self.total_backhaul_mbps:
            raise QosPolicyValidationError(
                "essential_reservation_mbps must not exceed total_backhaul_mbps."
            )

    @property
    def general_capacity_mbps(self) -> float:
        return self.total_backhaul_mbps - self.essential_reservation_mbps


@dataclass(frozen=True)
class QosPlan:
    essential_capacity_mbps: float
    general_capacity_mbps: float
    active_anonymous_connections: int
    theoretical_general_share_mbps: float
    one_mbps_target_met: bool
    congestion_mode: str
    user_identity_required: bool
    mac_address_retained: bool
    browsing_history_retained: bool


def build_qos_plan(
    configuration: QosConfiguration,
    active_anonymous_connections: int,
) -> QosPlan:
    if isinstance(active_anonymous_connections, bool) or not isinstance(
        active_anonymous_connections, int
    ):
        raise QosPolicyValidationError(
            "active_anonymous_connections must be an integer."
        )

    if active_anonymous_connections < 0:
        raise QosPolicyValidationError(
            "active_anonymous_connections must be non-negative."
        )

    if active_anonymous_connections == 0:
        share = configuration.general_capacity_mbps
    else:
        share = configuration.general_capacity_mbps / active_anonymous_connections

    target_met = share >= configuration.general_minimum_connection_mbps

    return QosPlan(
        essential_capacity_mbps=configuration.essential_reservation_mbps,
        general_capacity_mbps=configuration.general_capacity_mbps,
        active_anonymous_connections=active_anonymous_connections,
        theoretical_general_share_mbps=share,
        one_mbps_target_met=target_met,
        congestion_mode=(
            "NORMAL_ANONYMOUS_FAIR_QUEUEING"
            if target_met
            else "ANONYMOUS_FAIR_QUEUEING_WITH_BEST_EFFORT_SHAPING"
        ),
        user_identity_required=False,
        mac_address_retained=False,
        browsing_history_retained=False,
    )


def validate_essential_domain_policy(
    classification_basis: str,
    records_user_destination_history: bool,
    requires_user_identity: bool,
) -> bool:
    allowed_bases = {
        "signed_public_destination_allowlist",
        "local_public_service_mirror",
        "emergency_information_endpoint",
    }

    return (
        classification_basis in allowed_bases
        and not records_user_destination_history
        and not requires_user_identity
    )
