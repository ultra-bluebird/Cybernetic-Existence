from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from hashlib import sha256
from uuid import uuid4
import json

@dataclass(frozen=True)
class ConsentReceipt:
    receipt_version: int
    receipt_id: str
    event_time: str
    session_pseudonym: str
    policy_ver: str
    outcome: str
    reason_code: str
    data_cats_requested: list[str]
    data_cats_released: list[str]
    retention_class: str
    receipt_hash: str

def canonical_json(value: dict[str, object]) -> bytes:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")

def compute_receipt_hash(value: dict[str, object]) -> str:
    return sha256(canonical_json(value)).hexdigest()

def create_receipt(
    *,
    session_pseudonym: str,
    policy_ver: str,
    outcome: str,
    reason_code: str,
    data_cats_requested: list[str],
    data_cats_released: list[str],
    retention_class: str,
) -> ConsentReceipt:
    requested = sorted(set(data_cats_requested))
    released = sorted(set(data_cats_released))

    if not set(released).issubset(requested):
        raise ValueError("released data categories must be a subset of requested categories")

    if not session_pseudonym or len(session_pseudonym) > 128:
        raise ValueError("invalid session pseudonym")

    draft: dict[str, object] = {
        "receipt_version": 1,
        "receipt_id": str(uuid4()),
        "event_time": datetime.now(timezone.utc).isoformat(),
        "session_pseudonym": session_pseudonym,
        "policy_ver": policy_ver,
        "outcome": outcome,
        "reason_code": reason_code,
        "data_cats_requested": requested,
        "data_cats_released": released,
        "retention_class": retention_class,
    }

    return ConsentReceipt(
        **draft,
        receipt_hash=compute_receipt_hash(draft),
    )

def machine_readable_json(receipt: ConsentReceipt) -> str:
    return canonical_json(asdict(receipt)).decode("utf-8")

def human_readable_text(receipt: ConsentReceipt) -> str:
    requested = ", ".join(receipt.data_cats_requested) or "none"
    released = ", ".join(receipt.data_cats_released) or "none"

    return "\n".join(
        [
            "CONSENT RECEIPT",
            f"Receipt ID: {receipt.receipt_id}",
            f"Time: {receipt.event_time}",
            f"Session: {receipt.session_pseudonym}",
            f"Policy version: {receipt.policy_ver}",
            f"Outcome: {receipt.outcome}",
            f"Reason: {receipt.reason_code}",
            f"Requested categories: {requested}",
            f"Released categories: {released}",
            f"Retention: {receipt.retention_class}",
            f"Integrity hash: {receipt.receipt_hash}",
            "This receipt contains no raw request payload, credential, or decrypted content."
        ]
    )

def qr_payload(receipt: ConsentReceipt) -> str:
    payload = {
        "v": receipt.receipt_version,
        "id": receipt.receipt_id,
        "t": receipt.event_time,
        "s": receipt.session_pseudonym,
        "p": receipt.policy_ver,
        "o": receipt.outcome,
        "r": receipt.reason_code,
        "q": receipt.data_cats_requested,
        "d": receipt.data_cats_released,
        "k": receipt.retention_class,
        "h": receipt.receipt_hash,
    }
    return canonical_json(payload).decode("utf-8")
