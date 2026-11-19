from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from hashlib import sha256
from typing import Literal
import json

TransitionKind = Literal[
    "STATE_TRANSITION",
    "SYMMETRIC_MERGE",
    "REVOCATION",
    "RECOVERY_WITNESS",
    "POLICY_UPDATE",
]

@dataclass(frozen=True)
class Transition:
    record_version: int
    transition_kind: TransitionKind
    parent_hashes: tuple[str, ...]
    policy_version: str
    created_at: str
    content_commitment: str
    approval_commitment: str
    rights_regression_check: str
    transition_hash: str

def canonical_json(value: dict[str, object]) -> bytes:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")

def sha256_hex(value: dict[str, object]) -> str:
    return sha256(canonical_json(value)).hexdigest()

def validate_hash(value: str) -> None:
    if len(value) != 64 or any(character not in "0123456789abcdef" for character in value):
        raise ValueError("hash must be a lowercase SHA-256 hexadecimal digest")

def canonical_parent_set(parent_hashes: list[str] | tuple[str, ...]) -> tuple[str, ...]:
    parents = tuple(sorted(set(parent_hashes)))

    if len(parents) != len(parent_hashes):
        raise ValueError("duplicate parent hashes are not allowed")

    if len(parents) > 16:
        raise ValueError("too many parents")

    for parent_hash in parents:
        validate_hash(parent_hash)

    return parents

def create_transition(
    *,
    transition_kind: TransitionKind,
    parent_hashes: list[str] | tuple[str, ...],
    policy_version: str,
    content_commitment: str,
    approval_commitment: str,
    rights_regression_check: str = "PASSED",
    now: datetime | None = None,
) -> Transition:
    if not policy_version or len(policy_version) > 128:
        raise ValueError("policy_version must contain 1 to 128 characters")

    validate_hash(content_commitment)
    validate_hash(approval_commitment)

    parents = canonical_parent_set(parent_hashes)

    if transition_kind == "SYMMETRIC_MERGE" and len(parents) < 2:
        raise ValueError("a symmetric merge requires at least two parents")

    if rights_regression_check not in {"PASSED", "NOT_APPLICABLE"}:
        raise ValueError("invalid rights_regression_check")

    draft: dict[str, object] = {
        "record_version": 1,
        "transition_kind": transition_kind,
        "parent_hashes": parents,
        "policy_version": policy_version,
        "created_at": (now or datetime.now(timezone.utc)).isoformat(),
        "content_commitment": content_commitment,
        "approval_commitment": approval_commitment,
        "rights_regression_check": rights_regression_check,
    }

    return Transition(**draft, transition_hash=sha256_hex(draft))

def verify_transition(transition: Transition) -> bool:
    value = asdict(transition)
    supplied_hash = value.pop("transition_hash")

    if tuple(value["parent_hashes"]) != canonical_parent_set(value["parent_hashes"]):
        return False

    return sha256_hex(value) == supplied_hash

def is_acyclic(transitions: list[Transition]) -> bool:
    records = {transition.transition_hash: transition for transition in transitions}
    visited: set[str] = set()
    visiting: set[str] = set()

    def visit(node_hash: str) -> bool:
        if node_hash in visiting:
            return False
        if node_hash in visited:
            return True

        transition = records.get(node_hash)
        if transition is None:
            return False

        visiting.add(node_hash)
        for parent_hash in transition.parent_hashes:
            if parent_hash in records and not visit(parent_hash):
                return False
        visiting.remove(node_hash)
        visited.add(node_hash)
        return True

    return all(visit(node_hash) for node_hash in records)
