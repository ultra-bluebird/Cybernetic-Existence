package org.augmentedhub.metrics

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.augmentedhub.android.metrics.ProhibitedKeyValidator
import java.util.concurrent.ConcurrentHashMap

interface MetricDispatcherApi {
    suspend fun dispatch(request: MetricRequest): MetricResponse
}

class MetricDispatchRepository(
    private val dispatcherApi: MetricDispatcherApi,
    private val clockMillis: () -> Long = System::currentTimeMillis,
    private val cacheTtlMillis: Long = 15 * 60 * 1000L,
    private val maxCachedMetrics: Int = 8,
) {
    private val cacheMutex = Mutex()
    private val cache = ConcurrentHashMap<String, CachedMetricResponse>()

    suspend fun dispatch(request: MetricRequest): MetricDispatchResult {
        val validation = ProhibitedKeyValidator.validate(request.input)

        if (validation is KeyValidationResult.Rejected) {
            return MetricDispatchResult.Failure(
                errorCode = "prohibited_key",
                message = "Request rejected by aggregate-only input policy at ${validation.violation.path}.",
                metric = request.metric,
            )
        }

        if (MetricCatalog.find(request.metric) == null) {
            return MetricDispatchResult.Failure(
                errorCode = "unsupported_metric",
                message = "The requested metric is not in the approved mobile catalog.",
                metric = request.metric,
            )
        }

        return try {
            val response = dispatcherApi.dispatch(request)

            if (!isGovernanceCompatible(response)) {
                return MetricDispatchResult.Failure(
                    errorCode = "governance_contract_violation",
                    message = "Dispatcher response did not preserve the aggregate-only governance contract.",
                    metric = request.metric,
                )
            }

            cacheValidatedAggregateResponse(response)

            MetricDispatchResult.Success(response)
        } catch (error: Exception) {
            MetricDispatchResult.Failure(
                errorCode = "dispatch_failed",
                message = error.message ?: "Metric dispatcher request failed.",
                metric = request.metric,
            )
        }
    }

    suspend fun lastKnown(metric: String): MetricResponse? =
        cacheMutex.withLock {
            val cached = cache[metric] ?: return@withLock null

            if (clockMillis() > cached.expiresAtEpochMillis) {
                cache.remove(metric)
                return@withLock null
            }

            cached.response
        }

    suspend fun clearExpired(): Unit =
        cacheMutex.withLock {
            val now = clockMillis()

            cache.entries.removeIf { (_, cached) ->
                now > cached.expiresAtEpochMillis
            }
        }

    suspend fun clearAll(): Unit =
        cacheMutex.withLock {
            cache.clear()
        }

    private suspend fun cacheValidatedAggregateResponse(
        response: MetricResponse,
    ): Unit =
        cacheMutex.withLock {
            val now = clockMillis()

            if (!response.aggregateEnvironmentalOnly ||
                !response.personLevelInferenceProhibited ||
                !response.decisionSupportOnly ||
                !response.automatedAdverseActionProhibited
            ) {
                return@withLock
            }

            if (cache.size >= maxCachedMetrics && !cache.containsKey(response.metric)) {
                val oldest = cache.entries.minByOrNull {
                    (_, cached) -> cached.retrievedAtEpochMillis
                }

                if (oldest != null) {
                    cache.remove(oldest.key)
                }
            }

            cache[response.metric] = CachedMetricResponse(
                metric = response.metric,
                response = response,
                retrievedAtEpochMillis = now,
                expiresAtEpochMillis = now + cacheTtlMillis,
            )
        }

    private fun isGovernanceCompatible(response: MetricResponse): Boolean =
        response.decisionSupportOnly &&
            response.aggregateEnvironmentalOnly &&
            response.personLevelInferenceProhibited &&
            response.automatedAdverseActionProhibited &&
            response.governance?.individualProfiling != true &&
            response.governance?.automatedAdverseAction != true &&
            response.governance?.externalAction != true
}
