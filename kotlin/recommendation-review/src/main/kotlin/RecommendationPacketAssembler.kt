package org.augmentedhub.recommendationreview

import java.time.Instant

enum class RecommendationStatus {
    DRAFT,
    PENDING_REVIEW,
    ACCEPTED_FOR_NON_ACTUATING_DESIGN,
    REQUIRES_REVISION,
    CONTEST_OPEN,
    SUPERSEDED,
    WITHDRAWN_METHOD_INVALID,
    RETIRED
}

data class EvidenceReference(
    val evidencePacketId: String,
    val evidenceRole: String,
    val inclusionStatus: String,
    val rationaleDigest: String
)

data class RecommendationPacket(
    val recommendationId: String,
    val recommendationVersion: Int,
    val scope: String,
    val plainLanguageSummary: String,
    val technicalRationale: String,
    val intendedUse: String,
    val uncertaintySummary: String,
    val limitationSummary: String,
    val alternativeExplanationSummary: String,
    val evidenceReferences: List<EvidenceReference>,
    val modelId: String?,
    val modelVersion: String?,
    val parameterSetId: String?,
    val createdAt: Instant,
    val externalActionAuthorized: Boolean = false
)

object RecommendationPacketAssembler {
    fun assemble(packet: RecommendationPacket): RecommendationPacket {
        require(packet.recommendationId.isNotBlank())
        require(packet.recommendationVersion >= 1)
        require(packet.scope.isNotBlank())
        require(packet.plainLanguageSummary.isNotBlank())
        require(packet.technicalRationale.isNotBlank())
        require(packet.intendedUse.isNotBlank())
        require(packet.uncertaintySummary.isNotBlank())
        require(packet.limitationSummary.isNotBlank())
        require(packet.alternativeExplanationSummary.isNotBlank())
        require(packet.evidenceReferences.isNotEmpty())
        require(!packet.externalActionAuthorized) {
            "Recommendation packets cannot authorize external action"
        }

        packet.evidenceReferences.forEach { reference ->
            require(reference.evidencePacketId.isNotBlank())
            require(reference.evidenceRole.isNotBlank())
            require(reference.inclusionStatus in setOf(
                "INCLUDED",
                "CONSIDERED_NOT_SELECTED",
                "EXCLUDED_WITH_RATIONALE"
            ))
            require(reference.rationaleDigest.isNotBlank())
        }

        return packet
    }
}
