from __future__ import annotations

import argparse
import csv
import hashlib
import random
from dataclasses import dataclass
from pathlib import Path

FRAME_CLASSES = (
    "valid_canonical",
    "oversize",
    "unknown_field",
    "duplicate_key",
    "noncanonical_order",
    "unsupported_version",
    "invalid_nonce",
    "stale_sequence",
    "reused_nonce",
    "wrong_generation",
    "capability_denied",
    "rate_exhausted",
    "invalid_signature",
    "parser_disagreement",
    "audit_overflow",
)

OPERATIONS = (
    "identity.proof.verify",
    "session.status.read",
    "telemetry.summary.read",
)

DATA_CATEGORIES = (
    "communication_preference",
    "privacy_preference",
    "session_receipt",
)

REASONS = {
    "valid_canonical": "all_checks_passed",
    "oversize": "frame_too_large",
    "unknown_field": "unknown_field",
    "duplicate_key": "duplicate_key",
    "noncanonical_order": "noncanonical_encoding",
    "unsupported_version": "unsupported_version",
    "invalid_nonce": "invalid_nonce",
    "stale_sequence": "replay_detected",
    "reused_nonce": "replay_detected",
    "wrong_generation": "generation_mismatch",
    "capability_denied": "capability_denied",
    "rate_exhausted": "rate_limited",
    "invalid_signature": "authentication_failed",
    "parser_disagreement": "parser_differential",
    "audit_overflow": "aggregate_audit_only",
}

@dataclass(frozen=True)
class SyntheticRecord:
    case_id: str
    seed: int
    frame_class: str
    schema_version: str
    generation: int
    sequence: int
    payload_bytes: int
    operation: str
    data_category: str
    validation_outcome: str
    reason_code: str
    expected_dispatch: bool
    contains_sensitive_data: bool

def stable_case_id(seed: int, index: int, frame_class: str) -> str:
    material = f"msfp-synthetic-v1:{seed}:{index}:{frame_class}".encode()
    return hashlib.sha256(material).hexdigest()[:24]

def build_record(
    generator: random.Random,
    seed: int,
    index: int,
    max_frame_bytes: int,
) -> SyntheticRecord:
    frame_class = FRAME_CLASSES[index % len(FRAME_CLASSES)]
    operation = generator.choice(OPERATIONS)
    data_category = generator.choice(DATA_CATEGORIES)
    generation = generator.randint(1, 8)
    sequence = generator.randint(1, 100_000)

    if frame_class == "valid_canonical":
        payload_bytes = generator.randint(0, max_frame_bytes)
        outcome = "accepted"
        dispatch = True
        schema_version = "1"
    elif frame_class == "oversize":
        payload_bytes = max_frame_bytes + generator.randint(1, max_frame_bytes)
        outcome = "rejected"
        dispatch = False
        schema_version = "1"
    elif frame_class == "unsupported_version":
        payload_bytes = generator.randint(0, max_frame_bytes)
        outcome = "rejected"
        dispatch = False
        schema_version = generator.choice(("0", "2", "999"))
    else:
        payload_bytes = generator.randint(0, max_frame_bytes)
        outcome = "rejected"
        dispatch = False
        schema_version = "1"

    if frame_class == "capability_denied":
        operation = "command.execute"

    if frame_class == "wrong_generation":
        generation = 0

    if frame_class == "stale_sequence":
        sequence = 1

    return SyntheticRecord(
        case_id=stable_case_id(seed, index, frame_class),
        seed=seed,
        frame_class=frame_class,
        schema_version=schema_version,
        generation=generation,
        sequence=sequence,
        payload_bytes=payload_bytes,
        operation=operation,
        data_category=data_category,
        validation_outcome=outcome,
        reason_code=REASONS[frame_class],
        expected_dispatch=dispatch,
        contains_sensitive_data=False,
    )

def write_dataset(
    output_path: Path,
    records: list[SyntheticRecord],
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "case_id",
                "seed",
                "frame_class",
                "schema_version",
                "generation",
                "sequence",
                "payload_bytes",
                "operation",
                "data_category",
                "validation_outcome",
                "reason_code",
                "expected_dispatch",
                "contains_sensitive_data",
            ],
        )
        writer.writeheader()

        for record in records:
            writer.writerow(record.__dict__)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        default="tests/test-vectors/msfp-synthetic-telemetry.csv",
    )
    parser.add_argument("--seed", type=int, default=20260904)
    parser.add_argument("--records", type=int, default=1500)
    parser.add_argument("--max-frame-bytes", type=int, default=4096)
    args = parser.parse_args()

    if args.records <= 0:
        raise SystemExit("--records must be positive")

    if args.max_frame_bytes <= 0:
        raise SystemExit("--max-frame-bytes must be positive")

    generator = random.Random(args.seed)

    records = [
        build_record(
            generator,
            args.seed,
            index,
            args.max_frame_bytes,
        )
        for index in range(args.records)
    ]

    write_dataset(Path(args.output), records)

if __name__ == "__main__":
    main()
