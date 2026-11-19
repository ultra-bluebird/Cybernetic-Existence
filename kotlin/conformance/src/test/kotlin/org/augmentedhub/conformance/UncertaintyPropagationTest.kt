package org.augmentedhub.conformance

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class UncertaintyPropagationTest {
    @Test
    fun independentChainPreservesComponentwiseUncertainty() {
        val steps = listOf(
            step(
                metricName = "shade_equity_ratio",
                evidenceState = EvidenceState.MODELED,
                components = UncertaintyComponents(
                    measurement = 0.10,
                    spatial = 0.15,
                    temporal = 0.05,
                    model = 0.10
                )
            ),
            step(
                metricName = "corridor_continuity_score",
                evidenceState = EvidenceState.CALCULATED,
                components = UncertaintyComponents(
                    calibration = 0.05,
                    coverage = 0.10,
                    provenance = 0.05
                )
            )
        )

        val result = UncertaintyPropagation.calculateComplementProduct(
            steps = steps,
            dependency = DependencyDeclaration.INDEPENDENT,
            chainThreshold = 0.90,
            epistemicThreshold = 0.90
        )

        assertEquals(OutputClass.ADVISORY_ONLY, result.outputClass)
        assertTrue(result.chainUncertainty != null)
        assertTrue(result.epistemicUncertainty != null)
        assertTrue(result.aleatoricUncertainty != null)
        assertEquals(2, result.steps.size)
    }

    @Test
    fun correlatedChainRequiresReviewInsteadOfFalseIndependence() {
        val result = UncertaintyPropagation.calculateComplementProduct(
            steps = listOf(
                step(
                    metricName = "shade_equity_ratio",
                    evidenceState = EvidenceState.MODELED,
                    components = UncertaintyComponents(spatial = 0.20)
                ),
                step(
                    metricName = "corridor_continuity_score",
                    evidenceState = EvidenceState.MODELED,
                    components = UncertaintyComponents(spatial = 0.20)
                )
            ),
            dependency = DependencyDeclaration.SHARED_SOURCE,
            chainThreshold = 0.50,
            epistemicThreshold = 0.50
        )

        assertEquals(OutputClass.NEEDS_REVIEW, result.outputClass)
        assertTrue("complement_product_requires_independence_declaration" in result.reasonCodes)
    }

    @Test
    fun conflictedUpstreamEvidencePreservesConflictState() {
        val result = UncertaintyPropagation.calculateComplementProduct(
            steps = listOf(
                step(
                    metricName = "maintenance_condition_decay_model",
                    evidenceState = EvidenceState.CONFLICTED,
                    components = UncertaintyComponents(conflict = 0.80)
                )
            ),
            dependency = DependencyDeclaration.INDEPENDENT,
            chainThreshold = 0.50,
            epistemicThreshold = 0.50
        )

        assertEquals(OutputClass.CONFLICTED, result.outputClass)
        assertTrue("preserve_both_require_review" in result.reasonCodes)
    }

    @Test
    fun missingEvidenceFailsClosed() {
        val result = UncertaintyPropagation.calculateComplementProduct(
            steps = listOf(
                step(
                    metricName = "sensor_alignment_quality_score",
                    evidenceState = EvidenceState.INSUFFICIENT_EVIDENCE,
                    components = UncertaintyComponents(calibration = 0.90)
                )
            ),
            dependency = DependencyDeclaration.INDEPENDENT,
            chainThreshold = 0.50,
            epistemicThreshold = 0.50
        )

        assertEquals(OutputClass.INSUFFICIENT_EVIDENCE, result.outputClass)
        assertTrue("upstream_step_has_insufficient_evidence" in result.reasonCodes)
    }

    @Test
    fun elevatedEpistemicUncertaintyTriggersReview() {
        val result = UncertaintyPropagation.calculateComplementProduct(
            steps = listOf(
                step(
                    metricName = "stormwater_retention_estimate",
                    evidenceState = EvidenceState.MODELED,
                    components = UncertaintyComponents(
                        model = 0.45,
                        parameter = 0.35,
                        provenance = 0.25
                    )
                )
            ),
            dependency = DependencyDeclaration.INDEPENDENT,
            chainThreshold = 0.95,
            epistemicThreshold = 0.50
        )

        assertEquals(OutputClass.NEEDS_REVIEW, result.outputClass)
        assertTrue("epistemic_uncertainty_exceeds_threshold" in result.reasonCodes)
    }

    private fun step(
        metricName: String,
        evidenceState: EvidenceState,
        components: UncertaintyComponents
    ): UncertaintyChainStep {
        return UncertaintyChainStep(
            metricName = metricName,
            semanticVersion = "v1.0.0",
            uncertaintyMethod = PropagationMethod.COMPONENTWISE_HYBRID_PROPAGATION,
            evidenceState = evidenceState,
            components = components,
            provenanceReference = "local-provenance-summary"
        )
    }
}
