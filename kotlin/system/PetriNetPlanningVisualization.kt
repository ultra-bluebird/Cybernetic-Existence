package system

import java.util.Locale

data class PlaceMetadata(
    val placeId: String,
    val placeType: String,
    val subsystem: String,
    val publicSafeLabel: String,
    val sensitiveDataAllowed: Boolean,
    val publicSafeLocationPrecision: String,
    val reviewStatus: String
)

data class TransitionMetadata(
    val transitionId: String,
    val transitionType: String,
    val subsystem: String,
    val requiresHumanApproval: Boolean,
    val physicalActuationAuthority: Boolean,
    val publicSafeLabel: String,
    val reviewStatus: String
)

data class ReachabilityResult(
    val boundedReachabilityStatus: String,
    val targetStateReachable: Boolean,
    val deadlockCandidateCount: Int,
    val invariantValidationStatus: String,
    val unsafeMarkingDetected: Boolean,
    val interfaceContractStatus: String,
    val stateSpaceBoundStatus: String,
    val planningOnlyStatus: Boolean,
    val humanReviewRequired: Boolean,
    val limitationNotice: String
)

data class InvariantStatus(
    val invariantId: String,
    val invariantType: String,
    val verificationStatus: String,
    val publicSafeDescription: String
)

data class AccessibilityRenderingPreferences(
    val plainLanguage: Boolean,
    val includeTextFirstTable: Boolean,
    val includeSubsystemSummaries: Boolean,
    val includeLimitations: Boolean,
    val maximumLineLength: Int
)

data class VisualizationResult(
    val accessibleGraphDescription: String,
    val textFirstTransitionTable: String,
    val subsystemLevelStateSummary: String,
    val invariantStatusSummary: String,
    val boundedReachabilityExplanation: String,
    val uncertaintyAndLimitationNotice: String,
    val visualizationStatus: String,
    val humanReviewStatus: String
)

object PetriNetPlanningVisualization {
    private val allowedSubsystems = setOf(
        "canal",
        "heat_relief",
        "compute",
        "governance",
        "monitoring",
        "interface"
    )

    private val allowedLocationPrecision = setOf(
        "public_generalized",
        "restricted_exact"
    )

    fun render(
        netVersion: String,
        approvedPlaceMetadata: List<PlaceMetadata>,
        approvedTransitionMetadata: List<TransitionMetadata>,
        reachabilityResult: ReachabilityResult,
        invariantStatus: List<InvariantStatus>,
        generalizedSubsystemDiagramData: Map<String, String>,
        preferences: AccessibilityRenderingPreferences,
        publicSafeLocationPrecision: String
    ): VisualizationResult {
        validateInputs(
            netVersion,
            approvedPlaceMetadata,
            approvedTransitionMetadata,
            reachabilityResult,
            invariantStatus,
            generalizedSubsystemDiagramData,
            preferences,
            publicSafeLocationPrecision
        )

        val graphDescription = graphDescription(
            netVersion,
            approvedPlaceMetadata,
            approvedTransitionMetadata,
            generalizedSubsystemDiagramData,
            preferences.maximumLineLength
        )

        val transitionTable = transitionTable(
            approvedTransitionMetadata,
            preferences.maximumLineLength
        )

        val subsystemSummary = subsystemSummary(
            approvedPlaceMetadata,
            approvedTransitionMetadata,
            preferences.maximumLineLength
        )

        val invariantSummary = invariantSummary(
            invariantStatus,
            preferences.maximumLineLength
        )

        val reachabilityExplanation = reachabilityExplanation(
            reachabilityResult,
            preferences.maximumLineLength
        )

        val limitations = limitationNotice(
            reachabilityResult,
            publicSafeLocationPrecision,
            preferences.maximumLineLength
        )

        val visualizationStatus =
            if (
                reachabilityResult.planningOnlyStatus &&
                    reachabilityResult.humanReviewRequired &&
                    !reachabilityResult.unsafeMarkingDetected
            ) {
                "planning_visualization_qualified"
            } else {
                "hold_for_human_review"
            }

        return VisualizationResult(
            accessibleGraphDescription = graphDescription,
            textFirstTransitionTable = transitionTable,
            subsystemLevelStateSummary = subsystemSummary,
            invariantStatusSummary = invariantSummary,
            boundedReachabilityExplanation = reachabilityExplanation,
            uncertaintyAndLimitationNotice = limitations,
            visualizationStatus = visualizationStatus,
            humanReviewStatus = "required"
        )
    }

    private fun validateInputs(
        netVersion: String,
        places: List<PlaceMetadata>,
        transitions: List<TransitionMetadata>,
        result: ReachabilityResult,
        invariants: List<InvariantStatus>,
        generalizedDiagramData: Map<String, String>,
        preferences: AccessibilityRenderingPreferences,
        publicSafeLocationPrecision: String
    ) {
        require(netVersion.isNotBlank()) { "netVersion must not be blank" }
        require(places.isNotEmpty()) { "approvedPlaceMetadata must not be empty" }
        require(transitions.isNotEmpty()) { "approvedTransitionMetadata must not be empty" }
        require(preferences.maximumLineLength in 40..240) {
            "maximumLineLength must be within 40..240"
        }
        require(publicSafeLocationPrecision in allowedLocationPrecision) {
            "publicSafeLocationPrecision is not allowed"
        }
        require(result.deadlockCandidateCount >= 0) {
            "deadlockCandidateCount must be non-negative"
        }

        places.forEach { place ->
            require(place.placeId.isNotBlank()) { "placeId must not be blank" }
            require(place.placeType.isNotBlank()) { "placeType must not be blank" }
            require(place.subsystem in allowedSubsystems) {
                "place subsystem is not allowed"
            }
            require(place.publicSafeLabel.isNotBlank()) {
                "place publicSafeLabel must not be blank"
            }
            require(!place.sensitiveDataAllowed) {
                "sensitive data places must not be visualized"
            }
            require(place.publicSafeLocationPrecision in allowedLocationPrecision) {
                "place location precision is not allowed"
            }
            require(place.reviewStatus in setOf("approved", "qualified")) {
                "place reviewStatus must be approved or qualified"
            }
        }

        transitions.forEach { transition ->
            require(transition.transitionId.isNotBlank()) {
                "transitionId must not be blank"
            }
            require(transition.transitionType.isNotBlank()) {
                "transitionType must not be blank"
            }
            require(transition.subsystem in allowedSubsystems) {
                "transition subsystem is not allowed"
            }
            require(!transition.physicalActuationAuthority) {
                "physical-actuation transitions must not be visualized"
            }
            require(transition.publicSafeLabel.isNotBlank()) {
                "transition publicSafeLabel must not be blank"
            }
            require(transition.reviewStatus in setOf("approved", "qualified")) {
                "transition reviewStatus must be approved or qualified"
            }
        }

        invariants.forEach { invariant ->
            require(invariant.invariantId.isNotBlank()) {
                "invariantId must not be blank"
            }
            require(invariant.invariantType.isNotBlank()) {
                "invariantType must not be blank"
            }
            require(invariant.verificationStatus in setOf(
                "valid",
                "qualified",
                "invalid",
                "pending"
            )) {
                "invariant verificationStatus is invalid"
            }
            require(invariant.publicSafeDescription.isNotBlank()) {
                "invariant publicSafeDescription must not be blank"
            }
        }

        generalizedDiagramData.forEach { (subsystem, description) ->
            require(subsystem in allowedSubsystems) {
                "diagram subsystem is not allowed"
            }
            require(description.isNotBlank()) {
                "diagram description must not be blank"
            }
            require(!containsRestrictedDetail(description)) {
                "diagram data contains restricted operational detail"
            }
        }
    }

    private fun graphDescription(
        netVersion: String,
        places: List<PlaceMetadata>,
        transitions: List<TransitionMetadata>,
        diagramData: Map<String, String>,
        lineLength: Int
    ): String {
        val placeCounts = places.groupingBy { it.subsystem }.eachCount()
        val transitionCounts = transitions.groupingBy { it.subsystem }.eachCount()

        val content = buildString {
            append("Petri-net planning model ")
            append(netVersion)
            append(" contains only reviewed, generalized planning states and transitions. ")

            allowedSubsystems.forEach { subsystem ->
                val placeCount = placeCounts[subsystem] ?: 0
                val transitionCount = transitionCounts[subsystem] ?: 0

                if (placeCount > 0 || transitionCount > 0) {
                    append(
                        "Subsystem $subsystem has $placeCount place states and " +
                            "$transitionCount reviewed planning transitions. "
                    )

                    diagramData[subsystem]?.let { description ->
                        append("Generalized role: $description. ")
                    }
                }
            }

            append(
                "No exact sensitive ecological locations, critical infrastructure routes, " +
                    "identities, health records, personal telemetry, or physical control " +
                    "commands are represented."
            )
        }

        return wrapText(content, lineLength)
    }

    private fun transitionTable(
        transitions: List<TransitionMetadata>,
        lineLength: Int
    ): String {
        val header =
            "Transition ID | Subsystem | Human approval | Public-safe purpose | Review status"

        val rows = transitions
            .sortedWith(compareBy<TransitionMetadata> { it.subsystem }.thenBy { it.transitionId })
            .joinToString("\n") { transition ->
                val approval = if (transition.requiresHumanApproval) "required" else "not required"
                "${transition.transitionId} | ${transition.subsystem} | $approval | " +
                    "${sanitizeLabel(transition.publicSafeLabel)} | ${transition.reviewStatus}"
            }

        return wrapTable(header, rows, lineLength)
    }

    private fun subsystemSummary(
        places: List<PlaceMetadata>,
        transitions: List<TransitionMetadata>,
        lineLength: Int
    ): String {
        val content = buildString {
            allowedSubsystems.forEach { subsystem ->
                val subsystemPlaces = places.filter { it.subsystem == subsystem }
                val subsystemTransitions = transitions.filter { it.subsystem == subsystem }

                if (subsystemPlaces.isNotEmpty() || subsystemTransitions.isNotEmpty()) {
                    append("$subsystem: ")
                    append("${subsystemPlaces.size} reviewed place states; ")
                    append("${subsystemTransitions.size} reviewed transitions. ")

                    val labels = subsystemPlaces
                        .map { sanitizeLabel(it.publicSafeLabel) }
                        .distinct()
                        .take(5)

                    if (labels.isNotEmpty()) {
                        append("State examples: ${labels.joinToString(", ")}. ")
                    }
                }
            }

            append(
                "All subsystem summaries are modelled planning descriptions and are not " +
                    "operational instructions."
            )
        }

        return wrapText(content, lineLength)
    }

    private fun invariantSummary(
        invariants: List<InvariantStatus>,
        lineLength: Int
    ): String {
        if (invariants.isEmpty()) {
            return wrapText(
                "No invariant records were supplied. The visualization must be treated as " +
                    "incomplete and held for human review.",
                lineLength
            )
        }

        val content = invariants
            .sortedBy { it.invariantId }
            .joinToString("\n") { invariant ->
                "${invariant.invariantId}: ${invariant.verificationStatus}; " +
                    sanitizeLabel(invariant.publicSafeDescription)
            }

        return wrapText(
            "Invariant status summary:\n$content",
            lineLength
        )
    }

    private fun reachabilityExplanation(
        result: ReachabilityResult,
        lineLength: Int
    ): String {
        val content = buildString {
            append("Bounded reachability status: ")
            append(result.boundedReachabilityStatus)
            append(". Target state reachable within analyzed bounds: ")
            append(result.targetStateReachable)
            append(". Deadlock candidate count: ")
            append(result.deadlockCandidateCount)
            append(". Invariant validation status: ")
            append(result.invariantValidationStatus)
            append(". Unsafe marking detected: ")
            append(result.unsafeMarkingDetected)
            append(". Interface contract status: ")
            append(result.interfaceContractStatus)
            append(". State-space bound status: ")
            append(result.stateSpaceBoundStatus)
            append(".")
        }

        return wrapText(content, lineLength)
    }

    private fun limitationNotice(
        result: ReachabilityResult,
        publicSafeLocationPrecision: String,
        lineLength: Int
    ): String {
        val content = buildString {
            append(
                "This visualization is modelled planning evidence only. A bounded " +
                    "reachability result does not prove real-world safety, ecological " +
                    "benefit, legal authority, service availability, or operating permission. "
            )
            append(
                "Public location precision is $publicSafeLocationPrecision. "
            )
            append(
                "The visualization does not expose exact ecological sites, critical " +
                    "infrastructure routes, personal data, or operational-control details. "
            )
            append(
                "Human review remains required. "
            )
            append(result.limitationNotice)
        }

        return wrapText(content, lineLength)
    }

    private fun containsRestrictedDetail(value: String): Boolean {
        val normalized = value.lowercase(Locale.ROOT)

        val prohibitedTerms = listOf(
            "latitude",
            "longitude",
            "gps",
            "private key",
            "health record",
            "biometric",
            "neural data",
            "gate command",
            "pump command",
            "actuator command",
            "control endpoint"
        )

        return prohibitedTerms.any { term -> normalized.contains(term) }
    }

    private fun sanitizeLabel(value: String): String {
        return value
            .replace('\n', ' ')
            .replace('|', '/')
            .trim()
    }

    private fun wrapTable(header: String, rows: String, lineLength: Int): String {
        val lines = buildList {
            add(header)
            add("-".repeat(minOf(header.length, lineLength)))
            rows.lines().forEach { add(it) }
        }

        return lines.joinToString("\n") { line ->
            if (line.length <= lineLength) {
                line
            } else {
                wrapText(line, lineLength)
            }
        }
    }

    private fun wrapText(text: String, lineLength: Int): String {
        val output = StringBuilder()

        text.lines().forEachIndexed { lineIndex, sourceLine ->
            if (lineIndex > 0) {
                output.append('\n')
            }

            var currentLength = 0

            sourceLine
                .trim()
                .split(Regex("\\s+"))
                .filter { it.isNotEmpty() }
                .forEach { word ->
                    val separator = if (currentLength == 0) "" else " "

                    if (currentLength > 0 && currentLength + separator.length + word.length > lineLength) {
                        output.append('\n')
                        output.append(word)
                        currentLength = word.length
                    } else {
                        output.append(separator)
                        output.append(word)
                        currentLength += separator.length + word.length
                    }
                }
        }

        return output.toString()
    }
}
