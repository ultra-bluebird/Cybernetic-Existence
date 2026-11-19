package org.augmentedhub.governance

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

enum class PrivateStatus {
    ACTIVE,
    DERATED,
    HALTED,
    INDETERMINATE
}

enum class UpdateDecision {
    ACCEPT,
    REJECT,
    REVIEW_REQUIRED
}

enum class CredentialDecision {
    ACCEPT,
    REJECT_DUPLICATE,
    PENDING_FRESH_STATUS,
    EQUIVOCATION_DETECTED,
    REJECT_INVALID
}

data class RequestBoundAuthorization(
    val requestId: String,
    val policyVersion: String,
    val purpose: String,
    val ownerAuthorized: Boolean,
    val nonInterferencePassed: Boolean,
    val privateScopeConfirmed: Boolean,
    val expiresAtEpochSeconds: Long
)

data class SovereigntyTransition(
    val previousStatus: PrivateStatus,
    val requestedStatus: PrivateStatus,
    val protectedCapabilitiesReduced: Boolean,
    val authorization: RequestBoundAuthorization,
    val nowEpochSeconds: Long
)

data class AccumulatorPresentation(
    val proofValid: Boolean,
    val epoch: Long,
    val epochIssuedAtSeconds: Long,
    val maximumStalenessSeconds: Long,
    val epochQuorumValid: Boolean,
    val equivocationDetected: Boolean,
    val challengeMatches: Boolean,
    val purposeMatches: Boolean,
    val audienceMatches: Boolean,
    val notExpired: Boolean,
    val nullifierUnused: Boolean
)

object PrivateGovernanceGuards {
    fun evaluateSovereigntyTransition(
        transition: SovereigntyTransition
    ): UpdateDecision {
        val authorization = transition.authorization

        require(transition.nowEpochSeconds >= 0L)
        require(authorization.expiresAtEpochSeconds >= 0L)
        require(authorization.requestId.isNotBlank())
        require(authorization.policyVersion.isNotBlank())
        require(authorization.purpose.isNotBlank())

        val statusReduced = transition.previousStatus == PrivateStatus.ACTIVE &&
            transition.requestedStatus != PrivateStatus.ACTIVE

        val protectedChange = statusReduced ||
            transition.protectedCapabilitiesReduced

        if (!protectedChange) {
            return UpdateDecision.ACCEPT
        }

        val authorizationValid = authorization.ownerAuthorized &&
            authorization.nonInterferencePassed &&
            authorization.privateScopeConfirmed &&
            transition.nowEpochSeconds <= authorization.expiresAtEpochSeconds

        return if (authorizationValid) {
            UpdateDecision.ACCEPT
        } else {
            UpdateDecision.REJECT
        }
    }

    fun evaluateAccumulatorPresentation(
        presentation: AccumulatorPresentation,
        nowEpochSeconds: Long
    ): CredentialDecision {
        require(nowEpochSeconds >= 0L)
        require(presentation.epoch >= 0L)
        require(presentation.epochIssuedAtSeconds >= 0L)
        require(presentation.maximumStalenessSeconds >= 0L)

        if (!presentation.proofValid ||
            !presentation.challengeMatches ||
            !presentation.purposeMatches ||
            !presentation.audienceMatches ||
            !presentation.notExpired
        ) {
            return CredentialDecision.REJECT_INVALID
        }

        if (presentation.equivocationDetected) {
            return CredentialDecision.EQUIVOCATION_DETECTED
        }

        if (!presentation.epochQuorumValid) {
            return CredentialDecision.PENDING_FRESH_STATUS
        }

        val age = nowEpochSeconds - presentation.epochIssuedAtSeconds

        if (age < 0L || age > presentation.maximumStalenessSeconds) {
            return CredentialDecision.PENDING_FRESH_STATUS
        }

        if (!presentation.nullifierUnused) {
            return CredentialDecision.REJECT_DUPLICATE
        }

        return CredentialDecision.ACCEPT
    }

    fun scopedAuditReference(
        scopeKey: ByteArray,
        auditEpoch: String,
        purpose: String,
        localSubjectReference: String,
        policyVersion: String
    ): String {
        require(scopeKey.isNotEmpty())
        require(auditEpoch.isNotBlank())
        require(purpose.isNotBlank())
        require(localSubjectReference.isNotBlank())
        require(policyVersion.isNotBlank())

        val message = listOf(
            "audit_epoch=$auditEpoch",
            "purpose=$purpose",
            "subject=$localSubjectReference",
            "policy_version=$policyVersion"
        ).joinToString("|")

        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(scopeKey, "HmacSHA256"))

        return mac.doFinal(message.encodeToByteArray())
            .joinToString("") { byte -> "%02x".format(byte) }
    }
}
