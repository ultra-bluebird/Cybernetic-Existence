package eco_restoration.governance

import java.security.PublicKey
import java.security.Signature
import java.time.Instant
import java.util.Base64

object ScopedDidVerification {
    const val EXPECTED_DID = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

    enum class Status {
        VERIFIED_SCOPED_KEY_CONTROL,
        WITHHELD,
        EXPIRED
    }

    data class VerificationRequest(
        val did: String,
        val scope: String,
        val challengeId: String,
        val issuedAt: Instant,
        val expiresAt: Instant,
        val consentScopeValid: Boolean,
        val retentionEligible: Boolean,
        val keyReference: String,
        val signatureAlgorithm: String,
        val signatureBase64: String
    ) {
        init {
            require(did.isNotBlank()) { "did must not be blank." }
            require(scope.isNotBlank()) { "scope must not be blank." }
            require(challengeId.isNotBlank()) { "challengeId must not be blank." }
            require(expiresAt.isAfter(issuedAt)) {
                "expiresAt must be after issuedAt."
            }
            require(keyReference.isNotBlank()) { "keyReference must not be blank." }
            require(signatureAlgorithm.isNotBlank()) {
                "signatureAlgorithm must not be blank."
            }
            require(signatureBase64.isNotBlank()) {
                "signatureBase64 must not be blank."
            }
        }
    }

    data class VerificationResult(
        val did: String,
        val scope: String,
        val challengeId: String,
        val verifiedAt: Instant,
        val status: Status,
        val reason: String
    )

    fun verify(
        request: VerificationRequest,
        publicKey: PublicKey,
        challengePayload: ByteArray,
        now: Instant
    ): VerificationResult {
        if (request.did != EXPECTED_DID) {
            return withheld(request, now, "The DID is outside this local verifier scope.")
        }

        if (!request.consentScopeValid || !request.retentionEligible) {
            return withheld(
                request,
                now,
                "Consent scope or retention eligibility is not valid."
            )
        }

        if (!now.isBefore(request.expiresAt)) {
            return VerificationResult(
                request.did,
                request.scope,
                request.challengeId,
                now,
                Status.EXPIRED,
                "The verification challenge has expired."
            )
        }

        val verified = try {
            val verifier = Signature.getInstance(request.signatureAlgorithm)
            verifier.initVerify(publicKey)
            verifier.update(canonicalMessage(request, challengePayload))
            verifier.verify(Base64.getDecoder().decode(request.signatureBase64))
        } catch (_: Exception) {
            false
        }

        return if (verified) {
            VerificationResult(
                request.did,
                request.scope,
                request.challengeId,
                now,
                Status.VERIFIED_SCOPED_KEY_CONTROL,
                "Signature verified for the declared local scope only."
            )
        } else {
            withheld(
                request,
                now,
                "Signature verification did not succeed for the declared scope."
            )
        }
    }

    fun canonicalMessage(
        request: VerificationRequest,
        challengePayload: ByteArray
    ): ByteArray {
        val encodedChallenge = Base64.getEncoder().encodeToString(challengePayload)

        return listOf(
            "did=${escape(request.did)}",
            "scope=${escape(request.scope)}",
            "challenge_id=${escape(request.challengeId)}",
            "issued_at_utc=${request.issuedAt}",
            "expires_at_utc=${request.expiresAt}",
            "key_reference=${escape(request.keyReference)}",
            "challenge=${escape(encodedChallenge)}"
        ).joinToString("\n").encodeToByteArray()
    }

    private fun withheld(
        request: VerificationRequest,
        now: Instant,
        reason: String
    ): VerificationResult {
        return VerificationResult(
            request.did,
            request.scope,
            request.challengeId,
            now,
            Status.WITHHELD,
            reason
        )
    }

    private fun escape(value: String): String {
        return value
            .replace("\\", "\\\\")
            .replace("\n", "\\n")
            .replace("=", "\\=")
    }
}
