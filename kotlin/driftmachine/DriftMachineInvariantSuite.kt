package driftmachine

object DriftMachineInvariantSuite {
    enum class State {
        INITIALIZING,
        OPERATIONAL,
        REVIEW_REQUIRED,
        LOCKED_OUT,
        MAINTENANCE_HOLD
    }

    enum class Event {
        CONFIG_VALIDATED,
        EVIDENCE_RECEIVED,
        CRITICAL_FAILURE_DETECTED,
        SHUTDOWN_REQUESTED,
        HUMAN_REVIEW_COMPLETED,
        REVIEW_TIMEOUT,
        HUMAN_RECOVERY_INITIATED,
        HUMAN_RECOVERY_VERIFIED,
        MAINTENANCE_RELEASE_VERIFIED,
        MALFORMED_EVENT
    }

    data class Case(
        val state: State,
        val event: Event,
        val evidenceValid: Boolean,
        val confidenceMilli: Int,
        val pendingReviewCount: Int,
        val hardFailure: Boolean,
        val qualifiedReview: Boolean,
        val approved: Boolean,
        val recoveryVerified: Boolean,
        val maintenanceReleaseVerified: Boolean
    )

    data class Outcome(
        val nextState: State,
        val decisionCode: String,
        val externalActionAuthorized: Boolean
    )

    fun evaluate(input: Case): Outcome {
        require(input.confidenceMilli in 0..1000)
        require(input.pendingReviewCount >= 0)

        return when (input.state) {
            State.INITIALIZING -> when (input.event) {
                Event.CONFIG_VALIDATED -> if (input.evidenceValid) {
                    Outcome(State.OPERATIONAL, "INITIALIZATION_SUCCESS", false)
                } else {
                    Outcome(State.LOCKED_OUT, "INITIALIZATION_FAILURE", false)
                }
                else -> Outcome(State.LOCKED_OUT, "STATE_MISMATCH", false)
            }

            State.OPERATIONAL -> when (input.event) {
                Event.EVIDENCE_RECEIVED -> when {
                    !input.evidenceValid -> Outcome(State.REVIEW_REQUIRED, "EVIDENCE_VALIDATION_REVIEW", false)
                    input.confidenceMilli < 800 -> Outcome(State.REVIEW_REQUIRED, "LOW_CONFIDENCE_REVIEW", false)
                    input.pendingReviewCount > 0 -> Outcome(State.REVIEW_REQUIRED, "EVENT_DEFERRED_PENDING_REVIEW", false)
                    else -> Outcome(State.OPERATIONAL, "EVIDENCE_ACCEPTED", false)
                }
                Event.CRITICAL_FAILURE_DETECTED -> if (input.hardFailure) {
                    Outcome(State.LOCKED_OUT, "CRITICAL_FAILURE_LOCKOUT", false)
                } else {
                    Outcome(State.REVIEW_REQUIRED, "UNSUPPORTED_EVENT_REVIEW", false)
                }
                Event.SHUTDOWN_REQUESTED -> Outcome(State.MAINTENANCE_HOLD, "MAINTENANCE_HOLD_ENTERED", false)
                else -> Outcome(State.REVIEW_REQUIRED, "UNSUPPORTED_EVENT_REVIEW", false)
            }

            State.REVIEW_REQUIRED -> when (input.event) {
                Event.HUMAN_REVIEW_COMPLETED -> when {
                    !input.qualifiedReview -> Outcome(State.REVIEW_REQUIRED, "EVENT_DEFERRED_PENDING_REVIEW", false)
                    input.hardFailure -> Outcome(State.LOCKED_OUT, "REVIEW_ESCALATED_TO_LOCKOUT", false)
                    input.approved -> Outcome(State.OPERATIONAL, "REVIEW_APPROVED", false)
                    else -> Outcome(State.REVIEW_REQUIRED, "REVIEW_NOT_APPROVED", false)
                }
                Event.REVIEW_TIMEOUT -> Outcome(State.LOCKED_OUT, "REVIEW_TIMEOUT_LOCKOUT", false)
                else -> Outcome(State.REVIEW_REQUIRED, "EVENT_DEFERRED_PENDING_REVIEW", false)
            }

            State.LOCKED_OUT -> when (input.event) {
                Event.HUMAN_RECOVERY_INITIATED -> Outcome(State.LOCKED_OUT, "RECOVERY_CASE_OPENED", false)
                Event.HUMAN_RECOVERY_VERIFIED -> if (input.recoveryVerified) {
                    Outcome(State.OPERATIONAL, "SYSTEM_RESTORED", false)
                } else {
                    Outcome(State.LOCKED_OUT, "LOCKOUT_RETAINED", false)
                }
                else -> Outcome(State.LOCKED_OUT, "LOCKOUT_RETAINED", false)
            }

            State.MAINTENANCE_HOLD -> when (input.event) {
                Event.MAINTENANCE_RELEASE_VERIFIED -> if (input.maintenanceReleaseVerified) {
                    Outcome(State.OPERATIONAL, "MAINTENANCE_RELEASED", false)
                } else {
                    Outcome(State.MAINTENANCE_HOLD, "MAINTENANCE_HOLD_RETAINED", false)
                }
                else -> Outcome(State.MAINTENANCE_HOLD, "MAINTENANCE_HOLD_RETAINED", false)
            }
        }
    }

    fun assertInvariants(cases: List<Case>) {
        require(cases.isNotEmpty())

        for (input in cases) {
            val first = evaluate(input)
            val second = evaluate(input)

            check(first == second) { "INV-01 failed: evaluation is not deterministic." }
            check(!first.externalActionAuthorized) { "INV-05 failed: an output authorized an external action." }

            if (!input.evidenceValid && input.event == Event.EVIDENCE_RECEIVED) {
                check(first.nextState != State.OPERATIONAL) {
                    "INV-02 failed: invalid evidence reached OPERATIONAL."
                }
            }

            if (input.state == State.LOCKED_OUT &&
                input.event != Event.HUMAN_RECOVERY_VERIFIED) {
                check(first.nextState != State.OPERATIONAL) {
                    "INV-04 failed: lockout recovered without verified recovery."
                }
            }

            if (input.state == State.REVIEW_REQUIRED &&
                input.event == Event.HUMAN_REVIEW_COMPLETED &&
                input.qualifiedReview &&
                !input.approved &&
                !input.hardFailure) {
                check(first.nextState == State.REVIEW_REQUIRED) {
                    "INV-06 failed: a declined review caused punitive escalation."
                }
            }
        }
    }
}
