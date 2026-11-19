#!/usr/bin/env python3
"""
Red-team-hardened, local-only corridor calibration evaluator.

This utility derives a record-scoped calibration use state from locally provided
artifacts. It performs no network activity and makes no claim of identity,
attribution, institutional certification, universal accuracy, or external
authority.

Dependencies: Python standard library only.
Commitment hash: SHA-256 only.
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

HEX_64 = re.compile(r"^[a-f0-9]{64}$")
TIMESTAMP = re.compile(
    r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$"
)
SENSOR_NODE = re.compile(r"^sensor_node_[a-z0-9_]{1,64}$")

CURRENTNESS_STATES = {
    "current",
    "superseded",
    "withdrawn",
    "disputed",
    "expired",
    "unknown",
}
USABLE_STATES = {
    "calibration_not_established",
    "calibration_recorded_incomplete",
    "calibration_recorded_needs_local_review",
    "calibration_recorded_outside_time_tolerance",
    "calibration_recorded_reference_not_established",
    "calibration_recorded_topology_not_established",
    "calibration_recorded_integrity_failed",
    "calibration_recorded_expired",
    "calibration_recorded_superseded",
    "calibration_locally_aligned_within_tolerance",
    "calibration_quarantined_not_authoritative",
}
DIMENSION_STATES = {
    "verified",
    "not_established",
    "failed",
    "not_applicable",
}


class HardenedCalibrationError(ValueError):
    """Raised when a hardened local calibration invariant fails."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise HardenedCalibrationError(message)


def is_sha256(value: Any) -> bool:
    return isinstance(value, str) and HEX_64.fullmatch(value) is not None


def canonical_json(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def sha256_hex(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def object_hash(value: dict[str, Any], excluded: str | None = None) -> str:
    copied = copy.deepcopy(value)
    if excluded is not None:
        copied.pop(excluded, None)
    return sha256_hex(canonical_json(copied))


def parse_timestamp(value: str) -> dt.datetime:
    require(
        isinstance(value, str) and TIMESTAMP.fullmatch(value),
        "timestamp must be RFC 3339 with an explicit numeric offset",
    )
    try:
        result = dt.datetime.fromisoformat(value)
    except ValueError as error:
        raise HardenedCalibrationError("timestamp is not parseable") from error
    require(result.tzinfo is not None, "timestamp must include UTC offset")
    return result


def dimension(state: str, check_id: str, summary: str) -> dict[str, str]:
    require(state in DIMENSION_STATES, "unknown verification dimension state")
    return {
        "state": state,
        "check_id": check_id,
        "summary": summary,
    }


def validate_reference_artifact(reference: Any) -> dict[str, Any]:
    require(isinstance(reference, dict), "reference_artifact must be an object")

    required = {
        "reference_id",
        "reference_content_sha256",
        "reference_class",
        "applicability_scope",
        "applicability_conditions",
        "metric",
        "unit",
        "observed_reading",
        "observed_timestamp",
        "reference_role",
        "reference_provenance_head_sha256",
        "reference_integrity_state",
        "replacement_state",
        "redundancy_state",
        "redundant_local_copy_digests",
        "external_dependency_state",
        "non_claims",
    }
    require(set(reference) == required, "reference artifact fields are incomplete")

    require(
        isinstance(reference["reference_id"], str)
        and reference["reference_id"].startswith("local_reference_"),
        "reference_id must be an opaque local label",
    )
    for field in (
        "reference_content_sha256",
        "reference_provenance_head_sha256",
    ):
        require(is_sha256(reference[field]), f"{field} must be SHA-256")

    require(
        isinstance(reference["observed_reading"], (int, float))
        and not isinstance(reference["observed_reading"], bool)
        and math.isfinite(float(reference["observed_reading"])),
        "reference observed reading must be finite numeric",
    )
    parse_timestamp(reference["observed_timestamp"])

    copies = reference["redundant_local_copy_digests"]
    require(isinstance(copies, list), "redundant_local_copy_digests must be an array")
    require(len(copies) == len(set(copies)), "redundant copy digests must be unique")
    for digest in copies:
        require(is_sha256(digest), "redundant copy digest must be SHA-256")

    redundancy = reference["redundancy_state"]
    if redundancy == "multiple_matching_local_copies":
        require(len(copies) >= 2, "multiple matching copies requires at least two local digests")
        require(
            set(copies) == {reference["reference_content_sha256"]},
            "all declared redundant copies must match reference content digest",
        )

    return {
        "verified": reference["reference_integrity_state"] == "verified",
        "current": reference["replacement_state"] not in {"superseded"},
        "reading": float(reference["observed_reading"]),
        "unit": reference["unit"],
        "metric": reference["metric"],
        "external_dependency_state": reference["external_dependency_state"],
    }


def validate_drift_evidence(evidence: Any, reference: dict[str, Any]) -> dict[str, Any]:
    require(isinstance(evidence, dict), "drift_evidence must be an object")
    required = {
        "evidence_state",
        "sensor_reading",
        "reference_reading",
        "sensor_timestamp",
        "reference_timestamp",
        "measurement_unit",
        "conditions_reference_state",
    }
    optional = {"conditions_reference_sha256"}
    require(set(evidence).issubset(required | optional), "unexpected drift evidence field")
    require(required.issubset(evidence), "drift evidence fields are incomplete")

    for field in ("sensor_reading", "reference_reading"):
        require(
            isinstance(evidence[field], (int, float))
            and not isinstance(evidence[field], bool)
            and math.isfinite(float(evidence[field])),
            f"{field} must be finite numeric",
        )

    require(
        evidence["measurement_unit"] == reference["unit"],
        "drift evidence unit must match reference unit",
    )
    require(
        math.isclose(
            float(evidence["reference_reading"]),
            reference["reading"],
            rel_tol=0.0,
            abs_tol=1e-12,
        ),
        "drift evidence reference reading must match reference artifact",
    )

    sensor_time = parse_timestamp(evidence["sensor_timestamp"])
    reference_time = parse_timestamp(evidence["reference_timestamp"])

    if evidence["conditions_reference_state"] in {
        "local_conditions_commitment",
        "local_conditions_available",
    }:
        require(
            is_sha256(evidence.get("conditions_reference_sha256")),
            "conditions reference digest is required for declared conditions",
        )
    else:
        require(
            evidence.get("conditions_reference_sha256") is None,
            "conditions digest must be absent when conditions are not declared",
        )

    return {
        "available": evidence["evidence_state"] == "available_locally",
        "sensor_reading": float(evidence["sensor_reading"]),
        "reference_reading": float(evidence["reference_reading"]),
        "sensor_time": sensor_time,
        "reference_time": reference_time,
    }


def validate_drift_declaration(
    declaration: Any,
    evidence: dict[str, Any],
) -> dict[str, Any]:
    require(isinstance(declaration, dict), "drift_declaration must be an object")
    required = {
        "declaration_state",
        "declared_relationship",
        "uncertainty_bound",
        "interpretation_scope",
        "non_conversion_constraints",
    }
    optional = {"declared_value"}
    require(set(declaration).issubset(required | optional), "unexpected drift declaration field")
    require(required.issubset(declaration), "drift declaration fields are incomplete")

    constraints = {
        "not_a_sensor_trust_score",
        "not_a_sensor_priority_signal",
        "not_a_sensor_eligibility_criterion",
        "not_a_sensor_rank",
        "not_a_device_reputation_value",
        "not_aggregatable_for_sensor_comparison",
    }
    require(
        constraints.issubset(set(declaration["non_conversion_constraints"])),
        "drift declaration lacks mandatory non-conversion constraints",
    )
    require(
        isinstance(declaration["uncertainty_bound"], (int, float))
        and not isinstance(declaration["uncertainty_bound"], bool)
        and math.isfinite(float(declaration["uncertainty_bound"]))
        and declaration["uncertainty_bound"] >= 0,
        "drift uncertainty bound must be finite and non-negative",
    )

    state = declaration["declaration_state"]
    relationship = declaration["declared_relationship"]
    declared_value = declaration.get("declared_value")

    if state == "declared_consistent":
        require(
            relationship in {"sensor_minus_reference", "reference_minus_sensor"},
            "consistent drift declaration requires an arithmetic relationship",
        )
        require(
            isinstance(declared_value, (int, float))
            and not isinstance(declared_value, bool)
            and math.isfinite(float(declared_value)),
            "consistent drift declaration requires a finite declared value",
        )
        expected = (
            evidence["sensor_reading"] - evidence["reference_reading"]
            if relationship == "sensor_minus_reference"
            else evidence["reference_reading"] - evidence["sensor_reading"]
        )
        require(
            math.isclose(float(declared_value), expected, rel_tol=0.0, abs_tol=1e-12),
            "declared drift value does not match declared relationship and evidence",
        )
        return {"consistent": True, "state": state}

    return {
        "consistent": False,
        "state": state,
    }


def validate_time_reconciliation(
    value: Any,
    evidence: dict[str, Any],
) -> dict[str, Any]:
    require(isinstance(value, dict), "local_time_reconciliation must be an object")
    required = {
        "local_time_authority_label",
        "clock_basis",
        "clock_artifact_sha256",
        "tolerance_seconds",
        "declared_time_delta_seconds",
        "time_drift_band",
        "reconciliation_state",
        "time_authority_claim",
    }
    require(set(value) == required, "time reconciliation fields are incomplete")

    require(
        isinstance(value["local_time_authority_label"], str)
        and value["local_time_authority_label"].startswith("corridor_time_reference_"),
        "local time authority label must be an opaque local identifier",
    )
    require(is_sha256(value["clock_artifact_sha256"]), "clock artifact digest must be SHA-256")
    require(
        isinstance(value["tolerance_seconds"], (int, float))
        and not isinstance(value["tolerance_seconds"], bool)
        and 0 <= value["tolerance_seconds"] <= 86400,
        "tolerance_seconds must be within [0, 86400]",
    )

    actual_delta = (evidence["sensor_time"] - evidence["reference_time"]).total_seconds()
    require(
        math.isclose(
            float(value["declared_time_delta_seconds"]),
            actual_delta,
            rel_tol=0.0,
            abs_tol=1e-9,
        ),
        "declared time delta does not match drift evidence timestamps",
    )

    within = abs(actual_delta) <= float(value["tolerance_seconds"])
    expected_state = "within_tolerance" if within else "outside_tolerance"
    require(
        value["reconciliation_state"] == expected_state,
        "reconciliation state does not match declared tolerance",
    )

    expected_band = (
        "within_low_band"
        if abs(actual_delta) <= float(value["tolerance_seconds"]) / 2
        else "within_declared_tolerance"
        if within
        else "outside_declared_tolerance"
    )
    require(
        value["time_drift_band"] == expected_band,
        "time drift band does not match local timestamp difference",
    )
    require(
        value["time_authority_claim"] == "not_asserted",
        "time authority must not be asserted",
    )

    return {
        "within_tolerance": within,
        "delta_seconds": actual_delta,
    }


def derive_usable_state(
    *,
    fields_complete: bool,
    canonical_encoding: bool,
    record_digest: bool,
    trust_root: bool,
    reference: dict[str, Any],
    drift_evidence: dict[str, Any],
    drift_declaration: dict[str, Any],
    topology_verified: bool,
    geometry_verified: bool,
    time_result: dict[str, Any],
    currentness: str,
) -> str:
    require(currentness in CURRENTNESS_STATES, "unknown currentness state")

    if not record_digest or not canonical_encoding:
        return "calibration_recorded_integrity_failed"
    if currentness == "expired":
        return "calibration_recorded_expired"
    if currentness == "superseded":
        return "calibration_recorded_superseded"
    if currentness in {"withdrawn", "disputed", "unknown"}:
        return "calibration_recorded_needs_local_review"
    if not fields_complete:
        return "calibration_recorded_incomplete"
    if not trust_root:
        return "calibration_not_established"
    if not reference["verified"] or not reference["current"]:
        return "calibration_recorded_reference_not_established"
    if not topology_verified or not geometry_verified:
        return "calibration_recorded_topology_not_established"
    if not time_result["within_tolerance"]:
        return "calibration_recorded_outside_time_tolerance"
    if not drift_evidence["available"] or not drift_declaration["consistent"]:
        return "calibration_recorded_needs_local_review"

    return "calibration_locally_aligned_within_tolerance"


def load_json(path: Path) -> Any:
    def reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise HardenedCalibrationError(f"duplicate JSON key: {key!r}")
            result[key] = value
        return result

    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle, object_pairs_hook=reject_duplicates)
    except FileNotFoundError as error:
        raise HardenedCalibrationError(f"file not found: {path}") from error
    except json.JSONDecodeError as error:
        raise HardenedCalibrationError(f"invalid JSON: {error}") from error


def command_evaluate(args: argparse.Namespace) -> int:
    record = load_json(Path(args.record))
    require(isinstance(record, dict), "record must be an object")

    reference = validate_reference_artifact(record["reference_artifact"])
    evidence = validate_drift_evidence(record["drift_evidence"], reference)
    declaration = validate_drift_declaration(record["drift_declaration"], evidence)
    time_result = validate_time_reconciliation(record["local_time_reconciliation"], evidence)

    declared_hash = record.get("record_sha256")
    require(is_sha256(declared_hash), "record_sha256 must be SHA-256")
    computed_hash = object_hash(record, "record_sha256")
    record_digest_ok = computed_hash == declared_hash

    topology = record["topology_artifact"]
    require(isinstance(topology, dict), "topology_artifact must be an object")
    topology_ok = (
        topology.get("topology_applicability_state") == "applicable"
        and topology.get("graph_privacy_bounding_state") == "verified"
        and isinstance(topology.get("sensor_node_id"), str)
        and SENSOR_NODE.fullmatch(topology["sensor_node_id"]) is not None
    )

    geometry = record.get("geometry_artifact")
    geometry_ok = geometry is not None and (
        geometry.get("geometry_privacy_bounding_state") in {"verified", "not_applicable"}
    )

    currentness = record.get("currentness_state")
    require(currentness in CURRENTNESS_STATES, "currentness_state is invalid")

    fields_complete = True
    canonical_encoding_ok = True
    trust_root_ok = (
        isinstance(record.get("self_description"), dict)
        and is_sha256(record["self_description"].get("local_trust_root_sha256"))
    )

    usable_state = derive_usable_state(
        fields_complete=fields_complete,
        canonical_encoding=canonical_encoding_ok,
        record_digest=record_digest_ok,
        trust_root=trust_root_ok,
        reference=reference,
        drift_evidence=evidence,
        drift_declaration=declaration,
        topology_verified=topology_ok,
        geometry_verified=geometry_ok,
        time_result=time_result,
        currentness=currentness,
    )

    report = {
        "record_scoped_usable_state": usable_state,
        "calibration_purpose": record.get("calibration_purpose"),
        "non_claim": (
            "This is a local record-state result. It does not establish sensor "
            "accuracy, universal fitness, institutional certification, identity, "
            "attribution, or authority."
        ),
        "dimensions": {
            "reference": "verified" if reference["verified"] else "not_established",
            "drift_evidence": "verified" if evidence["available"] else "not_established",
            "drift_declaration": "verified" if declaration["consistent"] else "not_established",
            "time_reconciliation": "verified" if time_result["within_tolerance"] else "not_established",
            "topology": "verified" if topology_ok else "not_established",
            "geometry": "verified" if geometry_ok else "not_established",
            "record_digest": "verified" if record_digest_ok else "failed",
            "trust_root": "verified" if trust_root_ok else "not_established",
            "currentness": currentness,
        },
    }
    print(json.dumps(report, sort_keys=True, indent=2))
    return 0 if usable_state == "calibration_locally_aligned_within_tolerance" else 3


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Evaluate a hardened local offline calibration record."
    )
    commands = parser.add_subparsers(dest="command", required=True)

    evaluate = commands.add_parser(
        "evaluate",
        help="Derive the record-scoped usable calibration state.",
    )
    evaluate.add_argument("--record", required=True)
    evaluate.set_defaults(handler=command_evaluate)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.handler(args)
    except (HardenedCalibrationError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
