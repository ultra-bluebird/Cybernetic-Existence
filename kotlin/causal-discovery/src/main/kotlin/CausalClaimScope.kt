package org.augmentedhub.causaldiscovery

enum class CausalClaimScope {
    ASSOCIATION_ONLY,
    CANDIDATE_GRAPH,
    EFFECT_ELIGIBLE_FOR_METHOD_REVIEW,
    INSUFFICIENT_EVIDENCE
}

data class CausalAnalysisSummary(
    val datasetId: String,
    val graphRunId: String,
    val upstreamReferencePresent: Boolean,
    val confounderRegisterPresent: Boolean,
    val censoringMetadataPresent: Boolean,
    val sensitivityAnalysisAcceptable: Boolean,
    val exchangeabilityDeclared: Boolean,
    val externalActionRequested: Boolean
)

object CausalClaimScopeResolver {
    fun resolve(summary: CausalAnalysisSummary): CausalClaimScope {
        require(summary.datasetId.isNotBlank())
        require(summary.graphRunId.isNotBlank())

        if (summary.externalActionRequested) {
            return CausalClaimScope.INSUFFICIENT_EVIDENCE
        }

        if (!summary.upstreamReferencePresent
            || !summary.confounderRegisterPresent
            || !summary.censoringMetadataPresent) {
            return CausalClaimScope.ASSOCIATION_ONLY
        }

        if (!summary.exchangeabilityDeclared
            || !summary.sensitivityAnalysisAcceptable) {
            return CausalClaimScope.CANDIDATE_GRAPH
        }

        return CausalClaimScope.EFFECT_ELIGIBLE_FOR_METHOD_REVIEW
    }
}
