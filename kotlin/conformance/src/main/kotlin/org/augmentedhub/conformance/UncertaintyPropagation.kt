package org.augmentedhub.conformance

import kotlin.math.max

enum class PropagationMethod {
    COMPLEMENT_PRODUCT_INDICATOR,
    FIRST_ORDER_COVARIANCE_PROPAGATION,
    INTERVAL_BOUND_PROPAGATION,
    MONTE_CARLO_DISTRIBUTION_PROPAGATION,
    SCENARIO_ENSEMBLE_PROPAGATION,
    QUALITATIVE_UNCERTAINTY_LATTICE,
    COMPONENTWISE_HYBRID_PROPAGATION
}

enum class DependencyDeclaration {
    INDEPENDENT,
    CORRELATED,
    SHARED_SOURCE,
    SHARED_MODEL,
    COMMON_CAUSE_POSSIBLE,
    UNKNOWN
}

data class UncertaintyComponents(
    val measurement: Double = 0.0,
    val calibration: Double = 0.0,
    val spatial: Double = 0.0,
    val temporal: Double = 0.0,
    val model: Double = 0.0,
    val parameter: Double = 0.0,
    val scenario: Double = 0.0,
    val provenance: Double = 0.0,
    val coverage: Double = 0.0,
    val conflict: Double = 0.0,
    val environmentalVariability: Double = 0.0,
    val processVariability: Double = 0.0
) {
    fun allValues(): List<Double> = listOf(
        measurement,
        calibration,
        spatial,
        temporal,
        model,
        parameter,
        scenario,
        provenance,
        coverage,
        conflict,
        environmentalVariability,
        processVariability
    )

    fun epistemicValues(): List<Double> = listOf(
        calibration,
        spatial,
        temporal,
        model,
        parameter,
        scenario,
        provenance,
        coverage,
        conflict
    )

    fun aleatoricValues(): List<Double> = listOf(
        measurement,
        environmentalVariability,
        processVariability
    )
}

data class UncertaintyChainStep(
    val metricName: String,
    val semanticVersion: String,
    val uncertaintyMethod: PropagationMethod,
    val evidenceState: EvidenceState,
    val components: UncertaintyComponents,
    val provenanceReference: String
)

data class UncertaintyChainResult(
    val outputClass: OutputClass,
    val chainUncertainty: Double?,
    val epistemicUncertainty: Double?,
    val aleatoricUncertainty: Double?,
    val method: PropagationMethod,
    val dependencyDeclaration: DependencyDeclaration,
    val reasonCodes: Set<String>,
    val steps: List<UncertaintyChainStep>
)

object UncertaintyPropagation {
    fun calculateComplementProduct(
        steps: List<UncertaintyChainStep>,
        dependency: DependencyDeclaration,
        chainThreshold: Double,
        epistemicThreshold: Double
    ): UncertaintyChainResult {
        require(chainThreshold in 0.0..1.0)
        require(epistemicThreshold in 0.0..1.0)

        if (steps.isEmpty()) {
            return insufficient(
                steps = steps,
                dependency = dependency,
                reasons = setOf("missing_uncertainty_chain_steps")
            )
        }

        if (dependency != DependencyDeclaration.INDEPENDENT) {
            return review(
                steps = steps,
                dependency = dependency,
                reasons = setOf("complement_product_requires_independence_declaration")
            )
        }

        if (steps.any { it.metricName.isBlank() || it.semanticVersion.isBlank() || it.provenanceReference.isBlank() }) {
            return insufficient(
                steps = steps,
                dependency = dependency,
                reasons = setOf("missing_metric_version_or_provenance_reference")
            )
        }

        if (steps.any {
                it.evidenceState == EvidenceState.INSUFFICIENT_EVIDENCE ||
                    it.evidenceState == EvidenceState.UNKNOWN ||
                    it.evidenceState == EvidenceState.UNVERIFIED
            }
        ) {
            return insufficient(
                steps = steps,
                dependency = dependency,
                reasons = setOf("upstream_step_has_insufficient_evidence")
            )
        }

        if (steps.any { it.evidenceState == EvidenceState.CONFLICTED }) {
            return UncertaintyChainResult(
                outputClass = OutputClass.CONFLICTED,
                chainUncertainty = null,
                epistemicUncertainty = null,
                aleatoricUncertainty = null,
                method = PropagationMethod.COMPLEMENT_PRODUCT_INDICATOR,
                dependencyDeclaration = dependency,
                reasonCodes = setOf("upstream_step_is_conflicted", "preserve_both_require_review"),
                steps = steps
            )
        }

        if (steps.any { step -> step.components.allValues().any { it !in 0.0..1.0 } }) {
            return insufficient(
                steps = steps,
                dependency = dependency,
                reasons = setOf("uncertainty_component_out_of_range")
            )
        }

        val stepUncertainties = steps.map { conservativeStepUncertainty(it.components) }
        val chainUncertainty = complementProduct(stepUncertainties)
        val epistemicUncertainty = complementProduct(
            steps.map { complementProduct(it.components.epistemicValues()) }
        )
        val aleatoricUncertainty = complementProduct(
            steps.map { complementProduct(it.components.aleatoricValues()) }
        )

        val reasons = mutableSetOf<String>()
        if (chainUncertainty > chainThreshold) {
            reasons += "chain_uncertainty_exceeds_threshold"
        }
        if (epistemicUncertainty > epistemicThreshold) {
            reasons += "epistemic_uncertainty_exceeds_threshold"
        }
        if (steps.any { it.evidenceState == EvidenceState.STALE }) {
            reasons += "upstream_temporal_uncertainty_requires_review"
        }

        return UncertaintyChainResult(
            outputClass = if (reasons.isEmpty()) OutputClass.ADVISORY_ONLY else OutputClass.NEEDS_REVIEW,
            chainUncertainty = chainUncertainty,
            epistemicUncertainty = epistemicUncertainty,
            aleatoricUncertainty = aleatoricUncertainty,
            method = PropagationMethod.COMPLEMENT_PRODUCT_INDICATOR,
            dependencyDeclaration = dependency,
            reasonCodes = reasons,
            steps = steps
        )
    }

    fun complementProduct(values: List<Double>): Double {
        require(values.isNotEmpty())
        require(values.all { it in 0.0..1.0 })

        return 1.0 - values.fold(1.0) { accumulator, value ->
            accumulator * (1.0 - value)
        }
    }

    fun conservativeStepUncertainty(components: UncertaintyComponents): Double {
        return complementProduct(components.allValues())
    }

    private fun insufficient(
        steps: List<UncertaintyChainStep>,
        dependency: DependencyDeclaration,
        reasons: Set<String>
    ): UncertaintyChainResult {
        return UncertaintyChainResult(
            outputClass = OutputClass.INSUFFICIENT_EVIDENCE,
            chainUncertainty = null,
            epistemicUncertainty = null,
            aleatoricUncertainty = null,
            method = PropagationMethod.COMPLEMENT_PRODUCT_INDICATOR,
            dependencyDeclaration = dependency,
            reasonCodes = reasons,
            steps = steps
        )
    }

    private fun review(
        steps: List<UncertaintyChainStep>,
        dependency: DependencyDeclaration,
        reasons: Set<String>
    ): UncertaintyChainResult {
        return UncertaintyChainResult(
            outputClass = OutputClass.NEEDS_REVIEW,
            chainUncertainty = null,
            epistemicUncertainty = null,
            aleatoricUncertainty = null,
            method = PropagationMethod.COMPLEMENT_PRODUCT_INDICATOR,
            dependencyDeclaration = dependency,
            reasonCodes = reasons,
            steps = steps
        )
    }
}
