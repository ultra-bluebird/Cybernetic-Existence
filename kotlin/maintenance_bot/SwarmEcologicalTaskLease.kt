package augmentedhub.maintenance_bot

import java.time.Duration
import java.time.Instant
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

enum class EcologicalTaskClass {
    LITTER_COLLECTION,
    LEAF_REMOVAL,
    DRAIN_CLEARING,
    BIOSWALE_INLET_CLEARING,
    ACCESSIBILITY_OBSTRUCTION_REVIEW
}

enum class ClearanceState {
    APPROVED,
    REVIEW_REQUIRED,
    BLOCKED
}

enum class EnergyBand {
    CRITICAL,
    RESERVE_ONLY,
    ADEQUATE,
    HIGH
}

enum class LeaseState {
    PROPOSED,
    CLAIMED,
    COMPLETED,
    EXPIRED,
    RELEASED
}

data class TaskConstraints(
    val pedestrianSafety: ClearanceState,
    val accessibleRoute: ClearanceState,
    val hazardClearance: ClearanceState,
    val noiseWindowAllowed: Boolean,
    val zoneServiceFloorSatisfied: Boolean
) {
    fun permitsWork(energyBand: EnergyBand): Boolean {
        return pedestrianSafety == ClearanceState.APPROVED &&
            accessibleRoute == ClearanceState.APPROVED &&
            hazardClearance == ClearanceState.APPROVED &&
            noiseWindowAllowed &&
            zoneServiceFloorSatisfied &&
            energyBand != EnergyBand.CRITICAL &&
            energyBand != EnergyBand.RESERVE_ONLY
    }
}

data class EcologicalTask(
    val taskId: String,
    val taskClass: EcologicalTaskClass,
    val coarseZoneClass: String,
    val ecologicalBenefit: Double,
    val urgency: Double,
    val coverageNeed: Double,
    val noiseCost: Double,
    val constraints: TaskConstraints
) {
    fun validate(): EcologicalTask {
        require(taskId.matches(Regex("^task-[a-z0-9-]{8,95}$"))) {
            "taskId must use the task identifier format."
        }
        require(coarseZoneClass.matches(Regex("^[a-z][a-z0-9-]{2,63}$"))) {
            "coarseZoneClass must be a non-identifying planning-zone class."
        }
        require(ecologicalBenefit in 0.0..1.0) {
            "ecologicalBenefit must be between 0 and 1."
        }
        require(urgency in 0.0..1.0) {
            "urgency must be between 0 and 1."
        }
        require(coverageNeed in 0.0..1.0) {
            "coverageNeed must be between 0 and 1."
        }
        require(noiseCost in 0.0..1.0) {
            "noiseCost must be between 0 and 1."
        }
        return this
    }
}

data class BotBidContext(
    val ephemeralBotClaimId: String,
    val energyBand: EnergyBand,
    val travelCost: Double,
    val energyCost: Double,
    val signedMessageReady: Boolean,
    val humanDispatchApproved: Boolean
) {
    fun validate(): BotBidContext {
        require(ephemeralBotClaimId.matches(Regex("^claim-[a-z0-9-]{8,95}$"))) {
            "ephemeralBotClaimId must be a short-lived claim identifier."
        }
        require(travelCost in 0.0..1.0) {
            "travelCost must be between 0 and 1."
        }
        require(energyCost in 0.0..1.0) {
            "energyCost must be between 0 and 1."
        }
        return this
    }
}

data class TaskBid(
    val taskId: String,
    val ephemeralBotClaimId: String,
    val value: Double,
    val eligible: Boolean,
    val explanation: String
)

data class TaskLease(
    val leaseId: String,
    val taskId: String,
    val holderClaimId: String,
    val issuedAt: Instant,
    val expiresAt: Instant,
    val state: LeaseState,
    val signed: Boolean,
    val storesResidentData: Boolean,
    val storesRawLocationHistory: Boolean,
    val autonomousPublicDispatchAuthorized: Boolean
) {
    fun isActive(now: Instant): Boolean {
        return state == LeaseState.CLAIMED && now.isBefore(expiresAt)
    }
}

object SwarmEcologicalTaskLease {
    fun calculateBid(task: EcologicalTask, context: BotBidContext): TaskBid {
        task.validate()
        context.validate()

        if (!context.signedMessageReady) {
            return noBid(task, context, "A signed local task message is required.")
        }

        if (!context.humanDispatchApproved) {
            return noBid(task, context, "Human dispatch approval is required before a task claim.")
        }

        if (!task.constraints.permitsWork(context.energyBand)) {
            return noBid(task, context, "Task safety, accessibility, hazard, noise, energy, or coverage constraints are not satisfied.")
        }

        val numerator =
            0.45 * task.ecologicalBenefit +
                0.30 * task.urgency +
                0.25 * task.coverageNeed

        val denominator =
            1.0 +
                0.35 * context.travelCost +
                0.40 * context.energyCost +
                0.25 * task.noiseCost

        return TaskBid(
            taskId = task.taskId,
            ephemeralBotClaimId = context.ephemeralBotClaimId,
            value = numerator / denominator,
            eligible = true,
            explanation = "Bid is based on bounded ecological benefit, urgency, coverage need, travel cost, energy cost, and noise cost after all hard constraints passed."
        )
    }

    fun selectWinner(bids: List<TaskBid>): TaskBid? {
        val eligibleBids = bids.filter { it.eligible }

        if (eligibleBids.isEmpty()) {
            return null
        }

        return eligibleBids.sortedWith(
            compareByDescending<TaskBid> { it.value }
                .thenBy { it.ephemeralBotClaimId }
        ).first()
    }

    fun issueLease(
        winningBid: TaskBid,
        now: Instant,
        leaseDuration: Duration
    ): TaskLease {
        require(winningBid.eligible) {
            "A lease can only be issued for an eligible bid."
        }
        require(!leaseDuration.isZero && !leaseDuration.isNegative) {
            "leaseDuration must be positive."
        }
        require(leaseDuration <= Duration.ofHours(1)) {
            "leaseDuration may not exceed one hour."
        }

        return TaskLease(
            leaseId = "lease-${UUID.randomUUID()}",
            taskId = winningBid.taskId,
            holderClaimId = winningBid.ephemeralBotClaimId,
            issuedAt = now,
            expiresAt = now.plus(leaseDuration),
            state = LeaseState.CLAIMED,
            signed = true,
            storesResidentData = false,
            storesRawLocationHistory = false,
            autonomousPublicDispatchAuthorized = false
        )
    }

    fun coverageNeed(
        minimumRequiredTasks: Int,
        completedTasks: Int
    ): Double {
        require(minimumRequiredTasks >= 0) {
            "minimumRequiredTasks must not be negative."
        }
        require(completedTasks >= 0) {
            "completedTasks must not be negative."
        }

        if (minimumRequiredTasks == 0) {
            return 0.0
        }

        return min(
            1.0,
            max(
                0.0,
                (minimumRequiredTasks - completedTasks).toDouble() /
                    minimumRequiredTasks.toDouble()
            )
        )
    }

    private fun noBid(
        task: EcologicalTask,
        context: BotBidContext,
        explanation: String
    ): TaskBid {
        return TaskBid(
            taskId = task.taskId,
            ephemeralBotClaimId = context.ephemeralBotClaimId,
            value = 0.0,
            eligible = false,
            explanation = explanation
        )
    }
}
