package augmentedhub.accessibility

import java.time.Instant
import java.util.PriorityQueue
import kotlin.math.max

enum class RoutePreference {
    STEP_FREE,
    QUIETER,
    SHADED,
    FEWER_TURNS,
    SIMPLER_CROSSINGS,
    REST_OPPORTUNITIES,
    LOWER_EXPOSURE
}

enum class ConditionState {
    CLEAR,
    RESTRICTED,
    BLOCKED,
    INSPECTION_REQUIRED,
    UNKNOWN
}

enum class RouteConfidence {
    HIGH,
    MODERATE,
    LIMITED
}

data class RouteCondition(
    val state: ConditionState,
    val conditionClass: String,
    val sourceClass: String,
    val observedAt: Instant,
    val expiresAt: Instant,
    val alternateAccessibleRouteConfirmed: Boolean
) {
    fun isCurrent(now: Instant): Boolean = now <= expiresAt

    fun preventsUse(preferences: Set<RoutePreference>, now: Instant): Boolean {
        if (!isCurrent(now)) {
            return RoutePreference.STEP_FREE in preferences
        }

        if (state == ConditionState.BLOCKED) {
            return true
        }

        if (state == ConditionState.UNKNOWN && RoutePreference.STEP_FREE in preferences) {
            return true
        }

        return false
    }
}

data class PathEdge(
    val from: String,
    val to: String,
    val distanceMeters: Double,
    val estimatedSeconds: Int,
    val hasSteps: Boolean,
    val verifiedAccessibleWidth: Boolean,
    val shadeFraction: Double,
    val noiseCost: Double,
    val crossingComplexity: Double,
    val restOpportunity: Boolean,
    val ecologicalBenefit: Double,
    val condition: RouteCondition
) {
    fun validate(): PathEdge {
        require(from.isNotBlank() && to.isNotBlank()) {
            "Path-edge node values must not be blank."
        }
        require(distanceMeters.isFinite() && distanceMeters > 0.0) {
            "distanceMeters must be finite and positive."
        }
        require(estimatedSeconds > 0) {
            "estimatedSeconds must be positive."
        }
        require(shadeFraction in 0.0..1.0) {
            "shadeFraction must be between 0 and 1."
        }
        require(noiseCost in 0.0..1.0) {
            "noiseCost must be between 0 and 1."
        }
        require(crossingComplexity in 0.0..1.0) {
            "crossingComplexity must be between 0 and 1."
        }
        require(ecologicalBenefit in 0.0..1.0) {
            "ecologicalBenefit must be between 0 and 1."
        }
        return this
    }

    fun isFeasible(preferences: Set<RoutePreference>, now: Instant): Boolean {
        validate()

        if (RoutePreference.STEP_FREE in preferences && hasSteps) {
            return false
        }

        if (RoutePreference.STEP_FREE in preferences && !verifiedAccessibleWidth) {
            return false
        }

        return !condition.preventsUse(preferences, now)
    }
}

data class RouteWeights(
    val distanceWeight: Double,
    val barrierWeight: Double,
    val comfortWeight: Double,
    val ecologicalWeight: Double,
    val complexityWeight: Double
) {
    fun validate(): RouteWeights {
        require(distanceWeight >= 0.0 && barrierWeight >= 0.0) {
            "Distance and barrier weights must not be negative."
        }
        require(comfortWeight >= 0.0 && ecologicalWeight >= 0.0 && complexityWeight >= 0.0) {
            "Comfort, ecological, and complexity weights must not be negative."
        }
        require(
            distanceWeight + barrierWeight + comfortWeight + ecologicalWeight + complexityWeight > 0.0
        ) {
            "At least one routing weight must be positive."
        }
        return this
    }
}

data class RouteStep(
    val from: String,
    val to: String,
    val distanceMeters: Double,
    val estimatedSeconds: Int,
    val summary: String
)

data class AccessibleRoute(
    val nodes: List<String>,
    val steps: List<RouteStep>,
    val totalDistanceMeters: Double,
    val totalEstimatedSeconds: Int,
    val totalCost: Double,
    val confidence: RouteConfidence,
    val dataFreshnessSummary: String,
    val identityOrHistoryStored: Boolean,
    val externalExportAllowed: Boolean
)

private data class QueueEntry(
    val node: String,
    val cost: Double,
    val distanceMeters: Double,
    val estimatedSeconds: Int,
    val path: List<PathEdge>
)

class AccessibleRoutePlanner(
    private val graph: Map<String, List<PathEdge>>
) {
    fun findRoute(
        origin: String,
        destination: String,
        preferences: Set<RoutePreference>,
        weights: RouteWeights,
        now: Instant
    ): AccessibleRoute? {
        require(origin.isNotBlank()) { "origin must not be blank." }
        require(destination.isNotBlank()) { "destination must not be blank." }

        val validatedWeights = weights.validate()

        if (!graph.containsKey(origin)) {
            return null
        }

        val queue = PriorityQueue<QueueEntry>(compareBy { it.cost })
        val bestCost = mutableMapOf<String, Double>()

        queue.add(
            QueueEntry(
                node = origin,
                cost = 0.0,
                distanceMeters = 0.0,
                estimatedSeconds = 0,
                path = emptyList()
            )
        )

        bestCost[origin] = 0.0

        while (queue.isNotEmpty()) {
            val current = queue.remove()

            if (current.node == destination) {
                return buildRoute(current.path, current.cost, current.distanceMeters, current.estimatedSeconds, now)
            }

            if (current.cost > (bestCost[current.node] ?: Double.POSITIVE_INFINITY)) {
                continue
            }

            for (edge in graph[current.node].orEmpty()) {
                if (!edge.isFeasible(preferences, now)) {
                    continue
                }

                val candidateCost = current.cost + edgeCost(edge, preferences, validatedWeights)
                val previousCost = bestCost[edge.to] ?: Double.POSITIVE_INFINITY

                if (candidateCost < previousCost) {
                    bestCost[edge.to] = candidateCost
                    queue.add(
                        QueueEntry(
                            node = edge.to,
                            cost = candidateCost,
                            distanceMeters = current.distanceMeters + edge.distanceMeters,
                            estimatedSeconds = current.estimatedSeconds + edge.estimatedSeconds,
                            path = current.path + edge
                        )
                    )
                }
            }
        }

        return null
    }

    private fun edgeCost(
        edge: PathEdge,
        preferences: Set<RoutePreference>,
        weights: RouteWeights
    ): Double {
        val distanceCost = edge.distanceMeters / 100.0

        val barrierCost = when {
            edge.hasSteps -> 1.0
            !edge.verifiedAccessibleWidth -> 0.8
            else -> 0.0
        }

        val shadePenalty = if (RoutePreference.SHADED in preferences) 1.0 - edge.shadeFraction else 0.0
        val quietPenalty = if (RoutePreference.QUIETER in preferences) edge.noiseCost else 0.0
        val restPenalty = if (
            RoutePreference.REST_OPPORTUNITIES in preferences &&
            !edge.restOpportunity
        ) 0.5 else 0.0

        val comfortCost = shadePenalty + quietPenalty + restPenalty

        val complexityCost = if (
            RoutePreference.FEWER_TURNS in preferences ||
            RoutePreference.SIMPLER_CROSSINGS in preferences
        ) {
            edge.crossingComplexity
        } else {
            0.0
        }

        val ecologicalCredit = if (RoutePreference.LOWER_EXPOSURE in preferences) {
            edge.ecologicalBenefit
        } else {
            0.0
        }

        return max(
            0.0,
            weights.distanceWeight * distanceCost +
                weights.barrierWeight * barrierCost +
                weights.comfortWeight * comfortCost +
                weights.complexityWeight * complexityCost -
                weights.ecologicalWeight * ecologicalCredit
        )
    }

    private fun buildRoute(
        path: List<PathEdge>,
        cost: Double,
        distanceMeters: Double,
        estimatedSeconds: Int,
        now: Instant
    ): AccessibleRoute {
        val steps = path.map { edge ->
            RouteStep(
                from = edge.from,
                to = edge.to,
                distanceMeters = edge.distanceMeters,
                estimatedSeconds = edge.estimatedSeconds,
                summary = "${edge.distanceMeters.toInt()} meters toward ${edge.to}."
            )
        }

        val nodes = if (path.isEmpty()) {
            emptyList()
        } else {
            listOf(path.first().from) + path.map { it.to }
        }

        val staleEdgeCount = path.count { !it.condition.isCurrent(now) }
        val restrictedEdgeCount = path.count { it.condition.state == ConditionState.RESTRICTED }

        val confidence = when {
            staleEdgeCount > 0 -> RouteConfidence.LIMITED
            restrictedEdgeCount > 0 -> RouteConfidence.MODERATE
            else -> RouteConfidence.HIGH
        }

        val freshnessSummary = when {
            staleEdgeCount > 0 -> "Some route-condition data is stale. Confirm conditions before travel."
            restrictedEdgeCount > 0 -> "The route includes a verified restricted segment. Review route details before travel."
            else -> "Route-condition data is current for the selected path."
        }

        return AccessibleRoute(
            nodes = nodes,
            steps = steps,
            totalDistanceMeters = distanceMeters,
            totalEstimatedSeconds = estimatedSeconds,
            totalCost = cost,
            confidence = confidence,
            dataFreshnessSummary = freshnessSummary,
            identityOrHistoryStored = false,
            externalExportAllowed = false
        )
    }
}
