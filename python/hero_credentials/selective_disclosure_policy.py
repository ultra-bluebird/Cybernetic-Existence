from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum


class CredentialStatus(str, Enum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    REVOKED = "revoked"
    EXPIRED = "expired"


@dataclass(frozen=True)
class PresentationRequest:
    verifier_domain: str
    purpose: str
    requested_entitlement: str
    requested_at: datetime
    requested_claims: tuple[str, ...]


@dataclass(frozen=True)
class CredentialPolicy:
    status: CredentialStatus
    valid_from: datetime
    valid_until: datetime
    allowed_entitlements: frozenset[str]
    issuer_trusted: bool
    proof_signature_valid: bool
    zero_knowledge_proof_valid: bool
    context_binding_valid: bool
    holder_identity_disclosed: bool
    title_tier_disclosed: bool
    persistent_holder_identifier_disclosed: bool


@dataclass(frozen=True)
class VerificationDecision:
    accepted: bool
    reason: str
    disclosed_claims: tuple[str, ...]


def verify_selective_disclosure(
    request: PresentationRequest,
    policy: CredentialPolicy,
) -> VerificationDecision:
    if request.requested_at.tzinfo is None:
        raise ValueError("requested_at must be timezone-aware.")
    if policy.valid_from.tzinfo is None or policy.valid_until.tzinfo is None:
        raise ValueError("Credential validity timestamps must be timezone-aware.")
    if not request.verifier_domain.strip():
        raise ValueError("verifier_domain is required.")
    if not request.purpose.strip():
        raise ValueError("purpose is required.")
    if not request.requested_entitlement.strip():
        raise ValueError("requested_entitlement is required.")

    if policy.holder_identity_disclosed:
        return VerificationDecision(
            accepted=False,
            reason="Rejected because full holder identity disclosure is not permitted.",
            disclosed_claims=(),
        )

    if policy.title_tier_disclosed:
        return VerificationDecision(
            accepted=False,
            reason="Rejected because exact title tier disclosure is not permitted.",
            disclosed_claims=(),
        )

    if policy.persistent_holder_identifier_disclosed:
        return VerificationDecision(
            accepted=False,
            reason=(
                "Rejected because a persistent holder identifier would enable "
                "cross-context correlation."
            ),
            disclosed_claims=(),
        )

    if policy.status is not CredentialStatus.ACTIVE:
        return VerificationDecision(
            accepted=False,
            reason=f"Credential is not active: {policy.status.value}.",
            disclosed_claims=(),
        )

    requested_at = request.requested_at.astimezone(timezone.utc)
    valid_from = policy.valid_from.astimezone(timezone.utc)
    valid_until = policy.valid_until.astimezone(timezone.utc)

    if requested_at < valid_from or requested_at > valid_until:
        return VerificationDecision(
            accepted=False,
            reason="Credential is outside its validity window.",
            disclosed_claims=(),
        )

    if not policy.issuer_trusted:
        return VerificationDecision(
            accepted=False,
            reason="Credential issuer is not trusted for this verification policy.",
            disclosed_claims=(),
        )

    if not policy.proof_signature_valid:
        return VerificationDecision(
            accepted=False,
            reason="Credential signature validation failed.",
            disclosed_claims=(),
        )

    if not policy.zero_knowledge_proof_valid:
        return VerificationDecision(
            accepted=False,
            reason="Zero-knowledge proof validation failed.",
            disclosed_claims=(),
        )

    if not policy.context_binding_valid:
        return VerificationDecision(
            accepted=False,
            reason="Presentation is not bound to this verifier and stated purpose.",
            disclosed_claims=(),
        )

    if request.requested_entitlement not in policy.allowed_entitlements:
        return VerificationDecision(
            accepted=False,
            reason="Credential does not establish the requested entitlement.",
            disclosed_claims=(),
        )

    permitted_claims = {
        "entitlement",
        "presentation_expiry",
        "credential_status",
        "issuer",
    }

    if any(claim not in permitted_claims for claim in request.requested_claims):
        return VerificationDecision(
            accepted=False,
            reason="The verifier requested claims beyond the minimum necessary scope.",
            disclosed_claims=(),
        )

    return VerificationDecision(
        accepted=True,
        reason=(
            "Verified a context-bound entitlement without identity, exact tier, "
            "or persistent holder identifier disclosure."
        ),
        disclosed_claims=(
            "entitlement",
            "credential_status",
            "presentation_expiry",
            "issuer",
        ),
    )
