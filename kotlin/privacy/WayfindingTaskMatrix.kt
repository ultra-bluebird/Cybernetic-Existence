package augmentedhub.privacy

import augmentedhub.common.Bounds
import augmentedhub.common.CommonCode
import augmentedhub.common.CommonResult
import augmentedhub.common.RedactedContent
import augmentedhub.common.ResultState
import java.util.Collections

enum class WayfindingTaskClass {
    READ_DIRECTIONS,
    CONFIRM_CHECKPOINT,
    PLACE_OVERLAY,
    AVOID_OBSTACLE,
    VERIFY_EGRESS
}

enum class WayfindingOutcome {
    READ_PUBLIC_ROUTE,
    CONFIRM_PUBLIC_CHECKPOINT,
    DISPLAY_REFERENCE_BOUND_OVERLAY,
    LIVE_OBSTACLE_WARNING,
    ESTABLISH_EGRESS_VALIDITY
}

enum class SceneDataClass {
    REVIEWED_PUBLIC_ROUTE,
    BOUNDED_CHECKPOINT_EVIDENCE,
    TRANSIENT_POSE_REFERENCE,
    PLACEMENT_ERROR_EVIDENCE,
    RAW_IMAGE,
    RAW_DEPTH_OR_MESH,
    PERSONAL_TRAJECTORY,
    PERSON_OR_PRIVATE_SYSTEM_ATTRIBUTES
}

enum class SensorSource {
    PUBLIC_MARKER_ADAPTER,
    DOCUMENTED_PLATFORM_TRACKING,
    CAMERA,
    DEPTH_SENSOR
}

enum class RetentionRule {
    REVIEWED_ROUTE_POLICY,
    SESSION_ONLY,
    TRANSIENT_NO_PERSISTENCE
}

class WayfindingMatrixRow internal constructor(
    val taskClass: WayfindingTaskClass,
    minimumData: Set<SceneDataClass>,
    allowedSources: Set<SensorSource>,
    retention: Map<SceneDataClass, RetentionRule>,
    val nonSceneAlternative: String,
    val separatelyReviewedSafetyCaseRequired: Boolean
) : RedactedContent() {
    val schemaVersion = "1"
    val minimumData =
        Collections.unmodifiableSet(minimumData.toSet())
    val allowedSources =
        Collections.unmodifiableSet(allowedSources.toSet())
    val retention =
        Collections.unmodifiableMap(retention.toMap())
}

class WayfindingMinimizationAssessment(
    val requiredTaskClass: WayfindingTaskClass,
    val declaredTaskClass: WayfindingTaskClass,
    val matrixRow: WayfindingMatrixRow,
    findings: List<String>
) : RedactedContent() {
    val findings =
        Collections.unmodifiableList(findings.toList())
    val sensorActivationAuthorized: Boolean get() = false
    val routeSafetyVerified: Boolean get() = false
    val upstreamPrivateCaptureVerifiedAbsent: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object WayfindingTaskMatrix {
    private fun requiredClass(
        outcomes: Set<WayfindingOutcome>
    ): WayfindingTaskClass = when {
        WayfindingOutcome.ESTABLISH_EGRESS_VALIDITY in outcomes ->
            WayfindingTaskClass.VERIFY_EGRESS
        WayfindingOutcome.LIVE_OBSTACLE_WARNING in outcomes ->
            WayfindingTaskClass.AVOID_OBSTACLE
        WayfindingOutcome.DISPLAY_REFERENCE_BOUND_OVERLAY in outcomes ->
            WayfindingTaskClass.PLACE_OVERLAY
        WayfindingOutcome.CONFIRM_PUBLIC_CHECKPOINT in outcomes ->
            WayfindingTaskClass.CONFIRM_CHECKPOINT
        else -> WayfindingTaskClass.READ_DIRECTIONS
    }

    fun row(taskClass: WayfindingTaskClass): WayfindingMatrixRow {
        val route = SceneDataClass.REVIEWED_PUBLIC_ROUTE
        val checkpoint = SceneDataClass.BOUNDED_CHECKPOINT_EVIDENCE
        val pose = SceneDataClass.TRANSIENT_POSE_REFERENCE
        val error = SceneDataClass.PLACEMENT_ERROR_EVIDENCE

        return when (taskClass) {
            WayfindingTaskClass.READ_DIRECTIONS -> WayfindingMatrixRow(
                taskClass,
                setOf(route),
                emptySet(),
                mapOf(route to RetentionRule.REVIEWED_ROUTE_POLICY),
                "Reviewed text route and accessible assistance information.",
                false
            )

            WayfindingTaskClass.CONFIRM_CHECKPOINT -> WayfindingMatrixRow(
                taskClass,
                setOf(route, checkpoint),
                setOf(SensorSource.PUBLIC_MARKER_ADAPTER),
                mapOf(
                    route to RetentionRule.REVIEWED_ROUTE_POLICY,
                    checkpoint to RetentionRule.SESSION_ONLY
                ),
                "Text route with explicit manual checkpoint confirmation.",
                false
            )

            WayfindingTaskClass.PLACE_OVERLAY -> WayfindingMatrixRow(
                taskClass,
                setOf(route, checkpoint, pose, error),
                setOf(
                    SensorSource.PUBLIC_MARKER_ADAPTER,
                    SensorSource.DOCUMENTED_PLATFORM_TRACKING
                ),
                mapOf(
                    route to RetentionRule.REVIEWED_ROUTE_POLICY,
                    checkpoint to RetentionRule.SESSION_ONLY,
                    pose to RetentionRule.TRANSIENT_NO_PERSISTENCE,
                    error to RetentionRule.SESSION_ONLY
                ),
                "Nonspatial route description and reviewed checkpoint text.",
                false
            )

            WayfindingTaskClass.AVOID_OBSTACLE -> WayfindingMatrixRow(
                taskClass,
                emptySet(),
                emptySet(),
                emptyMap(),
                "Independent established mobility assistance; descriptive " +
                    "route text is not equivalent to live obstacle warning.",
                true
            )

            WayfindingTaskClass.VERIFY_EGRESS -> WayfindingMatrixRow(
                taskClass,
                emptySet(),
                emptySet(),
                emptyMap(),
                "Established site emergency provisions and accessible assistance; " +
                    "an AR route description does not verify egress.",
                true
            )
        }
    }

    private fun reviewedReference(value: String?): Boolean =
        value != null && value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    /**
     * Proposed task-profile check, not a sensor implementation.
     *
     * Manual confirmation may provide checkpoint evidence without sensors.
     * Selected sources are bounded options, not acquisition authorization.
     */
    fun review(
        outcomes: Set<WayfindingOutcome>,
        declaredTaskClass: WayfindingTaskClass,
        applicationData: Set<SceneDataClass>,
        selectedSources: Set<SensorSource>,
        retention: Map<SceneDataClass, RetentionRule>,
        acquisitionScopeReviewReference: String?
    ): CommonResult<WayfindingMinimizationAssessment> {
        if (outcomes.isEmpty()) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "At least one explicit wayfinding outcome is required."
            )
        }

        val required = requiredClass(outcomes)
        val profile = row(required)
        val findings = mutableListOf<String>()

        if (declaredTaskClass != required) {
            findings += "task_class_does_not_match_requested_outcomes"
        }

        if (profile.separatelyReviewedSafetyCaseRequired) {
            findings += "minimum_safety_data_not_established_by_this_matrix"

            return CommonResult(
                ResultState.NEEDS_REVIEW,
                CommonCode.REVIEW_REQUIRED,
                "This outcome requires a separately reviewed sensing and " +
                    "safety case. No acquisition profile is authorized.",
                WayfindingMinimizationAssessment(
                    required, declaredTaskClass, profile, findings
                )
            )
        }

        if (applicationData != profile.minimumData) {
            findings += "application_data_differs_from_minimum_profile"
        }

        if (!profile.allowedSources.containsAll(selectedSources)) {
            findings += "source_outside_declared_task_profile"
        }

        if (retention != profile.retention) {
            findings += "retention_differs_from_task_profile"
        }

        if (selectedSources.isNotEmpty() &&
            !reviewedReference(acquisitionScopeReviewReference)
        ) {
            findings += "upstream_acquisition_review_missing"
        }

        val state = if (findings.isEmpty())
            ResultState.DECLARED_CHECKS_MET
        else ResultState.NEEDS_REVIEW

        return CommonResult(
            state,
            if (findings.isEmpty()) CommonCode.DECLARED_LOCAL_CHECKS
            else CommonCode.REVIEW_REQUIRED,
            "This result compares declared outcomes, application data, " +
                "sources, and retention with the proposed minimum profile. " +
                "It does not verify extraction, capture, or navigation safety.",
            WayfindingMinimizationAssessment(
                required, declaredTaskClass, profile, findings
            )
        )
    }
}
