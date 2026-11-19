package augmentedhub.common

import java.util.Collections

enum class ArtifactDeliveryState {
    DELIVERED_AS_RESPONSE_TEXT,
    PLANNED
}

enum class VerificationState {
    NOT_EXECUTED,
    REPORTED_PASS,
    REPORTED_FAIL
}

enum class StandingStandard {
    DIRECT_RESPONSE_ARTIFACTS,
    NO_FILE_GENERATION_TOOLS,
    SHARED_RESULT_STATE,
    BOUNDED_INPUTS,
    REDACTED_DIAGNOSTICS,
    EVIDENCE_BASIS_SEPARATION,
    EXPLICIT_MUTABLE_STATE_SYNCHRONIZATION,
    GUARDED_PROCESS_LOCAL_TIMING,
    NO_AUTOMATIC_EXTERNAL_ACTION,
    ACCESSIBLE_RECOVERY,
    SYNTHETIC_TEST_LABELING
}

class ArtifactLedgerEntry(
    val topic: String,
    val filename: String,
    val destination: String,
    val packageName: String?,
    val batchName: String,
    val deliveryState: ArtifactDeliveryState
) : RedactedContent()

class SessionDeclaration(
    val formatVersion: String,
    val scope: String,
    deliveredWork: List<String>,
    nextBatch: List<String>,
    standards: Set<StandingStandard>,
    repositories: Set<String>,
    destinations: Set<String>,
    pendingHardening: List<String>,
    val compilation: VerificationState,
    val integration: VerificationState
) : RedactedContent() {
    val deliveredWork = Collections.unmodifiableList(deliveredWork.toList())
    val nextBatch = Collections.unmodifiableList(nextBatch.toList())
    val standards = Collections.unmodifiableSet(standards.toSet())
    val repositories = Collections.unmodifiableSet(repositories.toSet())
    val destinations = Collections.unmodifiableSet(destinations.toSet())
    val pendingHardening =
        Collections.unmodifiableList(pendingHardening.toList())
}

class VocabularyUse(
    val qualifiedSymbol: String,
    val meaningContractReference: String,
    val sourcePath: String
) : RedactedContent()

class CoordinationAssessment(
    findings: List<String>
) : RedactedContent() {
    val findings = Collections.unmodifiableList(findings.toList())
    val repositoryContentsInspected: Boolean get() = false
    val semanticEquivalenceVerified: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object BatchCoordination {
    const val SESSION_FORMAT_VERSION = "1"

    private val expectedRepositories = setOf(
        "mk-bluebird/Augmented-Hub",
        "mk-bluebird/Skynet"
    )

    private val packagePattern =
        Regex("[a-z][a-z0-9_]*(?:\\.[a-z][a-z0-9_]*)*")

    private val symbolPattern =
        Regex("[A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)+")

    private val sharedSymbols = setOf(
        "ResultState",
        "CommonResult",
        "MonotonicClock",
        "GuardedMonotonicClock",
        "TimeMark",
        "RedactedContent",
        "Bounds"
    )

    private fun validText(value: String): Boolean =
        value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    /**
     * This scoped ledger accepts Kotlin scaffolding and Markdown documents.
     * It is not a universal repository path validator.
     */
    private fun validPath(path: String): Boolean {
        if (path.length > 512 || path.startsWith("/") ||
            '\\' in path || ':' in path
        ) return false

        val parts = path.split("/")
        if (parts.size < 2 || parts.any {
            it.isEmpty() || it == "." || it == ".." ||
                !Regex("[A-Za-z0-9_.-]+").matches(it)
        }) return false

        return path.startsWith("kotlin/") ||
            path.startsWith("tests/kotlin/") ||
            path.startsWith("docs/")
    }

    private fun result(
        findings: List<String>
    ): CommonResult<CoordinationAssessment> =
        CommonResult(
            if (findings.isEmpty()) ResultState.DECLARED_CHECKS_MET
            else ResultState.NEEDS_REVIEW,
            if (findings.isEmpty()) CommonCode.DECLARED_LOCAL_CHECKS
            else CommonCode.REVIEW_REQUIRED,
            "This result evaluates supplied coordination metadata only.",
            CoordinationAssessment(findings.distinct())
        )

    fun reviewSession(
        declaration: SessionDeclaration
    ): CommonResult<CoordinationAssessment> {
        val findings = mutableListOf<String>()

        val strings = declaration.deliveredWork +
            declaration.nextBatch + declaration.pendingHardening +
            declaration.destinations + listOf(declaration.scope)

        if (strings.any { !validText(it) } ||
            declaration.deliveredWork.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            declaration.nextBatch.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            declaration.pendingHardening.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            declaration.destinations.size > Bounds.MAX_COLLECTION_ELEMENTS
        ) findings += "session_metadata_out_of_bounds"

        if (declaration.formatVersion != SESSION_FORMAT_VERSION)
            findings += "session_format_unsupported"

        if (declaration.repositories != expectedRepositories)
            findings += "repository_scope_mismatch"

        if (declaration.standards != StandingStandard.entries.toSet())
            findings += "standing_standard_missing_or_changed"

        if (declaration.deliveredWork.toSet().size !=
            declaration.deliveredWork.size
        ) findings += "duplicate_delivered_work_label"

        if (declaration.nextBatch.toSet().size != declaration.nextBatch.size)
            findings += "duplicate_next_batch_label"

        if (declaration.destinations.any {
            !validPath("$it/scope.md")
        }) findings += "destination_scope_invalid"

        return result(findings)
    }

    fun reviewLedger(
        entries: List<ArtifactLedgerEntry>
    ): CommonResult<CoordinationAssessment> {
        if (entries.size > Bounds.MAX_COLLECTION_ELEMENTS)
            return result(listOf("ledger_entry_limit"))

        val findings = mutableListOf<String>()
        if (entries.map { it.filename }.toSet().size != entries.size)
            findings += "duplicate_ledger_filename"

        for (entry in entries) {
            if (!validText(entry.topic) || !validText(entry.batchName))
                findings += "ledger_label_invalid"

            if (!validPath(entry.filename)) {
                findings += "ledger_path_invalid"
                continue
            }

            if (entry.destination != entry.filename.substringBeforeLast("/"))
                findings += "filename_destination_mismatch"

            when {
                entry.filename.endsWith(".kt") -> {
                    if (entry.packageName == null ||
                        !packagePattern.matches(entry.packageName)
                    ) {
                        findings += "kotlin_package_missing_or_invalid"
                    } else {
                        val relative = when {
                            entry.filename.startsWith("tests/kotlin/") ->
                                entry.filename.removePrefix("tests/kotlin/")
                            entry.filename.startsWith("kotlin/") ->
                                entry.filename.removePrefix("kotlin/")
                            else -> null
                        }

                        if (relative == null) {
                            findings += "kotlin_source_root_invalid"
                        } else {
                            val directory = relative.substringBeforeLast("/")
                            val expectedPackage =
                                "augmentedhub." + directory.replace("/", ".")
                            if (entry.packageName != expectedPackage)
                                findings += "package_destination_mismatch"
                        }
                    }
                }

                entry.filename.endsWith(".md") -> {
                    if (!entry.filename.startsWith("docs/") ||
                        entry.packageName != null
                    ) findings += "markdown_ledger_contract_invalid"
                }

                else -> findings += "unsupported_scaffolding_format"
            }
        }

        return result(findings)
    }

    /**
     * Reference comparison is not meaning verification.
     * Shared foundation short names must use augmentedhub.common.
     */
    fun reviewVocabulary(
        uses: List<VocabularyUse>
    ): CommonResult<CoordinationAssessment> {
        if (uses.size > Bounds.MAX_COLLECTION_ELEMENTS)
            return result(listOf("vocabulary_entry_limit"))

        val findings = mutableListOf<String>()

        for (use in uses) {
            if (!symbolPattern.matches(use.qualifiedSymbol) ||
                !validText(use.meaningContractReference) ||
                !validPath(use.sourcePath)
            ) findings += "vocabulary_metadata_invalid"

            val shortName = use.qualifiedSymbol.substringAfterLast(".")
            if (shortName in sharedSymbols &&
                use.qualifiedSymbol != "augmentedhub.common.$shortName"
            ) findings += "shared_vocabulary_shadowed"
        }

        for ((_, declarations) in uses.groupBy { it.qualifiedSymbol }) {
            if (declarations.map {
                it.meaningContractReference
            }.toSet().size > 1) {
                findings += "meaning_contract_collision"
            }
        }

        return result(findings)
    }
}
