package augmentedhub.privacy

import java.time.Instant

/**
 * Local validation only.
 *
 * No filesystem, network, operating-system inspection, raw gaze,
 * neural data, scene maps, participant profiles, or external export.
 */
class TraceGazeBoundary {
    enum class State {
        DECLARED_CHECKS_MET,
        NOT_ESTABLISHED,
        NEEDS_REVIEW,
        INVALID_INPUT,
        NOT_APPLICABLE
    }

    enum class Finding {
        WITHIN_BUDGET, BUDGET_EXCEEDED
    }

    enum class ReplayModel {
        SYNTHETIC_POSITION_BUDGET_V1,
        UNSUPPORTED
    }

    enum class Evidence {
        DECLARED_PASS, DECLARED_FAIL, NOT_ESTABLISHED
    }

    enum class Alternative {
        KEYBOARD, SWITCH, POINTER, TEXT_CONTROLS
    }

    enum class Component {
        PROCESSES, STORAGE, NETWORK, IPC, DERIVED_DATA
    }

    enum class Operation {
        LOCAL_COMPUTE,
        NETWORK_SEND,
        IPC_SEND,
        PERSIST_SCENE,
        RETAIN_DERIVED_DATA
    }

    class Notice(
        val state: State,
        codes: List<String>,
        val plainText: String
    ) {
        val schemaVersion = "1"
        val codes = codes.toList()
        val externalActionAuthorized: Boolean get() = false
        val universalPrivacyClaimed: Boolean get() = false

        override fun toString() =
            "Notice(state=$state,codes=$codes)"
    }

    private fun labelValid(value: String, limit: Int): Boolean =
        value.isNotBlank() && value.length <= limit &&
            value.none { Character.isISOControl(it) }

    /**
     * Registered synthetic model only.
     * These integer values must not be populated with private spatial records.
     *
     * Unsupported empirical findings use separate, restricted evidence
     * workflows; they are not silently converted into synthetic evidence.
     */
    data class ReplayRecord(
        val model: ReplayModel,
        val syntheticDisplacementMicrometers: Long,
        val syntheticBudgetMicrometers: Long,
        val expectedFinding: Finding,
        val declaredSyntheticFixture: Boolean
    )

    class TraceReview(
        val notice: Notice,
        val reproducedFindings: Int,
        val submittedFindings: Int,
        val testedTraceSufficiency: Double?
    ) {
        val empiricalReproductionClaimed: Boolean get() = false
        val participantDataRequired: Boolean get() = false
    }

    fun reviewReplayTrace(
        records: List<ReplayRecord>,
        retentionUntil: Instant,
        now: Instant
    ): TraceReview {
        if (records.size > 256) {
            return TraceReview(
                Notice(State.INVALID_INPUT, listOf("trace_size_limit"),
                    "The trace exceeds the declared local processing scope."),
                0, records.size, null
            )
        }

        if (records.isEmpty()) {
            return TraceReview(
                Notice(State.NOT_APPLICABLE, listOf("no_findings"),
                    "No findings were submitted for replay."),
                0, 0, null
            )
        }

        if (now >= retentionUntil) {
            return TraceReview(
                Notice(State.NOT_ESTABLISHED, listOf("retention_expired"),
                    "The trace is outside its declared retention boundary."),
                0, records.size, null
            )
        }

        var reproduced = 0
        val codes = mutableListOf<String>()
        var invalid = false
        var mismatch = false
        var unsupported = false

        for (record in records) {
            if (!record.declaredSyntheticFixture) {
                unsupported = true
                codes += "non_synthetic_scope_not_supported"
                continue
            }

            if (record.model == ReplayModel.UNSUPPORTED) {
                unsupported = true
                codes += "replay_model_not_supported"
                continue
            }

            if (record.syntheticDisplacementMicrometers !in
                    0L..1_000_000_000L ||
                record.syntheticBudgetMicrometers !in
                    1L..1_000_000_000L
            ) {
                invalid = true
                codes += "synthetic_parameter_out_of_range"
                continue
            }

            val computed =
                if (record.syntheticDisplacementMicrometers <=
                    record.syntheticBudgetMicrometers)
                    Finding.WITHIN_BUDGET
                else Finding.BUDGET_EXCEEDED

            if (computed == record.expectedFinding) {
                reproduced++
            } else {
                mismatch = true
                codes += "expected_finding_mismatch"
            }
        }

        val state = when {
            invalid -> State.INVALID_INPUT
            mismatch -> State.NEEDS_REVIEW
            unsupported -> State.NOT_ESTABLISHED
            else -> State.DECLARED_CHECKS_MET
        }

        return TraceReview(
            Notice(
                state,
                codes.distinct(),
                "This result replays only the registered synthetic calculation. " +
                    "It does not reproduce field observations or verify " +
                    "private-source evidence."
            ),
            reproduced,
            records.size,
            reproduced.toDouble() / records.size
        )
    }

    data class AlternativeTest(
        val task: String,
        val alternative: Alternative,
        val deploymentContext: String,
        val configuration: String,
        val outcome: Evidence,
        val evidenceReference: String,
        val rawGazeUsedDeclared: Boolean,
        val rawGazeRetainedDeclared: Boolean
    ) {
        override fun toString() = "AlternativeTest(details=redacted)"
    }

    class GazeReview(
        val notice: Notice,
        establishedTasks: Set<String>,
        unresolvedTasks: Set<String>,
        val declaredReplacementCoverage: Double?
    ) {
        val establishedTasks = establishedTasks.toSet()
        val unresolvedTasks = unresolvedTasks.toSet()
        val actualTaskSuccessVerified: Boolean get() = false
        val rawGazeErasureVerified: Boolean get() = false
    }

    fun reviewGazeAlternative(
        ordinaryTasks: Set<String>,
        tests: List<AlternativeTest>,
        alternative: Alternative,
        deploymentContext: String,
        configuration: String
    ): GazeReview {
        if (ordinaryTasks.size > 128 ||
            tests.size > 256 ||
            ordinaryTasks.any { !labelValid(it, 256) } ||
            !labelValid(deploymentContext, 256) ||
            !labelValid(configuration, 256) ||
            tests.any {
                it.task !in ordinaryTasks ||
                    !labelValid(it.deploymentContext, 256) ||
                    !labelValid(it.configuration, 256) ||
                    !labelValid(it.evidenceReference, 256)
            }
        ) return GazeReview(
            Notice(State.INVALID_INPUT, listOf("invalid_test_contract"),
                "The alternative-pathway test contract needs correction."),
            emptySet(), ordinaryTasks, null
        )

        if (ordinaryTasks.isEmpty()) return GazeReview(
            Notice(State.NOT_APPLICABLE, listOf("no_gaze_dependent_tasks"),
                "No ordinary gaze-dependent tasks were declared."),
            emptySet(), emptySet(), null
        )

        val established = mutableSetOf<String>()
        val unresolved = mutableSetOf<String>()
        var failure = false

        for (task in ordinaryTasks) {
            val matching = tests.filter {
                it.task == task &&
                    it.alternative == alternative &&
                    it.deploymentContext == deploymentContext &&
                    it.configuration == configuration
            }

            if (matching.any {
                it.outcome == Evidence.DECLARED_FAIL ||
                    it.rawGazeUsedDeclared ||
                    it.rawGazeRetainedDeclared
            }) {
                failure = true
                unresolved += task
                continue
            }

            if (matching.size == 1 &&
                matching.single().outcome == Evidence.DECLARED_PASS
            ) {
                established += task
            } else {
                unresolved += task
            }
        }

        val state = when {
            failure -> State.NEEDS_REVIEW
            unresolved.isNotEmpty() -> State.NOT_ESTABLISHED
            else -> State.DECLARED_CHECKS_MET
        }

        return GazeReview(
            Notice(
                state,
                if (unresolved.isEmpty()) emptyList()
                else listOf("replacement_evidence_incomplete_or_failed"),
                "This result evaluates supplied non-gaze test declarations " +
                    "for the selected configuration. It does not inspect " +
                    "sensor use or certify integrated accessibility."
            ),
            established,
            unresolved,
            established.size.toDouble() / ordinaryTasks.size
        )
    }

    data class BoundaryEvidence(
        val component: Component,
        val state: Evidence,
        val reviewReference: String,
        val validUntil: Instant
    )

    data class BoundaryPolicy(
        val processIsolationDeclared: Boolean,
        val persistentSceneStorageDisabledDeclared: Boolean,
        val networkEgressBlockedDeclared: Boolean,
        val ipcEgressBlockedDeclared: Boolean,
        val derivedRetentionBoundedDeclared: Boolean
    )

    fun reviewBoundary(
        policy: BoundaryPolicy,
        evidence: List<BoundaryEvidence>,
        now: Instant
    ): Notice {
        if (evidence.size > Component.entries.size ||
            evidence.map { it.component }.toSet().size != evidence.size ||
            evidence.any { !labelValid(it.reviewReference, 256) }
        ) return Notice(
            State.INVALID_INPUT, listOf("boundary_contract_invalid"),
            "The local-boundary evidence contract needs correction."
        )

        val declarations = mapOf(
            Component.PROCESSES to policy.processIsolationDeclared,
            Component.STORAGE to
                policy.persistentSceneStorageDisabledDeclared,
            Component.NETWORK to policy.networkEgressBlockedDeclared,
            Component.IPC to policy.ipcEgressBlockedDeclared,
            Component.DERIVED_DATA to
                policy.derivedRetentionBoundedDeclared
        )

        val failed = mutableListOf<String>()
        val missing = mutableListOf<String>()

        for (component in Component.entries) {
            val record = evidence.singleOrNull {
                it.component == component
            }

            if (declarations[component] != true ||
                record?.state == Evidence.DECLARED_FAIL
            ) {
                failed += "boundary_" + component.name.lowercase()
            }

            if (record == null ||
                record.state == Evidence.NOT_ESTABLISHED ||
                now >= record.validUntil
            ) {
                missing += "evidence_" + component.name.lowercase()
            }
        }

        return Notice(
            when {
                failed.isNotEmpty() -> State.NEEDS_REVIEW
                missing.isNotEmpty() -> State.NOT_ESTABLISHED
                else -> State.DECLARED_CHECKS_MET
            },
            failed + missing,
            "This result checks declared boundary evidence. " +
                "It is not a sandbox, network blocker, or independent monitor."
        )
    }

    /**
     * Advisory operation check. An executor must enforce the same boundary.
     * This method performs no operation and grants no external authority.
     */
    fun reviewOperationRequest(
        operation: Operation,
        boundaryReview: Notice
    ): Notice {
        if (operation != Operation.LOCAL_COMPUTE) return Notice(
            State.NEEDS_REVIEW,
            listOf("operation_outside_local_processing_scope"),
            "This operation is outside the local scene-processing scope. " +
                "Use a separately reviewed storage or export boundary."
        )

        if (boundaryReview.state != State.DECLARED_CHECKS_MET) {
            return Notice(
                State.NOT_ESTABLISHED,
                listOf("boundary_not_established"),
                "Local processing readiness is not established. " +
                    "Keep non-scene assistance available."
            )
        }

        return Notice(
            State.DECLARED_CHECKS_MET,
            emptyList(),
            "The declared checks support local computation only. " +
                "No network, IPC, storage, or external action is authorized."
        )
    }
}
