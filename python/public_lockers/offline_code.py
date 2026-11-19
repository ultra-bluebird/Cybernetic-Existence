from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from hmac import compare_digest
from secrets import choice, token_bytes
from typing import Final


class LockerCodeValidationError(ValueError):
    pass


CODE_ALPHABET: Final[str] = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
CODE_LENGTH: Final[int] = 16
CODE_ENTROPY_BITS: Final[int] = 80


@dataclass(frozen=True)
class OfflineLockerRecord:
    compartment_label: str
    salt: bytes
    verifier_hash: bytes
    expires_at_unix_s: int
    used: bool
    failed_attempts: int
    maximum_failed_attempts: int
    signed_manifest_valid: bool
    tamper_detected: bool

    def __post_init__(self) -> None:
        if not self.compartment_label.strip():
            raise LockerCodeValidationError("compartment_label must be non-empty.")
        if len(self.salt) < 16:
            raise LockerCodeValidationError("salt must contain at least 128 bits.")
        if len(self.verifier_hash) != 32:
            raise LockerCodeValidationError("verifier_hash must be a SHA-256 digest.")
        if self.expires_at_unix_s <= 0:
            raise LockerCodeValidationError("expires_at_unix_s must be positive.")
        if self.failed_attempts < 0 or self.maximum_failed_attempts <= 0:
            raise LockerCodeValidationError("Attempt counters are invalid.")


@dataclass(frozen=True)
class LockerVerification:
    accepted: bool
    next_state: str
    failed_attempts: int
    reason: str
    recipient_identity_required: bool
    network_required: bool


def generate_one_time_code() -> str:
    return "".join(choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))


def code_entropy_bits() -> int:
    return CODE_ENTROPY_BITS


def verifier_digest(
    compartment_label: str,
    salt: bytes,
    code: str,
    expires_at_unix_s: int,
) -> bytes:
    if not compartment_label.strip():
        raise LockerCodeValidationError("compartment_label must be non-empty.")
    if len(salt) < 16:
        raise LockerCodeValidationError("salt must contain at least 128 bits.")
    if len(code) != CODE_LENGTH or any(character not in CODE_ALPHABET for character in code):
        raise LockerCodeValidationError("Code has an invalid format.")
    if expires_at_unix_s <= 0:
        raise LockerCodeValidationError("expires_at_unix_s must be positive.")

    material = (
        b"augmented-hub/public-locker/one-time-code/v1\x00"
        + compartment_label.encode("utf-8")
        + b"\x00"
        + salt
        + b"\x00"
        + code.encode("ascii")
        + b"\x00"
        + str(expires_at_unix_s).encode("ascii")
    )
    return sha256(material).digest()


def prepare_offline_record(
    compartment_label: str,
    expires_at_unix_s: int,
    maximum_failed_attempts: int = 5,
) -> tuple[str, OfflineLockerRecord]:
    if maximum_failed_attempts <= 0:
        raise LockerCodeValidationError("maximum_failed_attempts must be positive.")

    code = generate_one_time_code()
    salt = token_bytes(16)
    record = OfflineLockerRecord(
        compartment_label=compartment_label,
        salt=salt,
        verifier_hash=verifier_digest(
            compartment_label,
            salt,
            code,
            expires_at_unix_s,
        ),
        expires_at_unix_s=expires_at_unix_s,
        used=False,
        failed_attempts=0,
        maximum_failed_attempts=maximum_failed_attempts,
        signed_manifest_valid=True,
        tamper_detected=False,
    )
    return code, record


def verify_offline_code(
    record: OfflineLockerRecord,
    submitted_code: str,
    now_unix_s: int,
) -> LockerVerification:
    if record.tamper_detected:
        return LockerVerification(
            accepted=False,
            next_state="TAMPER_REVIEW_REQUIRED",
            failed_attempts=record.failed_attempts,
            reason="Locker tamper state requires authorized human review.",
            recipient_identity_required=False,
            network_required=False,
        )

    if not record.signed_manifest_valid:
        return LockerVerification(
            accepted=False,
            next_state="HUMAN_ASSISTANCE_REQUIRED",
            failed_attempts=record.failed_attempts,
            reason="The local signed manifest is invalid or unavailable.",
            recipient_identity_required=False,
            network_required=False,
        )

    if record.used:
        return LockerVerification(
            accepted=False,
            next_state="COLLECTION_CONFIRMED",
            failed_attempts=record.failed_attempts,
            reason="The one-time code was already used.",
            recipient_identity_required=False,
            network_required=False,
        )

    if now_unix_s > record.expires_at_unix_s:
        return LockerVerification(
            accepted=False,
            next_state="CODE_EXPIRED",
            failed_attempts=record.failed_attempts,
            reason="The one-time code expired. Accessible human assistance remains available.",
            recipient_identity_required=False,
            network_required=False,
        )

    if record.failed_attempts >= record.maximum_failed_attempts:
        return LockerVerification(
            accepted=False,
            next_state="ATTEMPT_LIMIT_REVIEW",
            failed_attempts=record.failed_attempts,
            reason="Attempt limit reached. Use the accessible human assistance pathway.",
            recipient_identity_required=False,
            network_required=False,
        )

    try:
        expected = verifier_digest(
            record.compartment_label,
            record.salt,
            submitted_code,
            record.expires_at_unix_s,
        )
    except LockerCodeValidationError:
        expected = b"\x00" * 32

    if compare_digest(expected, record.verifier_hash):
        return LockerVerification(
            accepted=True,
            next_state="ACCESS_OPEN",
            failed_attempts=record.failed_attempts,
            reason="Local one-time code verification succeeded.",
            recipient_identity_required=False,
            network_required=False,
        )

    return LockerVerification(
        accepted=False,
        next_state="READY_FOR_COLLECTION",
        failed_attempts=record.failed_attempts + 1,
        reason="The code did not match. The compartment remains available until review limits apply.",
        recipient_identity_required=False,
        network_required=False,
    )
