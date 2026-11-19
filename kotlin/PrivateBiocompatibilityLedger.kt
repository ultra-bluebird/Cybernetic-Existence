package org.augmentedhub.biocompatibility

import java.time.Instant
import java.util.UUID

enum class EvidencePolarity {
    DETECTED,
    NOT_DETECTED,
    INCONCLUSIVE,
    NOT_APPLICABLE,
    NOT_MEASURED,
    CONTRADICTORY,
    MODELED_ABSENCE
}

enum class EvidenceQuality {
    ACCEPTED,
    PROVISIONAL,
    REJECTED,
    CALIBRATION_REQUIRED
}

data class EvidenceEntry(
    val entryId: String,
    val purpose: String,
    val sourceStatus: String,
    val observableDescription: String,
    val polarity: EvidencePolarity,
    val quality: EvidenceQuality,
    val createdAt: Instant,
    val correctedByEntryId: String? = null
) {
    init {
        require(entryId.matches(Regex("[a-z0-9][a-z0-9_-]{7,127}"))) {
            "entryId must use the local stable identifier grammar"
        }
        require(purpose.isNotBlank() && purpose.length <= 2_000) {
            "purpose must be non-empty and bounded"
        }
        require(sourceStatus.isNotBlank() && sourceStatus.length <= 128) {
            "sourceStatus must be non-empty and bounded"
        }
        require(observableDescription.isNotBlank() && observableDescription.length <= 4_000) {
            "observableDescription must be non-empty and bounded"
        }
    }
}

sealed interface LedgerResult {
    data class Accepted(val entry: EvidenceEntry) : LedgerResult
    data class Rejected(val reason: String) : LedgerResult
}

class PrivateBiocompatibilityLedger {
    private val entries = linkedMapOf<String, EvidenceEntry>()
    private var deleted = false

    fun append(
        purpose: String,
        sourceStatus: String,
        observableDescription: String,
        polarity: EvidencePolarity,
        quality: EvidenceQuality,
        correctedByEntryId: String? = null
    ): LedgerResult {
        if (deleted) {
            return LedgerResult.Rejected("ledger has been deleted locally")
        }

        if (correctedByEntryId != null && !entries.containsKey(correctedByEntryId)) {
            return LedgerResult.Rejected("correction target does not exist")
        }

        val prohibitedTerms = listOf(
            "bostrom",
            "cyberrank",
            "did:",
            "diagnosis:",
            "machine-control",
            "actuate",
            "telemetry-export",
            "cloud-endpoint"
        )

        val combined = "$purpose\n$sourceStatus\n$observableDescription".lowercase()

        if (prohibitedTerms.any { combined.contains(it) }) {
            return LedgerResult.Rejected(
                "entry includes prohibited identity, rank, diagnosis, control, telemetry, or cloud-routing content"
            )
        }

        val entry = EvidenceEntry(
            entryId = "local-evidence-" + UUID.randomUUID().toString().replace("-", ""),
            purpose = purpose,
            sourceStatus = sourceStatus,
            observableDescription = observableDescription,
            polarity = polarity,
            quality = quality,
            createdAt = Instant.now(),
            correctedByEntryId = correctedByEntryId
        )

        entries[entry.entryId] = entry
        return LedgerResult.Accepted(entry)
    }

    fun readLocalEntries(): List<EvidenceEntry> =
        if (deleted) emptyList() else entries.values.toList()

    fun correct(
        priorEntryId: String,
        purpose: String,
        sourceStatus: String,
        observableDescription: String,
        polarity: EvidencePolarity,
        quality: EvidenceQuality
    ): LedgerResult = append(
        purpose = purpose,
        sourceStatus = sourceStatus,
        observableDescription = observableDescription,
        polarity = polarity,
        quality = quality,
        correctedByEntryId = priorEntryId
    )

    fun deleteLocally(): Boolean {
        entries.clear()
        deleted = true
        return true
    }

    fun supportsCloudExport(): Boolean = false

    fun supportsTelemetryExport(): Boolean = false

    fun supportsTrainingExport(): Boolean = false

    fun supportsMachineControl(): Boolean = false

    fun generatesMedicalInference(): Boolean = false

    fun storesGovernanceIdentifier(): Boolean = false
}
