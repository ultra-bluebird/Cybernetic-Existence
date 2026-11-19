from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from hashlib import sha256
from typing import Literal
import json
import uuid

LocationPrecision = Literal["NONE", "REGION", "GRID_1KM", "COARSE_GPS", "EXACT_GPS"]
ConsentState = Literal["NOT_REQUIRED", "APPROVED", "DECLINED"]

@dataclass(frozen=True)
class EcologicalObservation:
    observation_id: str
    captured_at: str
    category: str
    measurement: float
    unit: str
    method_version: str
    location_precision: LocationPrecision
    location_value: str | None
    consent_state: ConsentState
    previous_hash: str | None
    record_hash: str

def canonical_json(value: dict[str, object]) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")

def record_hash(record_without_hash: dict[str, object]) -> str:
    return sha256(canonical_json(record_without_hash)).hexdigest()

def create_observation(
    *,
    category: str,
    measurement: float,
    unit: str,
    method_version: str,
    location_precision: LocationPrecision = "NONE",
    location_value: str | None = None,
    consent_state: ConsentState = "NOT_REQUIRED",
    previous_hash: str | None = None,
) -> EcologicalObservation:
    if not category or len(category) > 64:
        raise ValueError("category must contain 1 to 64 characters")
    if not unit or len(unit) > 32:
        raise ValueError("unit must contain 1 to 32 characters")
    if location_precision == "NONE" and location_value is not None:
        raise ValueError("location_value requires an explicit location precision")
    if location_precision != "NONE" and consent_state != "APPROVED":
        raise ValueError("recorded location requires approved consent")
    if location_precision == "NONE" and location_value is not None:
        raise ValueError("location must be absent when precision is NONE")

    draft: dict[str, object] = {
        "observation_id": str(uuid.uuid4()),
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "category": category,
        "measurement": measurement,
        "unit": unit,
        "method_version": method_version,
        "location_precision": location_precision,
        "location_value": location_value,
        "consent_state": consent_state,
        "previous_hash": previous_hash,
    }

    return EcologicalObservation(**draft, record_hash=record_hash(draft))

def verify_observation(observation: EcologicalObservation) -> bool:
    value = asdict(observation)
    supplied_hash = value.pop("record_hash")
    return record_hash(value) == supplied_hash

def verify_chain(observations: list[EcologicalObservation]) -> bool:
    if not all(verify_observation(item) for item in observations):
        return False

    for index in range(1, len(observations)):
        if observations[index].previous_hash != observations[index - 1].record_hash:
            return False

    return True
