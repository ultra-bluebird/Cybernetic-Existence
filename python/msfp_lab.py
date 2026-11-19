from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import FrozenSet

FORBIDDEN_AUDIT_KEYS = frozenset(
    {
        "payload",
        "plaintext",
        "ciphertext",
        "credential",
        "token",
        "network_address",
        "biometric_data",
        "device_inventory",
        "identity",
    }
)

@dataclass
class Lease:
    expires_at: int
    revoked: bool = False
    integrity_ok: bool = True
    budget: int = 1

    def active(self, now: int) -> bool:
        return (
            now < self.expires_at
            and not self.revoked
            and self.integrity_ok
            and self.budget > 0
        )

    def consume(self, now: int) -> bool:
        if not self.active(now):
            return False
        self.budget -= 1
        return True

    def restart_boundary(self) -> None:
        self.revoked = True
        self.integrity_ok = False
        self.budget = 0

@dataclass
class LabResult:
    name: str
    passed: bool
    details: str

def test_timeout_race() -> LabResult:
    lease = Lease(expires_at=10)
    admitted_at_nine = lease.active(9)
    released_at_ten = lease.consume(10)
    return LabResult(
        "timeout_race",
        admitted_at_nine and not released_at_ten,
        "A release must recheck expiry at release time.",
    )

def test_revocation_race() -> LabResult:
    lease = Lease(expires_at=100)
    admitted = lease.active(1)
    lease.revoked = True
    released = lease.consume(2)
    return LabResult(
        "revocation_race",
        admitted and not released,
        "Revocation after admission blocks release.",
    )

def test_capability_escalation() -> LabResult:
    requested: FrozenSet[str] = frozenset({"read"})
    policy_grant: FrozenSet[str] = frozenset({"read", "admin"})
    permitted = policy_grant.issubset(requested)
    return LabResult(
        "capability_escalation",
        not permitted,
        "A policy result may not grant outside requested capability scope.",
    )

def test_restart_no_resurrection() -> LabResult:
    lease = Lease(expires_at=100, budget=2)
    lease.restart_boundary()
    return LabResult(
        "restart_no_resurrection",
        not lease.active(1) and not lease.consume(1),
        "Restart clears volatile session authority.",
    )

def test_log_redaction() -> LabResult:
    permitted = {
        "event_type": "FRAME_REJECTED",
        "event_time": "2026-09-04T22:52:00-07:00",
        "session_pseudonym": "session-pseudo-1",
        "policy_ver": "2026-09-04",
        "outcome": "BLOCKED",
        "reason_code": "UNKNOWN_FIELD",
        "data_cats_requested": ["consent_state"],
        "data_cats_released": [],
        "retention_class": "OPERATIONAL_30D",
    }
    leaked = dict(permitted)
    leaked["plaintext"] = "must-not-log"

    allowed_ok = not (set(permitted) & FORBIDDEN_AUDIT_KEYS)
    leaked_detected = bool(set(leaked) & FORBIDDEN_AUDIT_KEYS)

    return LabResult(
        "log_redaction",
        allowed_ok and leaked_detected,
        "Audit schemas reject payload and secret-like keys.",
    )

def main() -> int:
    results = [
        test_timeout_race(),
        test_revocation_race(),
        test_capability_escalation(),
        test_restart_no_resurrection(),
        test_log_redaction(),
    ]
    report = {
        "passed": all(result.passed for result in results),
        "results": [result.__dict__ for result in results],
    }
    print(json.dumps(report, sort_keys=True))
    return 0 if report["passed"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
