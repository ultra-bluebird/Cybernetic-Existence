package augmentedhub.privacy

import augmentedhub.common.Bounds
import augmentedhub.common.CommonCode
import augmentedhub.common.CommonResult
import augmentedhub.common.ContentBearing
import augmentedhub.common.RedactedContent
import augmentedhub.common.ResultState
import java.time.Instant
import java.util.Collections

enum class LocalBoundaryComponent {
    PROCESSES_AND_PRIVILEGES,
    STORAGE_AND_BACKUPS,
    NETWORK_EGRESS,
    IPC_AND_BROKERS,
    DERIVED_DATA,
    CRASH_REPORTERS,
    ACCESSIBILITY_CACHES,
    RENDERING_AND_GPU,
    SCREENSHOT_AND_RECORDING,
    OS_DIAGNOSTICS,
    SDK_AND_NATIVE_DEPENDENCIES,
    LOGS_AND_ANALYTICS,
    CLIPBOARD_AND_SHARE,
    BACKGROUND_WORKERS,
    SENSOR_AND_RUNTIME_PROVIDERS
}

enum class ComponentPresence {
    PRESENT_DECLARED,
    ABSENT_DECLARED,
    NOT_ESTABLISHED
}

enum class InspectionFinding {
    WITHIN_DECLARED_BOUNDARY_REPORTED,
    PROHIBITED_PATH_REPORTED,
    NOT_ESTABLISHED
}

@ContentBearing
class BoundaryInventoryEntry(
    val component: LocalBoundaryComponent,
    val presence: ComponentPresence,
    val deploymentContext: String,
    val inventoryVersion: String,
    val discoveryReviewReference: String
) : RedactedContent()

@ContentBearing
class BoundaryInspectionRecord(
    val component: LocalBoundaryComponent,
    val inspectedPresence: ComponentPresence,
    val deploymentContext: String,
    val inventoryVersion: String,
    val finding: InspectionFinding,
    val inspectionReference: String,
    val validFrom: Instant,
    val validUntil: Instant
) : RedactedContent()

class LocalBoundaryAssessment(
    current: Set<LocalBoundaryComponent>,
    unresolved: Set<LocalBoundaryComponent>,
    adverse: Set<LocalBoundaryComponent>,
    conflicts: Set<LocalBoundaryComponent>
) : RedactedContent() {
    val schemaVersion = "1"
    val currentInspectedComponents =
        Collections.unmodifiableSet(current.toSet())
    val unresolvedComponents =
        Collections.unmodifiableSet(unresolved.toSet())
    val reportedAdverseComponents =
        Collections.unmodifiableSet(adverse.toSet())
    val conflictingComponents =
        Collections.unmodifiableSet(conflicts.toSet())

    val actualBoundaryDiscoveryVerified: Boolean get() = false
    val operatingSystemEnforcementVerified: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object LocalBoundaryInventory {
    private val versionPattern = Regex("[1-9][0-9]{0,5}")

    private fun validText(value: String): Boolean =
        value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    /**
     * Mandatory inventory floor.
     *
     * Additional deployment paths require a reviewed extension.
     * This function does not inspect applications or platform services.
     */
    fun review(
        entries: List<BoundaryInventoryEntry>,
        inspections: List<BoundaryInspectionRecord>,
        expectedDeploymentContext: String,
        expectedInventoryVersion: String,
        additionalPathDiscovery: InspectionFinding,
        additionalPathDiscoveryReference: String,
        now: Instant
    ): CommonResult<LocalBoundaryAssessment> {
        if (entries.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            inspections.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            !validText(expectedDeploymentContext) ||
            !versionPattern.matches(expectedInventoryVersion) ||
            !validText(additionalPathDiscoveryReference) ||
            entries.any {
                !validText(it.deploymentContext) ||
                    !versionPattern.matches(it.inventoryVersion) ||
                    !validText(it.discoveryReviewReference)
            } ||
            inspections.any {
                !validText(it.deploymentContext) ||
                    !versionPattern.matches(it.inventoryVersion) ||
                    !validText(it.inspectionReference) ||
                    it.validUntil <= it.validFrom
            }
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The local-boundary inventory contract is invalid."
            )
        }

        val current = mutableSetOf<LocalBoundaryComponent>()
        val unresolved = mutableSetOf<LocalBoundaryComponent>()
        val adverse = mutableSetOf<LocalBoundaryComponent>()
        val conflicts = mutableSetOf<LocalBoundaryComponent>()

        for (component in LocalBoundaryComponent.entries) {
            val declarations = entries.filter {
                it.component == component
            }

            // Preserve reported adverse evidence even when context or
            // records conflict. It requires resolution, not silent omission.
            if (inspections.any {
                it.component == component &&
                    it.finding == InspectionFinding.PROHIBITED_PATH_REPORTED
            }) {
                adverse += component
            }

            if (declarations.size != 1) {
                if (declarations.size > 1) conflicts += component
                unresolved += component
                continue
            }

            val entry = declarations.single()

            if (entry.deploymentContext != expectedDeploymentContext ||
                entry.inventoryVersion != expectedInventoryVersion ||
                entry.presence == ComponentPresence.NOT_ESTABLISHED
            ) {
                unresolved += component
                continue
            }

            val matching = inspections.filter {
                it.component == component &&
                    it.deploymentContext == expectedDeploymentContext &&
                    it.inventoryVersion == expectedInventoryVersion
            }

            if (matching.size != 1) {
                if (matching.size > 1) conflicts += component
                unresolved += component
                continue
            }

            val record = matching.single()

            if (record.inspectedPresence != entry.presence) {
                conflicts += component
                unresolved += component
                continue
            }

            if (now < record.validFrom || now >= record.validUntil ||
                record.finding !=
                    InspectionFinding.WITHIN_DECLARED_BOUNDARY_REPORTED
            ) {
                unresolved += component
                continue
            }

            if (component !in adverse) current += component
        }

        val discoveryAdverse =
            additionalPathDiscovery ==
                InspectionFinding.PROHIBITED_PATH_REPORTED
        val discoveryUnknown =
            additionalPathDiscovery == InspectionFinding.NOT_ESTABLISHED

        val state = when {
            adverse.isNotEmpty() || conflicts.isNotEmpty() ||
                discoveryAdverse -> ResultState.NEEDS_REVIEW
            unresolved.isNotEmpty() || discoveryUnknown ->
                ResultState.NOT_ESTABLISHED
            else -> ResultState.DECLARED_CHECKS_MET
        }

        return CommonResult(
            state,
            when (state) {
                ResultState.NEEDS_REVIEW -> CommonCode.REVIEW_REQUIRED
                ResultState.NOT_ESTABLISHED -> CommonCode.EVIDENCE_UNAVAILABLE
                else -> CommonCode.DECLARED_LOCAL_CHECKS
            },
            "This assessment checks declared inventory and inspection records. " +
                "It does not establish complete discovery or physically " +
                "enforce a local processing boundary.",
            LocalBoundaryAssessment(current, unresolved, adverse, conflicts)
        )
    }
}
