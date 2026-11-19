from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from hashlib import sha256
from typing import Literal
from uuid import uuid4
import json

LocationPrecision = Literal["NONE", "REGION", "GRID_1KM", "COARSE_GPS", "EXACT_GPS"]
ConsentState = Literal["NOT_REQUIRED", "APPROVED", "DECLINED"]

MAX_RETENTION_DAYS = 3650

@dataclass(frozen=True)
class CivicEcologicalObservation:
    record_version: int
    observation_id: str
    observed_at: str
    category: str
    measurement: float
    unit: str
    method_version: str
    location_precision: LocationPrecision
    location_value: str | None
    consent_state: ConsentState
    governance_profile: str
    purpose_code: str
    purpose_retention_days: int
    user_retention_days: int
    delete_after: str
    previous_hash: str | None
    record_hash: str

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

def retention_days(purpose_days: int, user_days: int) -> int:
    if not 1 <= purpose_days <= MAX_RETENTION_DAYS:
        raise ValueError("purpose_retention_days is outside the supported range")
    if not 1 <= user_days <= MAX_RETENTION_DAYS:
        raise ValueError("user_retention_days is outside the supported range")
    return min(purpose_days, user_days)

def validate_location(
    location_precision: LocationPrecision,
    location_value: str | None,
    consent_state: ConsentState,
) -> None:
    if location_precision == "NONE" and location_value is not None:
        raise ValueError("location_value must be absent when location_precision is NONE")

    if location_precision != "NONE" and consent_state != "APPROVED":
        raise ValueError("recorded location requires approved consent")

    if location_precision != "NONE" and not location_value:
        raise ValueError("recorded location requires a non-empty location_value")

def create_observation(
    *,
    category: str,
    measurement: float,
    unit: str,
    method_version: str,
    governance_profile: str,
    purpose_code: str,
    purpose_retention_days: int,
    user_retention_days: int,
    location_precision: LocationPrecision = "NONE",
    location_value: str | None = None,
    consent_state: ConsentState = "NOT_REQUIRED",
    previous_hash: str | None = None,
    now: datetime | None = None,
) -> CivicEcologicalObservation:
    if not category or len(category) > 64:
        raise ValueError("category must contain 1 to 64 characters")
    if not unit or len(unit) > 32:
        raise ValueError("unit must contain 1 to 32 characters")
    if not method_version or len(method_version) > 64:
        raise ValueError("method_version must contain 1 to 64 characters")
    if not governance_profile or len(governance_profile) > 64:
        raise ValueError("governance_profile must contain 1 to 64 characters")
    if not purpose_code or len(purpose_code) > 64:
        raise ValueError("purpose_code must contain 1 to 64 characters")

    validate_location(location_precision, location_value, consent_state)

    created_at = now or datetime.now(timezone.utc)
    effective_retention_days = retention_days(
        purpose_retention_days,
        user_retention_days,
    )
    delete_after = created_at + timedelta(days=effective_retention_days)

    draft: dict[str, object] = {
        "record_version": 1,
        "observation_id": str(uuid4()),
        "observed_at": created_at.isoformat(),
        "category": category,
        "measurement": measurement,
        "unit": unit,
        "method_version": method_version,
        "location_precision": location_precision,
        "location_value": location_value,
        "consent_state": consent_state,
        "governance_profile": governance_profile,
        "purpose_code": purpose_code,
        "purpose_retention_days": purpose_retention_days,
        "user_retention_days": user_retention_days,
        "delete_after": delete_after.isoformat(),
        "previous_hash": previous_hash,
    }

    return CivicEcologicalObservation(
        **draft,
        record_hash=sha256_hex(draft),
    )

def is_retained(record: CivicEcologicalObservation, now: datetime | None = None) -> bool:
    current_time = now or datetime.now(timezone.utc)
    deadline = datetime.fromisoformat(record.delete_after)
    return current_time < deadline

def verify_record(record: CivicEcologicalObservation) -> bool:
    value = asdict(record)
    supplied_hash = value.pop("record_hash")
    return sha256_hex(value) == supplied_hash

def verify_chain(records: list[CivicEcologicalObservation]) -> bool:
    if not all(verify_record(record) for record in records):
        return False

    for index in range(1, len(records)):
        if records[index].previous_hash != records[index - 1].record_hash:
            return False

    return True
