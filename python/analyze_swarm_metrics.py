from __future__ import annotations

import argparse
import csv
import math
from collections import defaultdict
from pathlib import Path
from statistics import mean, pstdev

REQUIRED_COLUMNS = {
    "simulation_generation",
    "policy_version",
    "eligible_nodes",
    "accept_votes",
    "reject_votes",
    "abstain_votes",
    "quarantined_nodes",
    "revoked_nodes",
    "required_final_quorum",
    "decision",
}

def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)

        if reader.fieldnames is None:
            raise ValueError("missing CSV header")

        missing = REQUIRED_COLUMNS.difference(reader.fieldnames)
        if missing:
            raise ValueError(f"missing columns: {sorted(missing)}")

        return list(reader)

def to_int(row: dict[str, str], key: str) -> int:
    value = int(row[key])

    if value < 0:
        raise ValueError(f"{key} must be non-negative")

    return value

def quorum_margin(
    accept_votes: int,
    reject_votes: int,
    required_final_quorum: int,
) -> int:
    leading_votes = max(accept_votes, reject_votes)
    return leading_votes - required_final_quorum

def summarize(rows: list[dict[str, str]]) -> dict[str, object]:
    decisions = defaultdict(int)
    margins: list[int] = []
    eligible_counts: list[int] = []
    quarantined_counts: list[int] = []
    revoked_counts: list[int] = []

    for row in rows:
        accept_votes = to_int(row, "accept_votes")
        reject_votes = to_int(row, "reject_votes")
        required_quorum = to_int(row, "required_final_quorum")

        decisions[row["decision"]] += 1
        margins.append(
            quorum_margin(
                accept_votes,
                reject_votes,
                required_quorum,
            )
        )
        eligible_counts.append(to_int(row, "eligible_nodes"))
        quarantined_counts.append(to_int(row, "quarantined_nodes"))
        revoked_counts.append(to_int(row, "revoked_nodes"))

    count = len(rows)

    if count == 0:
        raise ValueError("no rows supplied")

    return {
        "records": count,
        "decision_counts": dict(sorted(decisions.items())),
        "eligible_mean": mean(eligible_counts),
        "eligible_stddev": pstdev(eligible_counts),
        "quarantined_mean": mean(quarantined_counts),
        "revoked_mean": mean(revoked_counts),
        "quorum_margin_mean": mean(margins),
        "quorum_margin_min": min(margins),
        "quorum_margin_max": max(margins),
        "finite_metrics": all(
            math.isfinite(value)
            for value in [
                mean(eligible_counts),
                pstdev(eligible_counts),
                mean(quarantined_counts),
                mean(revoked_counts),
                mean(margins),
            ]
        ),
    }

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_csv")
    args = parser.parse_args()

    summary = summarize(read_rows(Path(args.input_csv)))

    for key, value in summary.items():
        print(f"{key}={value}")

if __name__ == "__main__":
    main()
