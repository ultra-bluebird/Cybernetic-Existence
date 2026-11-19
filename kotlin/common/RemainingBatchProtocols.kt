package augmentedhub.common

import java.util.Collections

enum class RemainingProtocol {
    CHANGE_AND_ENVELOPE,
    PACING_AND_EMERGENCY,
    INTEROPERABILITY,
    REPAIR_AND_RESOURCE,
    ENVIRONMENT_AND_SOCIAL
}

class PlannedTopicFiles(
    val topic: String,
    val sourcePath: String,
    val testPath: String,
    val packageName: String
) : RedactedContent()

class RemainingProtocolPlan internal constructor(
    val protocol: RemainingProtocol,
    val documentPath: String,
    topics: List<PlannedTopicFiles>
) : RedactedContent() {
    val schemaVersion = "1"
    val topics = Collections.unmodifiableList(topics.toList())
    val constituentImplementationsDelivered: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object RemainingBatchProtocols {
    private fun topic(
        name: String,
        directory: String,
        className: String
    ) = PlannedTopicFiles(
        name,
        "kotlin/$directory/$className.kt",
        "tests/kotlin/$directory/${className}Test.kt",
        "augmentedhub.$directory"
    )

    private val plans = listOf(
        RemainingProtocolPlan(
            RemainingProtocol.CHANGE_AND_ENVELOPE,
            "docs/research/change-envelope-completion-protocol.md",
            listOf(
                topic("material-change-review", "continuity", "MaterialChangeGate"),
                topic("private-continuity-envelope", "continuity",
                    "PrivateContinuityEnvelope")
            )
        ),
        RemainingProtocolPlan(
            RemainingProtocol.PACING_AND_EMERGENCY,
            "docs/research/pacing-emergency-completion-protocol.md",
            listOf(
                topic("assistive-pacing", "continuity", "AssistivePacing"),
                topic("emergency-access", "accessibility", "EmergencyAccess")
            )
        ),
        RemainingProtocolPlan(
            RemainingProtocol.INTEROPERABILITY,
            "docs/research/interoperability-completion-protocol.md",
            listOf(
                topic("runtime-negotiation", "interoperability", "RuntimeNegotiation"),
                topic("spatial-portability", "interoperability", "SpatialPortability"),
                topic("offline-continuity", "interoperability", "OfflineContinuity"),
                topic("tracking-degradation", "interoperability", "TrackingDegradation")
            )
        ),
        RemainingProtocolPlan(
            RemainingProtocol.REPAIR_AND_RESOURCE,
            "docs/research/repair-resource-completion-protocol.md",
            listOf(
                topic("repair-configuration", "interoperability", "RepairConfiguration"),
                topic("task-energy", "interoperability", "TaskEnergy"),
                topic("sampling-governance", "governance", "SamplingGovernor"),
                topic("device-thermal-policy", "governance", "DeviceThermalPolicy")
            )
        ),
        RemainingProtocolPlan(
            RemainingProtocol.ENVIRONMENT_AND_SOCIAL,
            "docs/research/environment-social-completion-protocol.md",
            listOf(
                topic("environmental-presentation", "governance", "EnvironmentalOverlay"),
                topic("social-duty-audit", "governance", "SocialAcceptanceAudit")
            )
        )
    )

    fun declaredPlans(): List<RemainingProtocolPlan> =
        Collections.unmodifiableList(plans.toList())

    /**
     * Validates the declared plan using the existing ledger contract.
     * No source files are opened, generated, or inspected.
     */
    fun reviewPlan(): CommonResult<CoordinationAssessment> {
        val entries = plans.flatMap { plan ->
            val batch = plan.protocol.name.lowercase()
            val sourcesAndTests = plan.topics.flatMap { item ->
                listOf(
                    ArtifactLedgerEntry(
                        item.topic,
                        item.sourcePath,
                        item.sourcePath.substringBeforeLast("/"),
                        item.packageName,
                        batch,
                        ArtifactDeliveryState.PLANNED
                    ),
                    ArtifactLedgerEntry(
                        "${item.topic}-tests",
                        item.testPath,
                        item.testPath.substringBeforeLast("/"),
                        item.packageName,
                        batch,
                        ArtifactDeliveryState.PLANNED
                    )
                )
            }

            sourcesAndTests + ArtifactLedgerEntry(
                "${batch}-protocol",
                plan.documentPath,
                plan.documentPath.substringBeforeLast("/"),
                null,
                batch,
                ArtifactDeliveryState.DELIVERED_AS_RESPONSE_TEXT
            )
        }

        return BatchCoordination.reviewLedger(entries)
    }
}
