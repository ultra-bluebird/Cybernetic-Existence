"""Research-only CyberJudgement packet inspection.

Dependency:
    python -m pip install jsonschema

Usage:
    python research/appeals/inspect_cyberjudgement_packet.py \
        schemas/research/cyberjudgement-record.schema.json \
        path/to/authorized-research-record.json

No networking, signing, enforcement, or appeal-admissibility decision.
Do not use confidential records in an unsecured terminal or environment.
"""

import argparse
import json
from pathlib import Path

from jsonschema import Draft202012Validator


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


def reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON property.")
        result[key] = value
    return result


def load_json(path):
    text = Path(path).read_text(encoding="utf-8")
    return json.loads(text, object_pairs_hook=reject_duplicate_keys)


def inspect_packet(schema, record):
    Draft202012Validator.check_schema(schema)
    errors = sorted(
        Draft202012Validator(schema).iter_errors(record),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    if errors:
        return {
            "structure": "invalid",
            "error_count": len(errors),
            "error_locations": [
                list(error.absolute_path) for error in errors
            ],
            "appeal_admissibility": "not_determined",
            "next_step": "correct_record_or_seek_record_production_assistance",
        }

    gaps = {}
    for item in record["packet"]:
        state = item["availability"]
        if state != "available":
            gaps[state] = gaps.get(state, 0) + 1

    return {
        "structure": "valid",
        "packet_gaps": gaps,
        "findings_without_recorded_support": sum(
            not finding["support"] for finding in record["findings"]
        ),
        "unfamiliarity_reasoning_requires_attention": any(
            finding["unfamiliarity_role"]
            in ("material_to_reasoning", "role_unresolved")
            for finding in record["findings"]
        ),
        "appeal_admissibility": "not_determined",
        "notice": (
            "Structure and disclosed gaps only; no evidence authenticity, "
            "legal adequacy, or substantive fairness is established."
        ),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("schema")
    parser.add_argument("record")
    arguments = parser.parse_args()

    try:
        schema = load_json(arguments.schema)
        record = load_json(arguments.record)
        result = inspect_packet(schema, record)
    except (OSError, ValueError, RecursionError):
        parser.exit(2, "Input could not be read or parsed safely.\n")

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
