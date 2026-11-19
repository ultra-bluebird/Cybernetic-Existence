#ifndef AUGMENTED_HUB_PUBLIC_RESERVE_ALLOCATOR_HPP
#define AUGMENTED_HUB_PUBLIC_RESERVE_ALLOCATOR_HPP

#include <chrono>
#include <cstdint>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>

namespace augmented_hub {

using ReserveClock = std::chrono::system_clock;
using ReserveTimePoint = ReserveClock::time_point;

struct PublicReserveRequest {
    std::string request_key;
    ReserveTimePoint requested_at;
    std::uint64_t requested_compute_seconds;
    bool eligible_public_interest_purpose;
    bool identity_based_restriction_detected;
};

struct PublicReserveCapacity {
    std::uint64_t available_compute_seconds;
    std::uint64_t maximum_immediate_allocation_seconds;
};

struct ReserveAllocationDecision {
    bool approved;
    bool requires_human_review;
    ReserveTimePoint access_deadline;
    std::string explanation_code;
};

class PublicReserveAllocator final {
public:
    static constexpr std::chrono::hours maximum_wait{72};

    [[nodiscard]] ReserveAllocationDecision evaluate(
        const PublicReserveRequest& request,
        const PublicReserveCapacity& capacity,
        ReserveTimePoint now
    ) const {
        validate(request, capacity);

        const ReserveTimePoint deadline =
            request.requested_at + maximum_wait;

        if (request.identity_based_restriction_detected) {
            return {
                false,
                true,
                deadline,
                "IDENTITY_BASED_RESTRICTION_REVIEW_REQUIRED"
            };
        }

        if (!request.eligible_public_interest_purpose) {
            return {
                false,
                true,
                deadline,
                "PURPOSE_ELIGIBILITY_REQUIRES_HUMAN_REVIEW"
            };
        }

        if (now > deadline) {
            return {
                false,
                true,
                deadline,
                "ACCESS_DEADLINE_MISSED_HUMAN_REMEDY_REQUIRED"
            };
        }

        if (request.requested_compute_seconds <=
            capacity.maximum_immediate_allocation_seconds &&
            request.requested_compute_seconds <= capacity.available_compute_seconds) {
            return {
                true,
                false,
                deadline,
                "PUBLIC_RESERVE_ALLOCATION_APPROVED"
            };
        }

        return {
            false,
            true,
            deadline,
            "CAPACITY_OR_SCHEDULING_REQUIRES_HUMAN_REVIEW_BEFORE_DEADLINE"
        };
    }

private:
    static void validate(
        const PublicReserveRequest& request,
        const PublicReserveCapacity& capacity
    ) {
        if (request.request_key.empty()) {
            throw std::invalid_argument("request_key must not be empty.");
        }

        if (request.requested_compute_seconds == 0) {
            throw std::invalid_argument(
                "requested_compute_seconds must be greater than zero."
            );
        }

        if (capacity.maximum_immediate_allocation_seconds == 0) {
            throw std::invalid_argument(
                "maximum_immediate_allocation_seconds must be greater than zero."
            );
        }
    }
};

}  // namespace augmented_hub

#endif
