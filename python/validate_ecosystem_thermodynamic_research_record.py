#!/usr/bin/env python3
"""Focused semantic validator for ecosystem thermodynamic research records.

Complements (does not replace) JSON Schema validation of
``schemas/ecosystem_thermodynamic_research_record.schema.json`` using only the
Python standard library. Records are research and decision support subject to
human scientific and community-governance review; nothing here automates
ecological, land, or human decisions.

Usage:
    python python/validate_ecosystem_thermodynamic_research_record.py RECORD.json

Exit codes:
    0 - no semantic errors (warnings may be printed to stderr)
    1 - semantic validation errors found
    2 - input could not be read or parsed
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys
from typing import Any

ENTROPY_UNIT = "W K^-1 m^-2"

CONSTRAINT_NAMES = (
    "radiative_forcing",
    "water_availability",
    "temperature_boundary",
    "soil_or_substrate",
    "vegetation_structure",
    "hydrologic_connectivity",
    "disturbance_boundary",
)

REQUIRED_PROHIBITED_USES = (
    "human_or_community_ranking",
    "automated_enforcement",
    "land_displacement_decision",
    "benefit_or_service_eligibility",
)

REQUIRED_BASELINES = (
    "climate_only",
    "vegetation_only",
    "biodiversity_only",
    "hydrology_only",
)


def load_json(path: pathlib.Path) -> dict:
    """Read a UTF-8 JSON object from ``path``.

    Rejects non-object JSON roots and unreadable/unparsable files by printing
    a clear error to stderr and exiting with status code 2.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"Error: cannot read file {path}: {exc}", file=sys.stderr)
        sys.exit(2)

    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        print(f"Error: {path} is not valid JSON: {exc}", file=sys.stderr)
        sys.exit(2)

    if not isinstance(data, dict):
        print(
            f"Error: {path} must contain a JSON object at the root, "
            f"got {type(data).__name__}.",
            file=sys.stderr,
        )
        sys.exit(2)

    return data


def _is_finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) \
        and math.isfinite(value)


def validate_record(record: dict) -> list[str]:
    """Return a list of validation messages for one research record.

    Messages that begin with ``WARNING:`` are advisory diagnostic signals,
    not errors. All other messages are semantic validation errors. Out-of-range
    normalized diagnostics produce a warning only: values outside [0, 1] flag
    uncertainty, boundary mismatch, missing processes, measurement error, or
    model misspecification for human review and must never be clipped or
    silently rejected.
    """
    errors: list[str] = []

    # 1. Temporal ordering: start_date <= end_date (ISO dates compare lexically).
    temporal = record.get("temporal_scope", {})
    if isinstance(temporal, dict):
        start = temporal.get("start_date")
        end = temporal.get("end_date")
        if isinstance(start, str) and isinstance(end, str):
            if start > end:
                errors.append(
                    "temporal_scope.start_date must be less than or equal to "
                    "temporal_scope.end_date."
                )

    # Entropy production checks (2-8).
    entropy = record.get("entropy_production", {})
    if isinstance(entropy, dict):
        feasible_min = entropy.get("feasible_minimum")
        feasible_max = entropy.get("feasible_maximum")

        # 2. Feasible envelope must be strictly ordered so the Φ_F denominator
        #    is strictly positive.
        if _is_finite_number(feasible_min) and _is_finite_number(feasible_max):
            if not feasible_max > feasible_min:
                errors.append(
                    "entropy_production.feasible_maximum must be strictly "
                    "greater than entropy_production.feasible_minimum; the "
                    "normalized diagnostic is invalid unless the envelope "
                    "denominator is strictly positive."
                )

        # 3. Normalized diagnostic must be finite.
        diagnostic = entropy.get("normalized_diagnostic")
        if "normalized_diagnostic" in entropy and \
                not _is_finite_number(diagnostic):
            errors.append(
                "entropy_production.normalized_diagnostic must be a finite "
                "number."
            )
        elif _is_finite_number(diagnostic):
            # 4. Out-of-range diagnostics are warnings, never errors, and are
            #    never clipped.
            if diagnostic < 0.0 or diagnostic > 1.0:
                errors.append(
                    "WARNING: entropy_production.normalized_diagnostic is "
                    f"{diagnostic}, outside the closed interval [0, 1]. This "
                    "is a diagnostic signal requiring uncertainty, boundary, "
                    "and missing-process review; do not clip the value."
                )

        # 8. Entropy-production unit constant.
        if entropy.get("entropy_production_unit") != ENTROPY_UNIT:
            errors.append(
                "entropy_production.entropy_production_unit must equal "
                f"'{ENTROPY_UNIT}'."
            )

        # 6-7. Flux components: finite contributions and fixed contribution unit.
        flux_components = entropy.get("flux_components")
        if isinstance(flux_components, list):
            for index, component in enumerate(flux_components):
                if not isinstance(component, dict):
                    errors.append(
                        f"entropy_production.flux_components[{index}] must be "
                        "an object."
                    )
                    continue
                contribution = component.get("contribution_value")
                if not _is_finite_number(contribution):
                    errors.append(
                        f"entropy_production.flux_components[{index}]."
                        "contribution_value must be a finite number."
                    )
                if component.get("contribution_unit") != ENTROPY_UNIT:
                    errors.append(
                        f"entropy_production.flux_components[{index}]."
                        "contribution_unit must equal "
                        f"'{ENTROPY_UNIT}'."
                    )

    # 5. Every numerical constraint-vector value must be finite.
    constraints = record.get("constraint_vector", {})
    if isinstance(constraints, dict):
        for name in CONSTRAINT_NAMES:
            component = constraints.get(name)
            if isinstance(component, dict):
                value = component.get("value")
                if not _is_finite_number(value):
                    errors.append(
                        f"constraint_vector.{name}.value must be a finite "
                        "number."
                    )

    # 10. Baseline comparisons must include all four single-domain baselines.
    modeling = record.get("modeling", {})
    if isinstance(modeling, dict):
        baselines = modeling.get("baseline_comparisons")
        if isinstance(baselines, list):
            for baseline in REQUIRED_BASELINES:
                if baseline not in baselines:
                    errors.append(
                        "modeling.baseline_comparisons must include "
                        f"'{baseline}'."
                    )
        else:
            errors.append("modeling.baseline_comparisons must be an array.")

    # 9. Prohibited uses must include the four mandated exclusions.
    governance = record.get("governance", {})
    if isinstance(governance, dict):
        prohibited = governance.get("prohibited_uses")
        if isinstance(prohibited, list):
            for use in REQUIRED_PROHIBITED_USES:
                if use not in prohibited:
                    errors.append(
                        f"governance.prohibited_uses must include '{use}'."
                    )
        else:
            errors.append("governance.prohibited_uses must be an array.")

    # 11. Material changes always reopen review.
    review = record.get("review", {})
    if isinstance(review, dict):
        if review.get("material_change_review_required") is not True:
            errors.append(
                "review.material_change_review_required must be true."
            )
    else:
        errors.append("review must be an object.")

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Validate an ecosystem thermodynamic research record (semantic "
            "checks complementing JSON Schema validation)."
        )
    )
    parser.add_argument(
        "record",
        type=pathlib.Path,
        help="Path to the RECORD.json file to validate.",
    )
    args = parser.parse_args(argv)

    record = load_json(args.record)
    messages = validate_record(record)

    warnings = [m for m in messages if m.startswith("WARNING:")]
    errors = [m for m in messages if not m.startswith("WARNING:")]

    for warning in warnings:
        print(warning, file=sys.stderr)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(
            f"Validation failed with {len(errors)} error(s) and "
            f"{len(warnings)} warning(s).",
            file=sys.stderr,
        )
        return 1

    if warnings:
        print(
            f"Validation passed with {len(warnings)} warning(s); warnings "
            "require human review before interpretation.",
            file=sys.stderr,
        )
    else:
        print("Validation passed with no errors or warnings.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
