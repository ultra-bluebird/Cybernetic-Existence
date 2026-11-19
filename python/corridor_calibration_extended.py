#!/usr/bin/env python3
"""
Local-only corridor-calibration extensions.

Implements:
- individually preserved uncertainty declarations and pairwise propagation;
- explicit sensor availability states;
- bounded categorical local verification;
- append-only sensor-replacement validation;
- closed calibration-purpose validation.

The module intentionally does not calculate scores, ranks, priorities,
eligibility results, sensor reputation, budget values, or authority claims.

Dependencies: Python standard library only.
Network access: none.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

HEX_64 = re.compile(r"^[a-f0-9]{64}$")
SENSOR_NODE = re.compile(r"^sensor_node_[a-z0-9_]{1,64}$")

PURPOSE_CODES = {
    "heat_island_monitoring",
    "air_quality_context_monitoring",
    "traffic_flow_context_monitoring",
    "stormwater_context_monitoring",
    "urban_habitat_context_monitoring",
    "maintenance_condition_monitoring",
    "local_environmental_reference_comparison",
    "sensor_integrity_review",
}
PURPOSE_BOUNDARIES = {
    "local_corridor_only",
    "local_sensor_pair_only",
    "local_maintenance_context_only",
    "local_reference_comparison_only",
}
REQUIRED_PURPOSE_NON_CLAIMS = {
    "purpose_is_not_personal_context",
    "purpose_is_not_eligibility_criterion",
    "purpose_is_not_priority_signal",
    "purpose_is_not_sensor_rank",
    "purpose_is_not_funding_request",
    "purpose_is_not_authority_claim",
}

AVAILABILITY_STATES = {
    "sensor_bytes_available_locally",
    "sensor_bytes_unavailable_locally",
    "sensor_bytes_verification_failed",
    "sensor_state_not_declared",
}
READ_ATTEMPT_STATES = {
    "read_attempted_not_available",
    "read_attempted_digest_mismatch",
    "read_available_locally",
    "read_not_attempted",
}
REQUIRED_AVAILABILITY_NON_CLAIMS = {
    "unavailability_is_not_fault",
    "unavailability_is_not_damage",
    "unavailability_is_not_removal",
    "unavailability_is_not_untrustworthiness",
    "unavailability_is_not_priority_change",
    "unavailability_is_not_eligibility_change",
    "unavailability_does_not_invalidate_other_sensor_records",
}

VERIFICATION_STATUSES = {
    "locally_verified",
    "not_established",
    "needs_local_review",
    "quarantined_not_authoritative",
}
VERIFICATION_DIMENSIONS = {
    "schema",
    "canonical_encoding",
    "record_sha256",
    "predecessor_link",
    "reference_binding",
    "drift_arithmetic",
    "time_tolerance",
    "topology_binding",
    "geometry_binding",
    "sensor_availability",
    "currentness",
    "purpose_scope",
}

REPLACEMENT_RELATIONS = {
    "sensor_replaced_same_topology_role",
    "sensor_replaced_topology_role_revised",
    "sensor_replacement_pending_local_review",
    "sensor_replacement_context_not_established",
}
REQUIRED_REPLACEMENT_NON_CLAIMS = {
    "replacement_is_not_retroactive_presence",
    "replacement_is_not_prior_sensor_fault_claim",
    "replacement_is_not_prior_sensor_damage_claim",
    "replacement_is_not_sensor_rank_change",
    "replacement_is_not_sensor_priority_change",
    "replacement_is_not_authority_or_procurement_claim",
}


class CorridorExtendedError(ValueError):
    """Raised when a local corridor-extension invariant is invalid."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CorridorExtendedError(message)


def is_sha256(value: Any) -> bool:
    return isinstance(value, str) and HEX_64.fullmatch(value) is not None


def require_keys(
    value: dict[str, Any],
    required: set[str],
    optional: set[str] | None = None,
) -> None:
    allowed = required | (optional or set())
    missing = sorted(required.difference(value))
    unexpected = sorted(set(value).difference(allowed))
    require(not missing, f"missing fields: {', '.join(missing)}")
    require(not unexpected, f"unexpected fields: {', '.join(unexpected)}")


def validate_declared_purpose(value: Any) -> dict[str, Any]:
    require(isinstance(value, dict), "declared_purpose must be an object")
    required = {"purpose_code", "scope_boundary", "non_claims"}
    require_keys(value, required)

    require(value["purpose_code"] in PURPOSE_CODES, "unknown purpose_code")
    require(value["scope_boundary"] in PURPOSE_BOUNDARIES, "invalid purpose scope_boundary")

    non_claims = value["non_claims"]
    require(isinstance(non_claims, list), "purpose non_claims must be an array")
    require(
        REQUIRED_PURPOSE_NON_CLAIMS.issubset(set(non_claims)),
        "declared purpose lacks mandatory non-claims",
    )

    return {
        "valid": True,
        "purpose_is_personal_context": False,
        "purpose_is_eligibility_signal": False,
        "purpose_is_priority_signal": False,
        "purpose_is_sensor_rank": False,
    }


def validate_sensor_uncertainty(value: Any) -> dict[str, Any]:
    require(isinstance(value, dict), "sensor_uncertainty must be an object")
    required = {
        "sensor_record_sha256",
        "sensor_node_id",
        "metric",
        "unit",
        "declared_uncertainty_bound",
        "reference_relation",
        "time_alignment_state",
        "non_claims",
    }
    require_keys(value, required)

    require(is_sha256(value["sensor_record_sha256"]), "sensor_record_sha256 must be SHA-256")
    require(
        isinstance(value["sensor_node_id"], str)
        and SENSOR_NODE.fullmatch(value["sensor_node_id"]),
        "sensor_node_id must be an opaque local identifier",
    )
    require(
        isinstance(value["declared_uncertainty_bound"], (int, float))
        and not isinstance(value["declared_uncertainty_bound"], bool)
        and math.isfinite(float(value["declared_uncertainty_bound"]))
        and value["declared_uncertainty_bound"] >= 0,
        "declared uncertainty bound must be finite and non-negative",
    )

    required_non_claims = {
        "uncertainty_is_not_a_score",
        "uncertainty_is_not_a_sensor_rank",
        "uncertainty_is_not_a_priority_signal",
        "uncertainty_is_not_an_eligibility_criterion",
        "uncertainty_is_not_aggregatable_for_ordering",
    }
    require(
        required_non_claims.issubset(set(value["non_claims"])),
        "sensor uncertainty lacks mandatory non-claims",
    )

    return {
        "valid": True,
        "sensor_record_sha256": value["sensor_record_sha256"],
        "sensor_node_id": value["sensor_node_id"],
        "uncertainty_bound": float(value["declared_uncertainty_bound"]),
        "metric": value["metric"],
        "unit": value["unit"],
        "time_alignment_state": value["time_alignment_state"],
    }


def propagate_edge_uncertainty(
    *,
    edge_id: str,
    from_sensor: dict[str, Any] | None,
    to_sensor: dict[str, Any] | None,
    geometry_uncertainty_bound: float | None = None,
) -> dict[str, Any]:
    """
    Computes a declared pairwise uncertainty bound only.

    Returns a categorical state plus the pairwise bound. It deliberately does
    not return a score, a rank, a priority, a total, an average, or a corridor
    quality value.
    """
    require(
        isinstance(edge_id, str) and edge_id.startswith("corridor_edge_"),
        "edge_id must be an opaque corridor edge identifier",
    )

    if from_sensor is None or to_sensor is None:
        return {
            "edge_id": edge_id,
            "edge_uncertainty_state": "not_established_due_to_unavailable_input",
            "declared_edge_uncertainty_bound": None,
            "propagation_model": "not_established",
            "non_claim": (
                "An unavailable input does not imply a sensor fault and does not "
                "invalidate uncertainty declarations for other independent records."
            ),
        }

    from_result = validate_sensor_uncertainty(from_sensor)
    to_result = validate_sensor_uncertainty(to_sensor)

    require(
        from_result["metric"] == to_result["metric"],
        "pairwise propagation requires matching metrics",
    )
    require(
        from_result["unit"] == to_result["unit"],
        "pairwise propagation requires matching units",
    )
    require(
        from_result["time_alignment_state"] == "within_tolerance"
        and to_result["time_alignment_state"] == "within_tolerance",
        "pairwise propagation requires within-tolerance time alignment",
    )

    geometry_bound = 0.0
    model = "root_sum_square_pairwise"
    if geometry_uncertainty_bound is not None:
        require(
            isinstance(geometry_uncertainty_bound, (int, float))
            and not isinstance(geometry_uncertainty_bound, bool)
            and math.isfinite(float(geometry_uncertainty_bound))
            and geometry_uncertainty_bound >= 0,
            "geometry uncertainty bound must be finite and non-negative",
        )
        geometry_bound = float(geometry_uncertainty_bound)
        model = "root_sum_square_pairwise_with_geometry"

    propagated = math.sqrt(
        from_result["uncertainty_bound"] ** 2
        + to_result["uncertainty_bound"] ** 2
        + geometry_bound ** 2
    )

    return {
        "edge_id": edge_id,
        "from_sensor_record_sha256": from_result["sensor_record_sha256"],
        "to_sensor_record_sha256": to_result["sensor_record_sha256"],
        "propagation_model": model,
        "geometry_uncertainty_bound": geometry_bound if geometry_uncertainty_bound is not None else None,
        "declared_edge_uncertainty_bound": propagated,
        "edge_uncertainty_state": "declared_and_locally_reproducible",
        "non_claim": (
            "This pairwise uncertainty declaration is not a corridor score, "
            "sensor rank, sensor priority, eligibility criterion, or quality total."
        ),
    }


def build_corridor_uncertainty_vector(
    sensor_uncertainties: list[dict[str, Any]],
    edge_results: list[dict[str, Any]],
) -> dict[str, Any]:
    """
    Produces a vector-style corridor summary.

    The only numeric summary is the maximum explicitly declared bound. The
    function intentionally refuses to sum, average, weight, score, or rank.
    """
    validated_sensors = [
        validate_sensor_uncertainty(sensor)
        for sensor in sensor_uncertainties
    ]

    established_edges = [
        edge for edge in edge_results
        if edge.get("edge_uncertainty_state") == "declared_and_locally_reproducible"
        and isinstance(edge.get("declared_edge_uncertainty_bound"), (int, float))
    ]

    all_bounds = [sensor["uncertainty_bound"] for sensor in validated_sensors]
    all_bounds.extend(
        float(edge["declared_edge_uncertainty_bound"])
        for edge in established_edges
    )

    summary_state = (
        "vector_declared"
        if len(established_edges) == len(edge_results)
        else "vector_incomplete"
    )

    return {
        "sensor_uncertainty_record_hashes": [
            sensor["sensor_record_sha256"]
            for sensor in validated_sensors
        ],
        "edge_uncertainty_record_hashes": [],
        "maximum_declared_uncertainty_bound": max(all_bounds) if all_bounds else None,
        "summary_state": summary_state,
        "aggregation_prohibition": True,
        "non_claims": [
            "no_corridor_uncertainty_score",
            "no_sensor_ranking",
            "no_sensor_priority_signal",
            "no_sensor_eligibility_criterion",
            "no_hidden_total",
            "no_cross_corridor_comparison"
        ]
    }


def validate_sensor_availability(value: Any) -> dict[str, Any]:
    require(isinstance(value, dict), "sensor_availability must be an object")
    required = {
        "sensor_artifact_sha256",
        "sensor_node_id",
        "availability_state",
        "local_read_attempt_state",
        "declared_at",
        "non_claims",
    }
    require_keys(value, required)

    require(is_sha256(value["sensor_artifact_sha256"]), "sensor artifact digest must be SHA-256")
    require(
        isinstance(value["sensor_node_id"], str)
        and SENSOR_NODE.fullmatch(value["sensor_node_id"]),
        "sensor node must be opaque local identifier",
    )
    require(value["availability_state"] in AVAILABILITY_STATES, "invalid availability_state")
    require(
        value["local_read_attempt_state"] in READ_ATTEMPT_STATES,
        "invalid local_read_attempt_state",
    )
    require(
        REQUIRED_AVAILABILITY_NON_CLAIMS.issubset(set(value["non_claims"])),
        "sensor availability lacks mandatory non-claims",
    )

    state = value["availability_state"]
    attempt = value["local_read_attempt_state"]

    if state == "sensor_bytes_unavailable_locally":
        require(
            attempt in {"read_attempted_not_available", "read_not_attempted"},
            "unavailable state requires a compatible local read attempt state",
        )
    if state == "sensor_bytes_available_locally":
        require(
            attempt == "read_available_locally",
            "available state requires read_available_locally",
        )
    if state == "sensor_bytes_verification_failed":
        require(
            attempt == "read_attempted_digest_mismatch",
            "verification-failed state requires digest mismatch attempt state",
        )

    return {
        "valid": True,
        "available_locally": state == "sensor_bytes_available_locally",
        "fault_asserted": False,
        "damage_asserted": False,
        "other_sensor_records_invalidated": False,
    }


def derive_local_verification_status(
    dimensions: dict[str, str],
) -> str:
    """
    Derives one closed categorical verification status.

    Dimension values must be:
    verified, not_established, needs_local_review, or failed.
    """
    allowed = {"verified", "not_established", "needs_local_review", "failed"}
    require(isinstance(dimensions, dict) and dimensions, "verification dimensions required")

    for name, state in dimensions.items():
        require(name in VERIFICATION_DIMENSIONS, f"unknown verification dimension: {name}")
        require(state in allowed, f"invalid verification state for {name}")

    if any(state == "failed" for state in dimensions.values()):
        return "quarantined_not_authoritative"
    if any(state == "needs_local_review" for state in dimensions.values()):
        return "needs_local_review"
    if any(state == "not_established" for state in dimensions.values()):
        return "not_established"
    return "locally_verified"


def validate_sensor_replacement(value: Any) -> dict[str, Any]:
    require(isinstance(value, dict), "sensor_replacement must be an object")
    required = {
        "prior_sensor_artifact_sha256",
        "prior_calibration_record_sha256",
        "replacement_sensor_artifact_sha256",
        "replacement_sensor_node_id",
        "replacement_relation",
        "effective_local_timestamp",
        "role",
        "non_claims",
    }
    require_keys(value, required)

    for field in (
        "prior_sensor_artifact_sha256",
        "prior_calibration_record_sha256",
        "replacement_sensor_artifact_sha256",
    ):
        require(is_sha256(value[field]), f"{field} must be SHA-256")

    require(
        value["prior_sensor_artifact_sha256"]
        != value["replacement_sensor_artifact_sha256"],
        "replacement sensor must be a distinct artifact",
    )
    require(
        isinstance(value["replacement_sensor_node_id"], str)
        and SENSOR_NODE.fullmatch(value["replacement_sensor_node_id"]),
        "replacement sensor node must be opaque local identifier",
    )
    require(
        value["replacement_relation"] in REPLACEMENT_RELATIONS,
        "invalid replacement relation",
    )
    require(
        value["role"]
        in {
            "calibration_steward",
            "maintenance_steward",
            "local_reviewer",
            "community_observer",
        },
        "invalid replacement role",
    )
    require(
        REQUIRED_REPLACEMENT_NON_CLAIMS.issubset(set(value["non_claims"])),
        "replacement lacks mandatory non-claims",
    )

    return {
        "valid": True,
        "prior_history_overwritten": False,
        "replacement_retroactive": False,
        "fault_claimed": False,
        "damage_claimed": False,
    }


def load_json(path: Path) -> Any:
    def reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, item in pairs:
            if key in result:
                raise CorridorExtendedError(f"duplicate JSON key: {key!r}")
            result[key] = item
        return result

    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle, object_pairs_hook=reject_duplicates)
    except FileNotFoundError as error:
        raise CorridorExtendedError(f"file not found: {path}") from error
    except json.JSONDecodeError as error:
        raise CorridorExtendedError(f"invalid JSON: {error}") from error


def command_validate(args: argparse.Namespace) -> int:
    value = load_json(Path(args.input))
    require(isinstance(value, dict), "input must be an object")

    report: dict[str, Any] = {}

    if "declared_purpose" in value:
        report["declared_purpose"] = validate_declared_purpose(value["declared_purpose"])
    if "sensor_uncertainty" in value:
        report["sensor_uncertainty"] = validate_sensor_uncertainty(value["sensor_uncertainty"])
    if "sensor_availability" in value:
        report["sensor_availability"] = validate_sensor_availability(value["sensor_availability"])
    if "sensor_replacement" in value:
        report["sensor_replacement"] = validate_sensor_replacement(value["sensor_replacement"])

    print(json.dumps(report, sort_keys=True, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate local-only corridor calibration extension fields."
    )
    commands = parser.add_subparsers(dest="command", required=True)

    validate = commands.add_parser(
        "validate",
        help="Validate bounded, non-scoring corridor calibration fields.",
    )
    validate.add_argument("--input", required=True)
    validate.set_defaults(handler=command_validate)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.handler(args)
    except (CorridorExtendedError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
