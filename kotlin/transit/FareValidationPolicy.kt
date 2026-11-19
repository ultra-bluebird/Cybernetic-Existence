package augmentedhub.transit

import java.time.Duration
import java.time.Instant

enum class FareMedium {
    ANONYMOUS_NFC_TOKEN,
    DISPOSABLE_PAPER_TOKEN,
    ACCESSIBLE_ASSISTANCE_PANEL,
    OPTIONAL_DEVICE_WALLET,
    OFFLINE_STORED_VALUE_MEDIA
}

enum class ValidationDecision {
    ACCEPT,
    COURTESY_ASSISTANCE_REQUIRED,
    REJECT_CONFIGURATION
}

enum class CourtesyReason {
    NONE,
    TOKEN_UNREADABLE,
    TOKEN_EXPIRED,
    TOKEN_ALREADY_PRESENTED,
    VALIDATOR_OFFLINE_LIMIT_REACHED,
    ACCESSIBILITY_ASSISTANCE_REQUESTED,
    VALIDATOR_HEALTH_DEGRADED
}

data class FareValidationPolicy(
    val schema: String,
    val policyName: String,
    val effectiveFrom: Instant,
    val universalValidationRequired: Boolean,
    val deviceFreeAlternativeRequired: Boolean,
    val offlinePaymentRequired: Boolean,
    val firstNonValidationRequiresCourtesy: Boolean,
    val humanSelectionForInspectionAllowed: Boolean,
    val identityAttributesStored: Boolean,
    val routeHistoryStored: Boolean,
    val persistentDeviceIdentifierStored: Boolean,
    val aggregateReportingOnly: Boolean,
    val maximumOfflineTokenAge: Duration,
    val minimumSupportedMedia: Set<FareMedium>
) {
    fun validate(): FareValidationPolicy {
        require(schema == "javasphere.transit-fare-validation-policy/v1") {
            "Unsupported policy schema."
        }
        require(policyName.matches(Regex("^[a-z][a-z0-9-]{2,95}$"))) {
            "policyName must be a lowercase identifier."
        }
        require(universalValidationRequired) {
            "Universal validation is required."
        }
        require(deviceFreeAlternativeRequired) {
            "A device-free validation alternative is required."
        }
        require(offlinePaymentRequired) {
            "Offline payment support is required."
        }
        require(firstNonValidationRequiresCourtesy) {
            "A first non-validation must use the courtesy path."
        }
        require(!humanSelectionForInspectionAllowed) {
            "Discretionary human selection is prohibited."
        }
        require(!identityAttributesStored) {
            "Identity attributes must not be stored."
        }
        require(!routeHistoryStored) {
            "Route-history storage is prohibited."
        }
        require(!persistentDeviceIdentifierStored) {
            "Persistent device identifiers must not be stored."
        }
        require(aggregateReportingOnly) {
            "Only aggregate reporting is permitted."
        }
        require(!maximumOfflineTokenAge.isNegative && !maximumOfflineTokenAge.isZero) {
            "maximumOfflineTokenAge must be positive."
        }
        require(maximumOfflineTokenAge <= Duration.ofHours(24)) {
            "maximumOfflineTokenAge may not exceed 24 hours."
        }
        require(
            minimumSupportedMedia.contains(FareMedium.ANONYMOUS_NFC_TOKEN) &&
                minimumSupportedMedia.contains(FareMedium.DISPOSABLE_PAPER_TOKEN) &&
                minimumSupportedMedia.contains(FareMedium.ACCESSIBLE_ASSISTANCE_PANEL) &&
                minimumSupportedMedia.contains(FareMedium.OFFLINE_STORED_VALUE_MEDIA)
        ) {
            "The policy must support anonymous, paper, assistance, and offline media."
        }
        return this
    }
}

data class FarePresentation(
    val tokenCommitment: ByteArray,
    val issuerSignature: ByteArray,
    val validatorNonce: ByteArray,
    val issuedAt: Instant,
    val expiresAt: Instant,
    val fareMedium: FareMedium,
    val accessibilityAssistanceRequested: Boolean
)

data class ValidatorHealth(
    val signatureVerifierReady: Boolean,
    val spentTokenStoreReady: Boolean,
    val clockTrusted: Boolean,
    val aggregateReportingReady: Boolean
)

data class FareValidationResult(
    val decision: ValidationDecision,
    val reason: CourtesyReason,
    val retainSpentMarkerUntil: Instant?,
    val humanSelectionAllowed: Boolean,
    val identityCollectionAllowed: Boolean,
    val routeHistoryCollectionAllowed: Boolean,
    val aggregateEventOnly: Boolean
)

interface TokenSignatureVerifier {
    fun verify(
        tokenCommitment: ByteArray,
        issuerSignature: ByteArray,
        validatorNonce: ByteArray
    ): Boolean
}

interface SpentTokenStore {
    fun hasSpent(tokenDigest: ByteArray, now: Instant): Boolean
    fun markSpent(tokenDigest: ByteArray, expiresAt: Instant)
}

interface TokenDigest {
    fun digest(
        tokenCommitment: ByteArray,
        validatorNonce: ByteArray
    ): ByteArray
}

class FareValidationEngine(
    private val policy: FareValidationPolicy,
    private val signatureVerifier: TokenSignatureVerifier,
    private val spentTokenStore: SpentTokenStore,
    private val tokenDigest: TokenDigest
) {
    init {
        policy.validate()
    }

    fun validate(
        presentation: FarePresentation,
        health: ValidatorHealth,
        now: Instant
    ): FareValidationResult {
        if (!health.signatureVerifierReady ||
            !health.spentTokenStoreReady ||
            !health.clockTrusted ||
            !health.aggregateReportingReady
        ) {
            return courtesy(CourtesyReason.VALIDATOR_HEALTH_DEGRADED)
        }

        if (presentation.accessibilityAssistanceRequested) {
            return courtesy(CourtesyReason.ACCESSIBILITY_ASSISTANCE_REQUESTED)
        }

        if (presentation.tokenCommitment.isEmpty() ||
            presentation.issuerSignature.isEmpty() ||
            presentation.validatorNonce.isEmpty()
        ) {
            return courtesy(CourtesyReason.TOKEN_UNREADABLE)
        }

        if (now.isBefore(presentation.issuedAt) || now.isAfter(presentation.expiresAt)) {
            return courtesy(CourtesyReason.TOKEN_EXPIRED)
        }

        if (Duration.between(presentation.issuedAt, presentation.expiresAt) >
            policy.maximumOfflineTokenAge
        ) {
            return configurationReject()
        }

        val digest = tokenDigest.digest(
            presentation.tokenCommitment,
            presentation.validatorNonce
        )

        if (spentTokenStore.hasSpent(digest, now)) {
            return courtesy(CourtesyReason.TOKEN_ALREADY_PRESENTED)
        }

        val signatureValid = signatureVerifier.verify(
            presentation.tokenCommitment,
            presentation.issuerSignature,
            presentation.validatorNonce
        )

        if (!signatureValid) {
            return courtesy(CourtesyReason.TOKEN_UNREADABLE)
        }

        val markerExpiry = minOf(
            presentation.expiresAt,
            now.plus(policy.maximumOfflineTokenAge)
        )

        spentTokenStore.markSpent(digest, markerExpiry)

        return FareValidationResult(
            decision = ValidationDecision.ACCEPT,
            reason = CourtesyReason.NONE,
            retainSpentMarkerUntil = markerExpiry,
            humanSelectionAllowed = false,
            identityCollectionAllowed = false,
            routeHistoryCollectionAllowed = false,
            aggregateEventOnly = true
        )
    }

    private fun courtesy(reason: CourtesyReason): FareValidationResult {
        return FareValidationResult(
            decision = ValidationDecision.COURTESY_ASSISTANCE_REQUIRED,
            reason = reason,
            retainSpentMarkerUntil = null,
            humanSelectionAllowed = false,
            identityCollectionAllowed = false,
            routeHistoryCollectionAllowed = false,
            aggregateEventOnly = true
        )
    }

    private fun configurationReject(): FareValidationResult {
        return FareValidationResult(
            decision = ValidationDecision.REJECT_CONFIGURATION,
            reason = CourtesyReason.VALIDATOR_OFFLINE_LIMIT_REACHED,
            retainSpentMarkerUntil = null,
            humanSelectionAllowed = false,
            identityCollectionAllowed = false,
            routeHistoryCollectionAllowed = false,
            aggregateEventOnly = true
        )
    }
}
