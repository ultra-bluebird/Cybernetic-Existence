package org.augmentedhub.reserve

import kotlin.math.ceil

enum class AccessCohort {
    GENERAL,
    CYBERNETIC_HOST,
    AUGMENTED_CITIZEN
}

data class ReserveRequest(
    val requestKey: String,
    val sessionKey: String,
    val purpose: String,
    val requestedComputeSeconds: Long,
    val cohort: AccessCohort
)

data class MonthlyReserveCapacity(
    val totalComputeSeconds: Long,
    val allocatedGeneralSeconds: Long,
    val allocatedCyberneticHostSeconds: Long,
    val allocatedAugmentedCitizenSeconds: Long
) {
    init {
        require(totalComputeSeconds > 0L) {
            "totalComputeSeconds must be greater than zero."
        }

        require(
            allocatedGeneralSeconds >= 0L &&
                allocatedCyberneticHostSeconds >= 0L &&
                allocatedAugmentedCitizenSeconds >= 0L
        ) {
            "Allocated compute seconds must not be negative."
        }

        require(totalAllocatedSeconds <= totalComputeSeconds) {
            "Allocated compute seconds must not exceed total capacity."
        }
    }

    val totalAllocatedSeconds: Long
        get() = allocatedGeneralSeconds +
            allocatedCyberneticHostSeconds +
            allocatedAugmentedCitizenSeconds

    val protectedAllocatedSeconds: Long
        get() = allocatedCyberneticHostSeconds +
            allocatedAugmentedCitizenSeconds

    val protectedReservedSeconds: Long
        get() = ceil(totalComputeSeconds * 0.20).toLong()

    val unallocatedSeconds: Long
        get() = totalComputeSeconds - totalAllocatedSeconds

    val protectedReservationRemainingSeconds: Long
        get() = (protectedReservedSeconds - protectedAllocatedSeconds).coerceAtLeast(0L)
}

data class AllocationDecision(
    val approved: Boolean,
    val allocatedComputeSeconds: Long,
    val reasonCode: String,
    val requiresHumanReview: Boolean
)

class ReserveAllocator {
    fun allocate(
        request: ReserveRequest,
        capacity: MonthlyReserveCapacity
    ): AllocationDecision {
        require(request.requestKey.isNotBlank()) {
            "requestKey must not be blank."
        }

        require(request.sessionKey.length >= 32) {
            "sessionKey must be a newly generated, high-entropy request identifier."
        }

        require(request.requestedComputeSeconds > 0L) {
            "requestedComputeSeconds must be greater than zero."
        }

        val validPurpose = request.purpose in setOf(
            "eco_research",
            "civic_data_analysis",
            "restoration_monitoring",
            "accessibility_tooling"
        )

        if (!validPurpose) {
            return AllocationDecision(
                approved = false,
                allocatedComputeSeconds = 0L,
                reasonCode = "PURPOSE_REQUIRES_HUMAN_REVIEW",
                requiresHumanReview = true
            )
        }

        if (request.requestedComputeSeconds > capacity.unallocatedSeconds) {
            return AllocationDecision(
                approved = false,
                allocatedComputeSeconds = 0L,
                reasonCode = "PUBLIC_RESERVE_CAPACITY_UNAVAILABLE",
                requiresHumanReview = true
            )
        }

        val protectedCohort = request.cohort == AccessCohort.CYBERNETIC_HOST ||
            request.cohort == AccessCohort.AUGMENTED_CITIZEN

        if (protectedCohort) {
            return AllocationDecision(
                approved = true,
                allocatedComputeSeconds = request.requestedComputeSeconds,
                reasonCode = if (
                    request.requestedComputeSeconds <= capacity.protectedReservationRemainingSeconds
                ) {
                    "PROTECTED_COHORT_RESERVED_CAPACITY_ALLOCATED"
                } else {
                    "PROTECTED_COHORT_GENERAL_CAPACITY_ALLOCATED"
                },
                requiresHumanReview = false
            )
        }

        val generalCapacityAvailableWithoutConsumingReservation =
            capacity.unallocatedSeconds - capacity.protectedReservationRemainingSeconds

        if (request.requestedComputeSeconds > generalCapacityAvailableWithoutConsumingReservation) {
            return AllocationDecision(
                approved = false,
                allocatedComputeSeconds = 0L,
                reasonCode = "PROTECTED_COHORT_MONTHLY_RESERVATION_PRESERVED",
                requiresHumanReview = true
            )
        }

        return AllocationDecision(
            approved = true,
            allocatedComputeSeconds = request.requestedComputeSeconds,
            reasonCode = "GENERAL_PUBLIC_RESERVE_CAPACITY_ALLOCATED",
            requiresHumanReview = false
        )
    }
}
