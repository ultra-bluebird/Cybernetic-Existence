package augmentedhub.common

import java.lang.reflect.Modifier

enum class EvidenceBasis {
    DECLARATION_BOOLEAN,
    DECLARATION_RATIO,
    REPORTED_RATIO,
    MEASUREMENT,
    OBSERVATION,
    INDEPENDENT_VERIFICATION
}

/**
 * Apply with @field:EvidenceMarker(...) on stored Kotlin properties.
 * This annotation describes evidence basis; it does not verify evidence.
 */
@Target(AnnotationTarget.FIELD)
@Retention(AnnotationRetention.RUNTIME)
annotation class EvidenceMarker(val basis: EvidenceBasis)

enum class EvidenceNamingIssue {
    TOO_MANY_FIELDS,
    HIERARCHY_LIMIT,
    UNMARKED_BOOLEAN,
    INVALID_DECLARATION_NAME,
    INVALID_RATIO_NAME,
    INVALID_MEASUREMENT_NAME,
    INVALID_OBSERVATION_NAME,
    INVALID_VERIFICATION_NAME,
    TYPE_MISMATCH
}

class EvidenceNamingReport(
    val fieldsReviewed: Int,
    val markedFields: Int,
    issues: List<EvidenceNamingIssue>
) : RedactedContent() {
    val schemaVersion = "1"
    val issues = issues.toList()
    val evidenceAuthenticityVerified: Boolean get() = false
}

/**
 * Metadata review only. Does not read field values.
 *
 * Stored Boolean fields must explicitly declare their evidence basis.
 * Computed getters and interface contracts require source-level review.
 */
object EvidenceNamingReview {
    fun auditType(type: Class<*>): CommonResult<EvidenceNamingReport> {
        var fieldsReviewed = 0
        var markedFields = 0
        val issues = mutableListOf<EvidenceNamingIssue>()
        var current: Class<*>? = type
        var depth = 0

        try {
            while (current != null && current != Any::class.java) {
                if (depth >= Bounds.MAX_NESTING_DEPTH) {
                    issues += EvidenceNamingIssue.HIERARCHY_LIMIT
                    break
                }
                depth++

                for (field in current.declaredFields) {
                    if (Modifier.isStatic(field.modifiers) ||
                        field.isSynthetic
                    ) continue

                    fieldsReviewed++
                    if (fieldsReviewed > Bounds.MAX_COLLECTION_ELEMENTS) {
                        issues += EvidenceNamingIssue.TOO_MANY_FIELDS
                        return report(fieldsReviewed, markedFields, issues)
                    }

                    val marker =
                        field.getAnnotation(EvidenceMarker::class.java)

                    val booleanType =
                        field.type == java.lang.Boolean.TYPE ||
                            field.type == java.lang.Boolean::class.java

                    val ratioType =
                        field.type == java.lang.Double.TYPE ||
                            field.type == java.lang.Double::class.java ||
                            field.type == java.lang.Float.TYPE ||
                            field.type == java.lang.Float::class.java

                    if (marker == null) {
                        if (booleanType) {
                            issues += EvidenceNamingIssue.UNMARKED_BOOLEAN
                        }
                        continue
                    }

                    markedFields++
                    val name = field.name

                    when (marker.basis) {
                        EvidenceBasis.DECLARATION_BOOLEAN -> {
                            if (!booleanType) {
                                issues += EvidenceNamingIssue.TYPE_MISMATCH
                            }
                            if (!name.endsWith("Declared")) {
                                issues +=
                                    EvidenceNamingIssue.INVALID_DECLARATION_NAME
                            }
                        }

                        EvidenceBasis.DECLARATION_RATIO -> {
                            if (!ratioType) {
                                issues += EvidenceNamingIssue.TYPE_MISMATCH
                            }
                            if (!name.startsWith("declared")) {
                                issues += EvidenceNamingIssue.INVALID_RATIO_NAME
                            }
                        }

                        EvidenceBasis.REPORTED_RATIO -> {
                            if (!ratioType) {
                                issues += EvidenceNamingIssue.TYPE_MISMATCH
                            }
                            if (!name.startsWith("reported")) {
                                issues += EvidenceNamingIssue.INVALID_RATIO_NAME
                            }
                        }

                        EvidenceBasis.MEASUREMENT -> {
                            if (!name.startsWith("measured")) {
                                issues +=
                                    EvidenceNamingIssue.INVALID_MEASUREMENT_NAME
                            }
                        }

                        EvidenceBasis.OBSERVATION -> {
                            if (!name.startsWith("observed")) {
                                issues +=
                                    EvidenceNamingIssue.INVALID_OBSERVATION_NAME
                            }
                        }

                        EvidenceBasis.INDEPENDENT_VERIFICATION -> {
                            if (!name.startsWith("verified")) {
                                issues +=
                                    EvidenceNamingIssue.INVALID_VERIFICATION_NAME
                            }
                        }
                    }
                }

                current = current.superclass
            }
        } catch (_: Exception) {
            return CommonResult(
                ResultState.NOT_ESTABLISHED,
                CommonCode.TYPE_REVIEW_FAILED,
                "Evidence field metadata could not be reviewed."
            )
        }

        return report(fieldsReviewed, markedFields, issues)
    }

    private fun report(
        fields: Int,
        marked: Int,
        issues: List<EvidenceNamingIssue>
    ): CommonResult<EvidenceNamingReport> =
        CommonResult(
            if (issues.isEmpty()) ResultState.DECLARED_CHECKS_MET
            else ResultState.NEEDS_REVIEW,
            if (issues.isEmpty()) CommonCode.DECLARED_LOCAL_CHECKS
            else CommonCode.REVIEW_REQUIRED,
            "This result evaluates evidence naming and stored-field metadata, " +
                "not the truth or quality of the underlying evidence.",
            EvidenceNamingReport(fields, marked, issues.toList())
        )
}

/**
 * Bounded declared/reported fraction calculation.
 * The caller must separately identify the numerator/denominator evidence.
 */
object EvidenceRatios {
    fun fromCounts(
        numerator: Long,
        denominator: Long
    ): CommonResult<Double> {
        if (numerator < 0 || denominator < 0 ||
            numerator > denominator
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The supplied evidence counts are inconsistent."
            )
        }

        if (denominator == 0L) {
            return CommonResult(
                ResultState.NOT_APPLICABLE,
                CommonCode.NO_APPLICABLE_SUBJECT,
                "No applicable denominator was supplied."
            )
        }

        return CommonResult(
            ResultState.DECLARED_CHECKS_MET,
            CommonCode.DECLARED_LOCAL_CHECKS,
            "The fraction was calculated from supplied counts. " +
                "The counts were not independently verified.",
            numerator.toDouble() / denominator.toDouble()
        )
    }
}
