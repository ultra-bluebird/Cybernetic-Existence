package augmentedhub.common

import java.time.LocalDate
import java.util.Collections

enum class VersionEvidenceBasis {
    DECLARED_IN_CONVERSATION,
    LOCAL_SOURCE_REVIEW_REPORTED
}

enum class SchemaKind {
    NOTICE_RESULT,
    STATE_VOCABULARY
}

class SchemaRecord(
    val schemaName: String,
    val kind: SchemaKind,
    val version: String,
    val sourcePath: String,
    val recordedOn: LocalDate,
    val lastSourceChangeDate: LocalDate?,
    val evidenceBasis: VersionEvidenceBasis
) : RedactedContent()

class VersionObservation(
    val schemaName: String,
    val kind: SchemaKind,
    val observedVersion: String,
    val sourceReviewReference: String
) : RedactedContent()

class RegistryReview(
    matchedNames: Set<String>,
    unresolvedNames: Set<String>,
    val sourceContentsIndependentlyVerified: Boolean = false
) : RedactedContent() {
    val matchedSchemaNames: Set<String> =
        Collections.unmodifiableSet(matchedNames.toSet())

    val unresolvedSchemaNames: Set<String> =
        Collections.unmodifiableSet(unresolvedNames.toSet())
}

/**
 * Registry records are review declarations, not code introspection.
 *
 * Existing files are not modified by this registry.
 * Future schema owners should use these constants when integrated.
 */
object NoticeStateRegistry {
    const val COMMON_RESULT_VERSION = "1"
    const val COMMON_STATE_VOCABULARY_VERSION = "1"
    const val REGISTRY_FORMAT_VERSION = "1"

    private val versionPattern =
        Regex("[1-9][0-9]{0,5}")

    private val schemaNamePattern =
        Regex("[a-z][a-z0-9]*(?:-[a-z0-9]+)*")

    private val records = listOf(
        SchemaRecord(
            schemaName = "common-result",
            kind = SchemaKind.NOTICE_RESULT,
            version = COMMON_RESULT_VERSION,
            sourcePath = "kotlin/common/ResultState.kt",
            recordedOn = LocalDate.of(2026, 10, 13),
            lastSourceChangeDate = null,
            evidenceBasis =
                VersionEvidenceBasis.DECLARED_IN_CONVERSATION
        ),
        SchemaRecord(
            schemaName = "common-result-state",
            kind = SchemaKind.STATE_VOCABULARY,
            version = COMMON_STATE_VOCABULARY_VERSION,
            sourcePath = "kotlin/common/ResultState.kt",
            recordedOn = LocalDate.of(2026, 10, 13),
            lastSourceChangeDate = null,
            evidenceBasis =
                VersionEvidenceBasis.DECLARED_IN_CONVERSATION
        )
    )

    fun declaredRecords(): List<SchemaRecord> =
        Collections.unmodifiableList(records.toList())

    /**
     * Checks whether an imported version has a declared registry entry.
     * Does not parse or migrate a payload.
     */
    fun checkSupportedVersion(
        schemaName: String,
        kind: SchemaKind,
        version: String
    ): CommonResult<Unit> {
        if (!schemaNamePattern.matches(schemaName) ||
            !versionPattern.matches(version)
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The schema name or version syntax is invalid."
            )
        }

        val supported = records.any {
            it.schemaName == schemaName &&
                it.kind == kind &&
                it.version == version
        }

        return CommonResult(
            if (supported)
                ResultState.DECLARED_CHECKS_MET
            else ResultState.NOT_ESTABLISHED,
            if (supported)
                CommonCode.DECLARED_LOCAL_CHECKS
            else CommonCode.EVIDENCE_UNAVAILABLE,
            if (supported)
                "The version has a declared registry entry. " +
                    "Payload validation remains separate."
            else
                "This schema version requires an explicit compatibility " +
                    "or migration review."
        )
    }

    /**
     * Compares reported source observations with registered declarations.
     * Missing and conflicting records never become a match.
     */
    fun reviewObservedVersions(
        observations: List<VersionObservation>
    ): CommonResult<RegistryReview> {
        if (observations.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            observations.any {
                !schemaNamePattern.matches(it.schemaName) ||
                    !versionPattern.matches(it.observedVersion) ||
                    it.sourceReviewReference.isBlank() ||
                    Bounds.checkString(it.sourceReviewReference).state !=
                        ResultState.DECLARED_CHECKS_MET
            }
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The version-observation contract is invalid."
            )
        }

        val registeredKeys = records.map {
            it.schemaName to it.kind
        }.toSet()

        if (observations.any {
            (it.schemaName to it.kind) !in registeredKeys
        }) {
            return CommonResult(
                ResultState.NEEDS_REVIEW,
                CommonCode.REVIEW_REQUIRED,
                "A source observation lacks a registry entry."
            )
        }

        val matched = mutableSetOf<String>()
        val unresolved = mutableSetOf<String>()

        for (record in records) {
            val found = observations.filter {
                it.schemaName == record.schemaName &&
                    it.kind == record.kind
            }

            if (found.size == 1 &&
                found.single().observedVersion == record.version
            ) {
                matched += record.schemaName
            } else {
                unresolved += record.schemaName
            }
        }

        return CommonResult(
            if (unresolved.isEmpty())
                ResultState.DECLARED_CHECKS_MET
            else ResultState.NEEDS_REVIEW,
            if (unresolved.isEmpty())
                CommonCode.DECLARED_LOCAL_CHECKS
            else CommonCode.REVIEW_REQUIRED,
            "This comparison uses supplied source-review observations. " +
                "The registry did not inspect repository files.",
            RegistryReview(matched, unresolved)
        )
    }
}
