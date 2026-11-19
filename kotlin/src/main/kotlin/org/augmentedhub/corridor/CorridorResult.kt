package org.augmentedhub.corridor

data class CorridorMetrics(
    val voltageV: Double,
    val currentA: Double,
    val surfaceTemperatureC: Double,
    val waterStressStage: Int,
    val fogUnmodeledFraction: Double,
    val dissolvedOxygenMgL: Double,
    val harmRisk: Double
)

data class PendingDecision(
    val decisionKey: String,
    val description: String,
    val requestedAtUtc: String
)

sealed class CorridorResult {
    data class Permitted(
        val explanationCode: String,
        val metrics: CorridorMetrics
    ) : CorridorResult()

    data class Denied(
        val explanationCode: String,
        val reason: DenialReason
    ) : CorridorResult()

    data class NeedsHumanReview(
        val explanationCode: String,
        val pendingDecisions: List<PendingDecision>
    ) : CorridorResult()
}

sealed class DenialReason {
    abstract val explanationCode: String

    data class ElectricalViolation(
        val measured: Double,
        val bound: Double,
        val formula: String
    ) : DenialReason() {
        override val explanationCode = "ELECTRICAL_BOUND_VIOLATION"
    }

    data class ThermalViolation(
        val measured: Double,
        val bound: Double
    ) : DenialReason() {
        override val explanationCode = "THERMAL_BOUND_VIOLATION"
    }

    data class WaterStressViolation(
        val stage: Int,
        val requiredStage: Int
    ) : DenialReason() {
        override val explanationCode = "WATER_STRESS_STAGE_EXCEEDED"
    }

    data class ConsentRevoked(
        val revocationTimestamp: String
    ) : DenialReason() {
        override val explanationCode = "CONSENT_REVOKED"
    }

    data class IdentityDiscriminationDetected(
        val identityClass: String,
        val protectedStatus: Boolean
    ) : DenialReason() {
        override val explanationCode = "IDENTITY_DISCRIMINATION_DETECTED"
    }

    data class FogMediaViolation(
        val metric: String,
        val measured: Double,
        val threshold: Double
    ) : DenialReason() {
        override val explanationCode = "FOG_MEDIA_THRESHOLD_EXCEEDED"
    }

    data class CanalConditionViolation(
        val metric: String,
        val measured: Double,
        val threshold: Double
    ) : DenialReason() {
        override val explanationCode = "CANAL_CONDITION_THRESHOLD_FAILED"
    }

    data class KerThresholdFailed(
        val metric: String,
        val measured: Double,
        val threshold: Double
    ) : DenialReason() {
        override val explanationCode = "KER_THRESHOLD_FAILED"
    }
}

fun CorridorResult.toMachineReadableExplanationCode(): String =
    when (this) {
        is CorridorResult.Permitted -> explanationCode
        is CorridorResult.Denied -> reason.explanationCode
        is CorridorResult.NeedsHumanReview -> explanationCode
    }

fun DenialReason.toAuditAttributes(): Map<String, String> =
    when (this) {
        is DenialReason.ElectricalViolation -> mapOf(
            "measured" to measured.toString(),
            "bound" to bound.toString(),
            "formula" to formula
        )

        is DenialReason.ThermalViolation -> mapOf(
            "measured" to measured.toString(),
            "bound" to bound.toString()
        )

        is DenialReason.WaterStressViolation -> mapOf(
            "stage" to stage.toString(),
            "requiredStage" to requiredStage.toString()
        )

        is DenialReason.ConsentRevoked -> mapOf(
            "revocationTimestamp" to revocationTimestamp
        )

        is DenialReason.IdentityDiscriminationDetected -> mapOf(
            "identityClass" to identityClass,
            "protectedStatus" to protectedStatus.toString()
        )

        is DenialReason.FogMediaViolation -> mapOf(
            "metric" to metric,
            "measured" to measured.toString(),
            "threshold" to threshold.toString()
        )

        is DenialReason.CanalConditionViolation -> mapOf(
            "metric" to metric,
            "measured" to measured.toString(),
            "threshold" to threshold.toString()
        )

        is DenialReason.KerThresholdFailed -> mapOf(
            "metric" to metric,
            "measured" to measured.toString(),
            "threshold" to threshold.toString()
        )
    }
