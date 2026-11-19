package org.augmentedhub.scheduling

import kotlin.math.max
import kotlin.math.min

data class ComputeNode(
    val nodeId: String,
    val authorized: Boolean,
    val supportsTaskClass: Set<String>,
    val estimatedEnergyJoules: Double,
    val energyVariance: Double,
    val estimatedLatencyMillis: Double,
    val reliability: Double,
    val privacyEgressRisk: Double,
    val thermalLoad: Double
)

data class ComputeTask(
    val taskId: String,
    val taskClass: String,
    val maximumPrivacyEgressRisk: Double,
    val maximumThermalLoad: Double,
    val speculativeExecutionAllowed: Boolean
)

data class AllocationWeights(
    val energy: Double,
    val latency: Double,
    val variance: Double,
    val reliability: Double,
    val privacy: Double
)

data class AllocationDecision(
    val taskId: String,
    val selectedNodeId: String?,
    val score: Double?,
    val speculativeExecution: Boolean,
    val status: Status,
    val reasons: List<String>
) {
    enum class Status {
        ALLOCATED,
        NO_ELIGIBLE_NODE,
        INVALID_INPUT
    }
}

object HybridTaskAllocationPlanner {
    fun allocate(
        task: ComputeTask,
        nodes: List<ComputeNode>,
        weights: AllocationWeights
    ): AllocationDecision {
        val validationErrors = validate(task, nodes, weights)

        if (validationErrors.isNotEmpty()) {
            return AllocationDecision(
                taskId = task.taskId,
                selectedNodeId = null,
                score = null,
                speculativeExecution = false,
                status = AllocationDecision.Status.INVALID_INPUT,
                reasons = validationErrors
            )
        }

        val eligibleNodes = nodes.filter { node ->
            node.authorized &&
                task.taskClass in node.supportsTaskClass &&
                node.privacyEgressRisk <= task.maximumPrivacyEgressRisk &&
                node.thermalLoad <= task.maximumThermalLoad
        }

        if (eligibleNodes.isEmpty()) {
            return AllocationDecision(
                taskId = task.taskId,
                selectedNodeId = null,
                score = null,
                speculativeExecution = false,
                status = AllocationDecision.Status.NO_ELIGIBLE_NODE,
                reasons = listOf(
                    "No authorized node satisfies the task class, privacy, and thermal constraints."
                )
            )
        }

        val maximumEnergy = eligibleNodes.maxOf { it.estimatedEnergyJoules }
        val maximumLatency = eligibleNodes.maxOf { it.estimatedLatencyMillis }
        val maximumVariance = eligibleNodes.maxOf { it.energyVariance }

        val scored = eligibleNodes.map { node ->
            val energyScore = normalize(node.estimatedEnergyJoules, maximumEnergy)
            val latencyScore = normalize(node.estimatedLatencyMillis, maximumLatency)
            val varianceScore = normalize(node.energyVariance, maximumVariance)
            val reliabilityPenalty = 1.0 - node.reliability

            val score =
                (weights.energy * energyScore) +
                (weights.latency * latencyScore) +
                (weights.variance * varianceScore) +
                (weights.reliability * reliabilityPenalty) +
                (weights.privacy * node.privacyEgressRisk)

            node to score
        }

        val selected = scored.minBy { (_, score) -> score }

        return AllocationDecision(
            taskId = task.taskId,
            selectedNodeId = selected.first.nodeId,
            score = selected.second,
            speculativeExecution =
                task.speculativeExecutionAllowed && eligibleNodes.size > 1,
            status = AllocationDecision.Status.ALLOCATED,
            reasons = listOf(
                "Selected from authorized external compute nodes.",
                "Allocation uses energy, latency, variance, reliability, privacy, and thermal constraints.",
                "The decision is advisory and does not control body-integrated or unverified components."
            )
        )
    }

    private fun normalize(value: Double, maximum: Double): Double =
        if (maximum <= 0.0) 0.0 else min(max(value / maximum, 0.0), 1.0)

    private fun validate(
        task: ComputeTask,
        nodes: List<ComputeNode>,
        weights: AllocationWeights
    ): List<String> {
        val errors = mutableListOf<String>()

        if (task.taskId.isBlank()) {
            errors += "taskId must not be blank."
        }

        if (task.taskClass.isBlank()) {
            errors += "taskClass must not be blank."
        }

        if (
            !task.maximumPrivacyEgressRisk.isFinite() ||
            task.maximumPrivacyEgressRisk !in 0.0..1.0
        ) {
            errors += "maximumPrivacyEgressRisk must be within [0, 1]."
        }

        if (
            !task.maximumThermalLoad.isFinite() ||
            task.maximumThermalLoad !in 0.0..1.0
        ) {
            errors += "maximumThermalLoad must be within [0, 1]."
        }

        val weightValues = listOf(
            weights.energy,
            weights.latency,
            weights.variance,
            weights.reliability,
            weights.privacy
        )

        if (weightValues.any { !it.isFinite() || it < 0.0 }) {
            errors += "All allocation weights must be finite and non-negative."
        }

        if (weightValues.sum() <= 0.0) {
            errors += "At least one allocation weight must be greater than zero."
        }

        nodes.forEach { node ->
            if (node.nodeId.isBlank()) {
                errors += "Every node must have a non-blank nodeId."
            }

            val normalizedValues = listOf(
                node.reliability,
                node.privacyEgressRisk,
                node.thermalLoad
            )

            if (normalizedValues.any { !it.isFinite() || it !in 0.0..1.0 }) {
                errors += "Node ${node.nodeId} has invalid normalized values."
            }

            val nonNegativeValues = listOf(
                node.estimatedEnergyJoules,
                node.energyVariance,
                node.estimatedLatencyMillis
            )

            if (nonNegativeValues.any { !it.isFinite() || it < 0.0 }) {
                errors += "Node ${node.nodeId} has invalid energy, variance, or latency values."
            }
        }

        return errors
    }
}
