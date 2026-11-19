package org.augmentedhub.evidencepromotion

enum class ResultState {
    PROVISIONAL,
    EVIDENCE_QUALIFIED,
    REPLICATION_SUPPORTED,
    ACCEPTED_FOR_DESIGN,
    NOT_DETECTED,
    INCONCLUSIVE,
    CONTRADICTORY,
    RETIRED_OR_SUPERSEDED
}

enum class ReviewDestination {
    METHOD_QUALITY_REVIEW,
    REPLICATION_REVIEW,
    CONTRADICTION_SYNTHESIS_REVIEW,
    DESIGN_EVIDENCE_REVIEW,
    RETAINED_RECORD_QUEUE,
    NO_EXTERNAL_ACTION
}

data class EvidencePacketSummary(
    val evidencePacketId: String,
    val resultState: ResultState,
    val calibrationStatus: String,
    val provenanceStatus: String,
    val uncertaintyAvailable: Boolean,
    val replicationCount: Int,
    val contradictionStatus: String,
    val externalActionRequested: Boolean
)

object EvidenceReviewQueueRouter {
    fun route(packet: EvidencePacketSummary): ReviewDestination {
        require(packet.evidencePacketId.isNotBlank())
        require(packet.replicationCount >= 0)

        if (packet.externalActionRequested) {
            return ReviewDestination.NO_EXTERNAL_ACTION
        }

        if (packet.calibrationStatus != "VALID"
            || packet.provenanceStatus != "COMPLETE"
            || !packet.uncertaintyAvailable) {
            return ReviewDestination.METHOD_QUALITY_REVIEW
        }

        return when (packet.resultState) {
            ResultState.NOT_DETECTED,
            ResultState.INCONCLUSIVE,
            ResultState.RETIRED_OR_SUPERSEDED ->
                ReviewDestination.RETAINED_RECORD_QUEUE

            ResultState.CONTRADICTORY ->
                ReviewDestination.CONTRADICTION_SYNTHESIS_REVIEW

            ResultState.PROVISIONAL ->
                ReviewDestination.REPLICATION_REVIEW

            ResultState.EVIDENCE_QUALIFIED,
            ResultState.REPLICATION_SUPPORTED,
            ResultState.ACCEPTED_FOR_DESIGN ->
                if (packet.contradictionStatus == "UNRESOLVED") {
                    ReviewDestination.CONTRADICTION_SYNTHESIS_REVIEW
                } else {
                    ReviewDestination.DESIGN_EVIDENCE_REVIEW
                }
        }
    }
}
