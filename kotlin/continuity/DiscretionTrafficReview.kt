package augmentedhub.continuity

import java.time.Instant

/**
 * Local, bounded research checks.
 *
 * No networking, files, IPC, sensors, credentials, device access,
 * command executor, traffic-controller connection, or automatic export.
 */
class DiscretionTrafficReview {
    enum class State {
        DECLARED_CHECKS_MET,
        NEEDS_REVIEW,
        NOT_ESTABLISHED,
        INVALID_INPUT,
        NOT_APPLICABLE
    }

    enum class PromptPurpose {
        SERVICE_CHOICE,
        PRESENTATION_PREFERENCE,
        ASSISTANCE_REQUEST,
        TASK_PARAMETER,
        PRIVATE_COMPANION_DETAILS,
        PRIVATE_NEURAL_OR_MEDICAL_DETAILS,
        PRIVATE_CREDENTIAL,
        UNKNOWN
    }

    enum class BoundaryComponent {
        PROCESS_PRIVILEGES,
        DEVICE_INTERFACES,
        FILE_WRITES,
        NETWORK_PATHS,
        IPC_AND_BROKERS,
        DEPENDENCIES,
        INDIRECT_COMMAND_DISPATCH
    }

    enum class InspectionState {
        NO_COMMAND_OR_WRITE_PATH_REPORTED,
        PROHIBITED_PATH_REPORTED,
        NOT_ESTABLISHED
    }

    enum class TrafficFinding {
        ACCOUNTING_INCONSISTENCY,
        DISCONTINUOUS_OBSERVATIONS,
        QUEUE_GROWTH_FOR_RESEARCH_REVIEW,
        NO_GROWTH_IN_SUPPLIED_WINDOW
    }

    class Notice(
        val state: State,
        findings: List<String>,
        val plainText: String
    ) {
        val schemaVersion = "1"
        val findings = findings.toList()
        val externalActionAuthorized: Boolean get() = false
        val serviceDenialAuthorized: Boolean get() = false
        val equipmentControlAuthorized: Boolean get() = false

        override fun toString() =
            "Notice(state=$state,findings=$findings)"
    }

    data class PromptDeclaration(
        val purpose: PromptPurpose,
        val required: Boolean,
        val classificationReviewReference: String?
    )

    class PromptReview(
        val notice: Notice,
        val requiredPrivateDisclosureFraction: Double?,
        val privatePromptsRequested: Int,
        val unknownPrompts: Int,
        alternatives: List<String>
    ) {
        val alternativePrompts = alternatives.toList()
        val arbitraryPromptTextAudited: Boolean get() = false
    }

    private fun validReference(value: String?): Boolean =
        value != null && value.isNotBlank() &&
            value.length <= 256 &&
            value.none { Character.isISOControl(it) }

    private fun privatePurpose(purpose: PromptPurpose): Boolean =
        purpose == PromptPurpose.PRIVATE_COMPANION_DETAILS ||
            purpose == PromptPurpose.PRIVATE_NEURAL_OR_MEDICAL_DETAILS ||
            purpose == PromptPurpose.PRIVATE_CREDENTIAL

    fun reviewOrdinaryPrompts(
        prompts: List<PromptDeclaration>,
        humanFallbackReviewReference: String?
    ): PromptReview {
        if (prompts.size > 128) return PromptReview(
            Notice(State.INVALID_INPUT, listOf("prompt_limit"),
                "The prompt contract exceeds the local review boundary."),
            null, 0, 0, emptyList()
        )

        if (prompts.isEmpty()) return PromptReview(
            Notice(State.NOT_APPLICABLE, listOf("no_prompts"),
                "No prompts were supplied. This does not establish " +
                    "availability of the service or assistance pathway."),
            null, 0, 0, emptyList()
        )

        val privateRequested = prompts.count {
            privatePurpose(it.purpose)
        }
        val privateRequired = prompts.count {
            privatePurpose(it.purpose) && it.required
        }
        val unknown = prompts.count {
            it.purpose == PromptPurpose.UNKNOWN ||
                !validReference(it.classificationReviewReference)
        }
        val fallbackKnown =
            validReference(humanFallbackReviewReference)

        val findings = mutableListOf<String>()
        if (privateRequested > 0) {
            findings += "private_prompt_present_in_ordinary_service"
        }
        if (unknown > 0) findings += "prompt_classification_incomplete"
        if (!fallbackKnown) findings += "human_fallback_not_established"

        val state = when {
            privateRequested > 0 -> State.NEEDS_REVIEW
            unknown > 0 || !fallbackKnown -> State.NOT_ESTABLISHED
            else -> State.DECLARED_CHECKS_MET
        }

        return PromptReview(
            Notice(
                state,
                findings,
                "This result checks supplied prompt classifications. " +
                    "Do not demand private-system details to deliver " +
                    "ordinary assistance."
            ),
            privateRequired.toDouble() / prompts.size,
            privateRequested,
            unknown,
            if (privateRequested > 0) listOf(
                "Which service information do you need?",
                "Would you prefer text instructions?",
                "Would you like more time or human assistance?"
            ) else emptyList()
        )
    }

    data class BoundaryInspection(
        val component: BoundaryComponent,
        val state: InspectionState,
        val reviewReference: String,
        val validUntil: Instant
    )

    /**
     * Receipts describe inspection; they do not perform it.
     * A material change blocks reliance on prior passing declarations.
     */
    fun reviewNonInterference(
        inspections: List<BoundaryInspection>,
        materialChangePending: Boolean,
        now: Instant
    ): Notice {
        if (inspections.size > BoundaryComponent.entries.size ||
            inspections.map { it.component }.toSet().size !=
                inspections.size ||
            inspections.any { !validReference(it.reviewReference) }
        ) return Notice(
            State.INVALID_INPUT,
            listOf("invalid_inspection_contract"),
            "The non-interference inspection contract needs correction."
        )

        val prohibited = inspections.any {
            it.state == InspectionState.PROHIBITED_PATH_REPORTED
        }

        val incomplete = BoundaryComponent.entries.any { component ->
            val record = inspections.singleOrNull {
                it.component == component
            }
            record == null ||
                record.state == InspectionState.NOT_ESTABLISHED ||
                now >= record.validUntil
        }

        val findings = mutableListOf<String>()
        if (prohibited) findings += "command_or_write_path_reported"
        if (incomplete) findings += "inspection_evidence_incomplete"
        if (materialChangePending) findings += "material_change_review_pending"

        return Notice(
            when {
                prohibited || materialChangePending -> State.NEEDS_REVIEW
                incomplete -> State.NOT_ESTABLISHED
                else -> State.DECLARED_CHECKS_MET
            },
            findings,
            "This result evaluates declared inspection evidence only. " +
                "It does not inspect privileges, prove absence of side effects, " +
                "or authorize commands."
        )
    }

    /**
     * Aggregate counts only. No vehicle trajectories, plates,
     * pedestrian identities, or augmentation classifications.
     *
     * intervalPosition is a bounded sequence position, not a timestamp.
     */
    data class TrafficWindow(
        val intervalPosition: Int,
        val queueAtStart: Long,
        val arrivals: Long,
        val departures: Long,
        val queueAtEnd: Long
    )

    class TrafficReview(
        val notice: Notice,
        findings: Set<TrafficFinding>,
        val netQueueChange: Long?
    ) {
        val trafficFindings = findings.toSet()
        val signalTimingRecommendationProduced: Boolean get() = false
        val operationalModelValidated: Boolean get() = false
        val actuationAuthorized: Boolean get() = false
    }

    /**
     * Pure arithmetic on caller-supplied approved snapshots.
     * No live adapter or equipment connection is created.
     */
    fun evaluateTrafficSnapshots(
        windows: List<TrafficWindow>,
        consistentCountingScopeDeclared: Boolean,
        aggregateReleaseReviewReference: String?
    ): TrafficReview {
        if (windows.isEmpty()) return TrafficReview(
            Notice(State.NOT_APPLICABLE, listOf("no_windows"),
                "No traffic windows were supplied."),
            emptySet(), null
        )

        if (windows.size > 256 ||
            windows.any {
                it.intervalPosition !in 0..255 ||
                    listOf(
                        it.queueAtStart, it.arrivals,
                        it.departures, it.queueAtEnd
                    ).any { count -> count !in 0L..1_000_000L }
            } ||
            windows.map { it.intervalPosition }.toSet().size !=
                windows.size
        ) return TrafficReview(
            Notice(State.INVALID_INPUT, listOf("invalid_aggregate_windows"),
                "The supplied traffic windows are invalid or excessive."),
            emptySet(), null
        )

        if (!consistentCountingScopeDeclared ||
            !validReference(aggregateReleaseReviewReference)
        ) return TrafficReview(
            Notice(State.NOT_ESTABLISHED, listOf("counting_scope_not_established"),
                "The aggregate counting and release context is not established."),
            emptySet(), null
        )

        val ordered = windows.sortedBy { it.intervalPosition }
        val findings = mutableSetOf<TrafficFinding>()

        for (window in ordered) {
            val expected =
                window.queueAtStart + window.arrivals - window.departures
            if (expected < 0 || expected != window.queueAtEnd) {
                findings += TrafficFinding.ACCOUNTING_INCONSISTENCY
            }
        }

        for (index in 1 until ordered.size) {
            val prior = ordered[index - 1]
            val current = ordered[index]
            if (current.intervalPosition != prior.intervalPosition + 1 ||
                current.queueAtStart != prior.queueAtEnd
            ) {
                findings += TrafficFinding.DISCONTINUOUS_OBSERVATIONS
            }
        }

        if (findings.isNotEmpty()) return TrafficReview(
            Notice(State.NEEDS_REVIEW, listOf("aggregate_consistency_issue"),
                "Review counting scope and observation continuity. " +
                    "No operational recommendation is established."),
            findings, null
        )

        val change =
            ordered.last().queueAtEnd - ordered.first().queueAtStart

        findings += if (change > 0)
            TrafficFinding.QUEUE_GROWTH_FOR_RESEARCH_REVIEW
        else TrafficFinding.NO_GROWTH_IN_SUPPLIED_WINDOW

        return TrafficReview(
            Notice(
                if (change > 0) State.NEEDS_REVIEW
                else State.DECLARED_CHECKS_MET,
                listOf("bounded_aggregate_analysis"),
                "The supplied accounting is consistent. " +
                    "Any queue trend is a research observation, not a " +
                    "validated signal-timing or safety recommendation."
            ),
            findings,
            change
        )
    }
}
