package org.augmentedhub.provenance

import java.time.Instant
import java.util.UUID

enum class ArtifactClass {
    ENVIRONMENTAL_OBSERVATION,
    CALIBRATION_SET,
    FORMAL_SPECIFICATION,
    SOFTWARE_TEST,
    HOST_REPORTED_NOTE,
    EXTERNAL_EVIDENCE_REFERENCE
}

enum class ReviewStatus {
    DRAFT,
    HOST_REVIEWED,
    TECHNICAL_REVIEWED,
    EXTERNALLY_REFERENCED,
    REJECTED_FOR_INSUFFICIENT_PROVENANCE
}

data class ProvenanceRecord(
    val recordId: UUID,
    val sequence: Long,
    val createdAt: Instant,
    val artifactClass: ArtifactClass,
    val revision: String,
    val contentDigest: String,
    val sourceReference: String,
    val classification: String,
    val reviewStatus: ReviewStatus,
    val purpose: String,
    val predecessorDigest: String?,
    val continuityDigest: String
)

sealed class ProvenanceError(message: String) : IllegalArgumentException(message) {
    data object EmptyRevision : ProvenanceError("revision must not be blank")
    data object InvalidDigest : ProvenanceError("contentDigest must be lowercase SHA-384 hex")
    data object EmptySourceReference : ProvenanceError("sourceReference must not be blank")
    data object EmptyClassification : ProvenanceError("classification must not be blank")
    data object EmptyPurpose : ProvenanceError("purpose must not be blank")
    data object DuplicateDigest : ProvenanceError("contentDigest already exists in this registry")
    data object TimestampRegression : ProvenanceError("record timestamp must not precede the prior record")
}

class ResearchProvenanceRegistry(
    private val digest: (String) -> String
) {
    private val records = mutableListOf<ProvenanceRecord>()

    fun append(
        createdAt: Instant,
        artifactClass: ArtifactClass,
        revision: String,
        contentDigest: String,
        sourceReference: String,
        classification: String,
        reviewStatus: ReviewStatus,
        purpose: String
    ): ProvenanceRecord {
        validate(
            createdAt = createdAt,
            revision = revision,
            contentDigest = contentDigest,
            sourceReference = sourceReference,
            classification = classification,
            purpose = purpose
        )

        val predecessor = records.lastOrNull()

        if (predecessor != null && createdAt.isBefore(predecessor.createdAt)) {
            throw ProvenanceError.TimestampRegression
        }

        if (records.any { it.contentDigest == contentDigest }) {
            throw ProvenanceError.DuplicateDigest
        }

        val sequence = predecessor?.sequence?.plus(1L) ?: 0L
        val predecessorDigest = predecessor?.continuityDigest

        val canonical = listOf(
            "AUGMENTED_HUB_PROVENANCE_V1",
            sequence.toString(),
            createdAt.toString(),
            artifactClass.name,
            revision,
            contentDigest,
            sourceReference,
            classification,
            reviewStatus.name,
            purpose,
            predecessorDigest.orEmpty()
        ).joinToString("|")

        val record = ProvenanceRecord(
            recordId = UUID.randomUUID(),
            sequence = sequence,
            createdAt = createdAt,
            artifactClass = artifactClass,
            revision = revision,
            contentDigest = contentDigest,
            sourceReference = sourceReference,
            classification = classification,
            reviewStatus = reviewStatus,
            purpose = purpose,
            predecessorDigest = predecessorDigest,
            continuityDigest = digest(canonical)
        )

        records += record
        return record
    }

    fun verify(): List<String> {
        val failures = mutableListOf<String>()

        records.forEachIndexed { index, record ->
            val predecessor = records.getOrNull(index - 1)

            if (record.sequence != index.toLong()) {
                failures += "sequence mismatch at index $index"
            }

            if (record.predecessorDigest != predecessor?.continuityDigest) {
                failures += "predecessor digest mismatch at sequence ${record.sequence}"
            }

            if (predecessor != null && record.createdAt.isBefore(predecessor.createdAt)) {
                failures += "timestamp regression at sequence ${record.sequence}"
            }

            val canonical = listOf(
                "AUGMENTED_HUB_PROVENANCE_V1",
                record.sequence.toString(),
                record.createdAt.toString(),
                record.artifactClass.name,
                record.revision,
                record.contentDigest,
                record.sourceReference,
                record.classification,
                record.reviewStatus.name,
                record.purpose,
                record.predecessorDigest.orEmpty()
            ).joinToString("|")

            if (digest(canonical) != record.continuityDigest) {
                failures += "continuity digest mismatch at sequence ${record.sequence}"
            }
        }

        return failures
    }

    fun snapshot(): List<ProvenanceRecord> = records.toList()

    private fun validate(
        createdAt: Instant,
        revision: String,
        contentDigest: String,
        sourceReference: String,
        classification: String,
        purpose: String
    ) {
        require(!createdAt.isBefore(Instant.EPOCH)) {
            "createdAt must not be before the Unix epoch"
        }

        if (revision.isBlank()) {
            throw ProvenanceError.EmptyRevision
        }

        if (!contentDigest.matches(Regex("^[a-f0-9]{96}$"))) {
            throw ProvenanceError.InvalidDigest
        }

        if (sourceReference.isBlank()) {
            throw ProvenanceError.EmptySourceReference
        }

        if (classification.isBlank()) {
            throw ProvenanceError.EmptyClassification
        }

        if (purpose.isBlank()) {
            throw ProvenanceError.EmptyPurpose
        }
    }
}
