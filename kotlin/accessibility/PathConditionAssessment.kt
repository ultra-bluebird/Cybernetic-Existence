package augmentedhub.accessibility

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

enum class SensorModality {
    FIBER_OPTIC_STRAIN,
    MEMS_VIBRATION,
    ACOUSTIC_EMISSION
}

enum class SensorHealth {
    HEALTHY,
    STALE,
    FAULT
}

enum class PathConditionState {
    STABLE,
    INSPECTION_REQUIRED,
    URGENT_HUMAN_REVIEW,
    SENSOR_HEALTH_REVIEW
}

data class ModalityObservation(
    val modality: SensorModality,
    val features: DoubleArray,
    val baseline: DoubleArray,
    val robustScale: DoubleArray,
    val qualityConfidence: Double,
    val modalityWeight: Double,
    val sensorHealth: SensorHealth
) {
    fun validate(): ModalityObservation {
        require(features.isNotEmpty()) { "features must not be empty." }
        require(features.size == baseline.size) {
            "features and baseline must have equal lengths."
        }
        require(features.size == robustScale.size) {
            "features and robustScale must have equal lengths."
        }
        require(qualityConfidence in 0.0..1.0) {
            "qualityConfidence must be between 0 and 1."
        }
        require(modalityWeight in 0.0..1.0) {
            "modalityWeight must be between 0 and 1."
        }
        require(robustScale.all { it.isFinite() && it > 0.0 }) {
            "robustScale values must be finite and greater than zero."
        }
        require(features.all { it.isFinite() } && baseline.all { it.isFinite() }) {
            "feature and baseline values must be finite."
        }
        return this
    }
}

data class ConditionPolicy(
    val inspectionReviewThreshold: Double,
    val urgentHumanReviewThreshold: Double,
    val minimumPersistentWindows: Int,
    val automaticRouteClosureAllowed: Boolean
) {
    fun validate(): ConditionPolicy {
        require(inspectionReviewThreshold in 0.0..1.0) {
            "inspectionReviewThreshold must be between 0 and 1."
        }
        require(urgentHumanReviewThreshold in 0.0..1.0) {
            "urgentHumanReviewThreshold must be between 0 and 1."
        }
        require(inspectionReviewThreshold < urgentHumanReviewThreshold) {
            "inspectionReviewThreshold must be below urgentHumanReviewThreshold."
        }
        require(minimumPersistentWindows >= 1) {
            "minimumPersistentWindows must be at least one."
        }
        require(!automaticRouteClosureAllowed) {
            "Automatic route closure is prohibited."
        }
        return this
    }
}

data class ConditionAssessment(
    val conditionIndex: Double,
    val state: PathConditionState,
    val fieldInspectionRequired: Boolean,
    val routeClosureAuthorized: Boolean,
    val explanation: String
)

object PathConditionAssessment {
    fun robustAnomaly(observation: ModalityObservation): Double {
        observation.validate()

        if (observation.sensorHealth != SensorHealth.HEALTHY) {
            return 0.0
        }

        var squaredDistance = 0.0

        for (index in observation.features.indices) {
            val normalizedDifference =
                (observation.features[index] - observation.baseline[index]) /
                    observation.robustScale[index]

            squaredDistance += normalizedDifference * normalizedDifference
        }

        val normalizedDistance = sqrt(squaredDistance) / max(1.0, observation.features.size.toDouble())

        return min(
            1.0,
            observation.qualityConfidence *
                observation.modalityWeight *
                normalizedDistance
        )
    }

    fun assess(
        observations: List<ModalityObservation>,
        persistenceScore: Double,
        contextScore: Double,
        persistentWindows: Int,
        policy: ConditionPolicy
    ): ConditionAssessment {
        require(observations.isNotEmpty()) {
            "At least one modality observation is required."
        }
        require(persistenceScore in 0.0..1.0) {
            "persistenceScore must be between 0 and 1."
        }
        require(contextScore in 0.0..1.0) {
            "contextScore must be between 0 and 1."
        }
        require(persistentWindows >= 0) {
            "persistentWindows must not be negative."
        }

        val validatedPolicy = policy.validate()

        if (observations.any { it.sensorHealth != SensorHealth.HEALTHY }) {
            return ConditionAssessment(
                conditionIndex = 0.0,
                state = PathConditionState.SENSOR_HEALTH_REVIEW,
                fieldInspectionRequired = true,
                routeClosureAuthorized = false,
                explanation = "At least one required sensor modality is stale or faulty; qualified inspection is required before interpreting path condition."
            )
        }

        val modalityContribution = observations.sumOf { robustAnomaly(it) }
        val normalizedContribution = min(1.0, modalityContribution)

        val conditionIndex = min(
            1.0,
            0.7 * normalizedContribution +
                0.2 * persistenceScore +
                0.1 * contextScore
        )

        if (persistentWindows < validatedPolicy.minimumPersistentWindows) {
            return ConditionAssessment(
                conditionIndex = conditionIndex,
                state = PathConditionState.STABLE,
                fieldInspectionRequired = false,
                routeClosureAuthorized = false,
                explanation = "Condition change has not persisted across the required evidence windows."
            )
        }

        if (conditionIndex >= validatedPolicy.urgentHumanReviewThreshold) {
            return ConditionAssessment(
                conditionIndex = conditionIndex,
                state = PathConditionState.URGENT_HUMAN_REVIEW,
                fieldInspectionRequired = true,
                routeClosureAuthorized = false,
                explanation = "Persistent multi-sensor anomaly requires urgent qualified field inspection and accessible-detour review."
            )
        }

        if (conditionIndex >= validatedPolicy.inspectionReviewThreshold) {
            return ConditionAssessment(
                conditionIndex = conditionIndex,
                state = PathConditionState.INSPECTION_REQUIRED,
                fieldInspectionRequired = true,
                routeClosureAuthorized = false,
                explanation = "Persistent condition change requires qualified field inspection."
            )
        }

        return ConditionAssessment(
            conditionIndex = conditionIndex,
            state = PathConditionState.STABLE,
            fieldInspectionRequired = false,
            routeClosureAuthorized = false,
            explanation = "No persistent sensor condition exceeds the inspection threshold."
        )
    }

    fun relativeChange(current: Double, previous: Double, scale: Double): Double {
        require(current.isFinite() && previous.isFinite()) {
            "Values must be finite."
        }
        require(scale.isFinite() && scale > 0.0) {
            "scale must be finite and greater than zero."
        }

        return abs(current - previous) / scale
    }
}
