package org.augmentedhub.metrics

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

@Serializable
data class MetricRequest(
    val metric: String,
    val input: JsonObject,
    val options: JsonObject = JsonObject(emptyMap()),
)

@Serializable
data class GovernanceEnvelope(
    val scope: String,
    val individualProfiling: Boolean,
    val automatedAdverseAction: Boolean,
    val externalAction: Boolean,
)

@Serializable
data class MetricResponse(
    val metric: String,
    val contractVersion: Int,
    val decisionSupportOnly: Boolean,
    val aggregateEnvironmentalOnly: Boolean,
    val personLevelInferenceProhibited: Boolean,
    val automatedAdverseActionProhibited: Boolean,
    val result: JsonObject,
    val governance: GovernanceEnvelope? = null,
)

@Serializable
data class MetricErrorResponse(
    val errorCode: String,
    val message: String,
    val metric: String? = null,
)

sealed interface MetricDispatchResult {
    data class Success(val response: MetricResponse) : MetricDispatchResult
    data class Failure(
        val errorCode: String,
        val message: String,
        val metric: String? = null,
    ) : MetricDispatchResult
}

data class ProhibitedKeyViolation(
    val path: String,
    val normalizedKey: String,
    val matchedToken: String,
)

sealed interface KeyValidationResult {
    data object Allowed : KeyValidationResult
    data class Rejected(
        val violation: ProhibitedKeyViolation,
    ) : KeyValidationResult
}

data class CachedMetricResponse(
    val metric: String,
    val response: MetricResponse,
    val retrievedAtEpochMillis: Long,
    val expiresAtEpochMillis: Long,
)
