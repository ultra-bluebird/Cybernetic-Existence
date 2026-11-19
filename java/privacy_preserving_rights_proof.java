package org.augmentedhub.rights;

import java.time.Instant;
import java.util.Objects;
import java.util.Set;

public final class PrivacyPreservingRightsProof {
    public enum VerificationDecision {
        ACCEPTED_MINIMAL_CLAIM,
        REJECTED_INVALID_PROOF,
        REJECTED_EXPIRED,
        REJECTED_AUDIENCE_MISMATCH,
        REJECTED_REVOKED,
        HUMAN_FALLBACK_REQUIRED
    }

    public record ProofRequest(
            String relyingPartyReference,
            String nonce,
            Set<String> permittedClaimTypes,
            Instant expiresAt
    ) {
        public ProofRequest {
            Objects.requireNonNull(relyingPartyReference, "relyingPartyReference");
            Objects.requireNonNull(nonce, "nonce");
            Objects.requireNonNull(permittedClaimTypes, "permittedClaimTypes");
            Objects.requireNonNull(expiresAt, "expiresAt");

            if (relyingPartyReference.isBlank() || nonce.isBlank() || permittedClaimTypes.isEmpty()) {
                throw new IllegalArgumentException("Proof request fields must be present.");
            }
        }
    }

    public record MinimalClaim(
            String claimType,
            boolean satisfied,
            Instant notBefore,
            Instant expiresAt,
            String issuerKeyReference
    ) {
        public MinimalClaim {
            Objects.requireNonNull(claimType, "claimType");
            Objects.requireNonNull(notBefore, "notBefore");
            Objects.requireNonNull(expiresAt, "expiresAt");
            Objects.requireNonNull(issuerKeyReference, "issuerKeyReference");

            if (claimType.isBlank() || issuerKeyReference.isBlank() || expiresAt.isBefore(notBefore)) {
                throw new IllegalArgumentException("Minimal claim fields are invalid.");
            }
        }
    }

    public record ProofPresentation(
            String proofSystem,
            String proofBytesBase64,
            String audienceBinding,
            String nonceBinding,
            MinimalClaim disclosedMinimalClaim
    ) {
        public ProofPresentation {
            Objects.requireNonNull(proofSystem, "proofSystem");
            Objects.requireNonNull(proofBytesBase64, "proofBytesBase64");
            Objects.requireNonNull(audienceBinding, "audienceBinding");
            Objects.requireNonNull(nonceBinding, "nonceBinding");
            Objects.requireNonNull(disclosedMinimalClaim, "disclosedMinimalClaim");

            if (proofSystem.isBlank() || proofBytesBase64.isBlank()
                    || audienceBinding.isBlank() || nonceBinding.isBlank()) {
                throw new IllegalArgumentException("Proof presentation fields must be present.");
            }
        }
    }

    public interface VerifiedProofProvider {
        boolean verify(ProofRequest request, ProofPresentation presentation);
        boolean isIssuerKeyTrusted(String issuerKeyReference);
        boolean isClaimRevoked(MinimalClaim claim);
    }

    public record VerificationResult(
            VerificationDecision decision,
            String reason,
            MinimalClaim acceptedClaim
    ) {}

    private final VerifiedProofProvider provider;

    public PrivacyPreservingRightsProof(VerifiedProofProvider provider) {
        this.provider = Objects.requireNonNull(provider, "provider");
    }

    public VerificationResult verify(
            ProofRequest request,
            ProofPresentation presentation,
            Instant now) {

        Objects.requireNonNull(request, "request");
        Objects.requireNonNull(presentation, "presentation");
        Objects.requireNonNull(now, "now");

        if (!request.relyingPartyReference().equals(presentation.audienceBinding())
                || !request.nonce().equals(presentation.nonceBinding())) {
            return reject(
                    VerificationDecision.REJECTED_AUDIENCE_MISMATCH,
                    "The proof is not bound to this relying party and request nonce.");
        }

        final MinimalClaim claim = presentation.disclosedMinimalClaim();

        if (!request.permittedClaimTypes().contains(claim.claimType())
                || !claim.satisfied()
                || !provider.isIssuerKeyTrusted(claim.issuerKeyReference())) {
            return reject(
                    VerificationDecision.REJECTED_INVALID_PROOF,
                    "The requested minimal claim is absent, unsatisfied, or issued by an untrusted key.");
        }

        if (now.isBefore(claim.notBefore()) || now.isAfter(claim.expiresAt())
                || now.isAfter(request.expiresAt())) {
            return reject(
                    VerificationDecision.REJECTED_EXPIRED,
                    "The proof or minimal claim is outside its valid time window.");
        }

        if (provider.isClaimRevoked(claim)) {
            return reject(
                    VerificationDecision.REJECTED_REVOKED,
                    "The minimal claim is revoked.");
        }

        if (!provider.verify(request, presentation)) {
            return reject(
                    VerificationDecision.REJECTED_INVALID_PROOF,
                    "The configured cryptographic provider rejected the proof.");
        }

        return new VerificationResult(
                VerificationDecision.ACCEPTED_MINIMAL_CLAIM,
                "A minimal scoped claim was verified without requesting identity disclosure.",
                claim);
    }

    public VerificationResult humanFallback() {
        return new VerificationResult(
                VerificationDecision.HUMAN_FALLBACK_REQUIRED,
                "Provide an equivalent accessible human review path without requiring proof use.",
                null);
    }

    private static VerificationResult reject(VerificationDecision decision, String reason) {
        return new VerificationResult(decision, reason, null);
    }
}
