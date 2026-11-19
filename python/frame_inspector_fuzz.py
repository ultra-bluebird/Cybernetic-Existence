from __future__ import annotations

import json
import random
import subprocess
import sys
from pathlib import Path

MAX_CASE_BYTES = 20_000
CASES = 2_000

def mutated_case(seed: bytes, rng: random.Random) -> bytes:
    data = bytearray(seed)
    operations = rng.randint(1, 12)

    for _ in range(operations):
        operation = rng.choice(("insert", "delete", "flip", "repeat"))
        if operation == "insert" and len(data) < MAX_CASE_BYTES:
            index = rng.randrange(len(data) + 1)
            data[index:index] = bytes([rng.randrange(256)])
        elif operation == "delete" and data:
            del data[rng.randrange(len(data))]
        elif operation == "flip" and data:
            index = rng.randrange(len(data))
            data[index] ^= 1 << rng.randrange(8)
        elif operation == "repeat" and data and len(data) < MAX_CASE_BYTES:
            index = rng.randrange(len(data))
            data[index:index] = data[index:index + 1] * rng.randint(1, 128)

    return bytes(data[:MAX_CASE_BYTES])

def run_case(binary: Path, case: bytes) -> int:
    completed = subprocess.run(
        [str(binary)],
        input=case,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=1.0,
        check=False,
    )
    return completed.returncode

def main() -> int:
    if len(sys.argv) != 2:
        print("usage: frame_inspector_fuzz.py PATH_TO_INSPECTOR_BINARY", file=sys.stderr)
        return 2

    binary = Path(sys.argv[1]).resolve()
    if not binary.is_file():
        print("inspector binary does not exist", file=sys.stderr)
        return 2

    rng = random.Random(0x5AFE_2026)
    seeds = [
        b"{}",
        b"[]",
        br#"{"version":1}"#,
        b"[" * 128 + b"]" * 128,
        b'"' + b"a" * 8_192,
    ]

    failures: list[dict[str, object]] = []
    for index in range(CASES):
        seed = rng.choice(seeds)
        case = mutated_case(seed, rng)
        try:
            code = run_case(binary, case)
        except subprocess.TimeoutExpired:
            failures.append({"case": index, "kind": "timeout", "bytes": len(case)})
            continue

        if code not in (0, 1):
            failures.append(
                {"case": index, "kind": "unexpected_exit", "exit_code": code, "bytes": len(case)}
            )

    print(json.dumps({"cases": CASES, "failures": failures}, sort_keys=True))
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())
