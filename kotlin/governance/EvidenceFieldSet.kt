package augmentedhub.governance

import augmentedhub.common.*
import java.time.Instant
import java.util.Collections

enum class EnvironmentalQuantity {
    AIR_TEMPERATURE, SURFACE_TEMPERATURE, PM25_CONCENTRATION
}

enum class EnvironmentalUnit {
    DEGREES_CELSIUS, KELVIN, MICROGRAMS_PER_CUBIC_METER
}

enum class EnvironmentalKind {
    MEASUREMENT, MODEL, SCENARIO
}

enum class ProvenanceField {
    QUANTITY, UNIT, KIND, PERIOD, PRODUCTION_TIME,
    SOURCE_REFERENCE, UNCERTAINTY, METHOD_REVIEW
}

class EnvironmentalProvenance(
    val quantity: EnvironmentalQuantity?,
    val unit: EnvironmentalUnit?,
    val kind: EnvironmentalKind?,
    val periodStart: Instant?,
    val periodEnd: Instant?,
    val producedAt: Instant?,
    val sourceReference: String?,
    val uncertaintyStatement: String?,
    val methodReviewReference: String?,
    val extendedNotes: String?
) : RedactedContent()

class ProvenanceAssessment(
    missing: Set<ProvenanceField>,
    val temporalInterpretation: String
) : RedactedContent() {
    val schemaVersion = "1"
    val missingFields = Collections.unmodifiableSet(missing.toSet())
    val sourceTruthVerified: Boolean get() = false
    val measurementAccuracyVerified: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object EvidenceFieldSet {
    private fun present(value: String?) =
        value != null && value.isNotBlank()

    private fun bounded(value: String?) =
        value == null ||
            Bounds.checkString(value).state == ResultState.DECLARED_CHECKS_MET

    fun review(
        record: EnvironmentalProvenance,
        now: Instant
    ): CommonResult<ProvenanceAssessment> {
        val text = listOf(
            record.sourceReference, record.uncertaintyStatement,
            record.methodReviewReference, record.extendedNotes
        )

        if (text.any { !bounded(it) }) return CommonResult(
            ResultState.INVALID_INPUT,
            CommonCode.INPUT_CONTRACT_VIOLATION,
            "A provenance text field violates the common bounds."
        )

        val missing = mutableSetOf<ProvenanceField>()
        if (record.quantity == null) missing += ProvenanceField.QUANTITY
        if (record.unit == null) missing += ProvenanceField.UNIT
        if (record.kind == null) missing += ProvenanceField.KIND
        if (record.periodStart == null || record.periodEnd == null)
            missing += ProvenanceField.PERIOD
        if (record.producedAt == null) missing += ProvenanceField.PRODUCTION_TIME
        if (!present(record.sourceReference))
            missing += ProvenanceField.SOURCE_REFERENCE
        if (!present(record.uncertaintyStatement))
            missing += ProvenanceField.UNCERTAINTY
        if (!present(record.methodReviewReference))
            missing += ProvenanceField.METHOD_REVIEW

        if (missing.isNotEmpty()) return CommonResult(
            ResultState.NOT_ESTABLISHED,
            CommonCode.EVIDENCE_UNAVAILABLE,
            "Required environmental provenance is incomplete.",
            ProvenanceAssessment(missing, "not_established")
        )

        val quantity = requireNotNull(record.quantity)
        val unit = requireNotNull(record.unit)
        val kind = requireNotNull(record.kind)
        val start = requireNotNull(record.periodStart)
        val end = requireNotNull(record.periodEnd)
        val produced = requireNotNull(record.producedAt)

        val compatibleUnit = when (quantity) {
            EnvironmentalQuantity.AIR_TEMPERATURE,
            EnvironmentalQuantity.SURFACE_TEMPERATURE ->
                unit == EnvironmentalUnit.DEGREES_CELSIUS ||
                    unit == EnvironmentalUnit.KELVIN
            EnvironmentalQuantity.PM25_CONCENTRATION ->
                unit == EnvironmentalUnit.MICROGRAMS_PER_CUBIC_METER
        }

        if (!compatibleUnit || end < start || produced > now) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "Unit compatibility or temporal structure is invalid."
            )
        }

        if (kind == EnvironmentalKind.MEASUREMENT &&
            (end > now || produced < end)
        ) return CommonResult(
            ResultState.NEEDS_REVIEW,
            CommonCode.REVIEW_REQUIRED,
            "A measurement period conflicts with its production/current context."
        )

        val interpretation = when (kind) {
            EnvironmentalKind.MEASUREMENT ->
                "measurement_of_declared_period"
            EnvironmentalKind.MODEL ->
                if (end > now) "model_for_future_period"
                else "model_for_declared_period"
            EnvironmentalKind.SCENARIO ->
                "scenario_not_observed_fact"
        }

        return CommonResult(
            ResultState.DECLARED_CHECKS_MET,
            CommonCode.DECLARED_LOCAL_CHECKS,
            "Required fields are present. Preserve kind and units in presentation; " +
                "do not relabel models or scenarios as measurements.",
            ProvenanceAssessment(emptySet(), interpretation)
        )
    }
}
