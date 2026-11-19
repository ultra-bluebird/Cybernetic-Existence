package org.augmentedhub.canal

enum class AdvisoryStatus {
    ADVISORY,
    DERATE,
    HALT,
    INDETERMINATE
}

data class GraphManifest(
    val modelVersion: String,
    val nodeSchemaVersion: String,
    val edgeSchemaVersion: String,
    val edgeMaskVersion: String,
    val validForMinutes: Long
)

data class InferenceEvidence(
    val inputInDomain: Boolean,
    val nodeQualityPassed: Boolean,
    val edgeMaskPassed: Boolean,
    val outputBoundsPassed: Boolean,
    val uncertaintyCoveragePassed: Boolean,
    val falseSafeCount: Long
)

object CanalGatOrchestrator {
    fun evaluate(
        manifest: GraphManifest,
        evidence: InferenceEvidence
    ): AdvisoryStatus {
        require(manifest.modelVersion.isNotBlank())
        require(manifest.nodeSchemaVersion.isNotBlank())
        require(manifest.edgeSchemaVersion.isNotBlank())
        require(manifest.edgeMaskVersion.isNotBlank())
        require(manifest.validForMinutes > 0L)
        require(evidence.falseSafeCount >= 0L)

        if (!evidence.nodeQualityPassed || !evidence.edgeMaskPassed) {
            return AdvisoryStatus.INDETERMINATE
        }

        if (!evidence.inputInDomain
            || !evidence.outputBoundsPassed
            || !evidence.uncertaintyCoveragePassed
            || evidence.falseSafeCount > 0L
        ) {
            return AdvisoryStatus.INDETERMINATE
        }

        return AdvisoryStatus.ADVISORY
    }
}
