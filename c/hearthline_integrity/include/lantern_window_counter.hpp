#pragma once

#include <chrono>
#include <cstddef>
#include <deque>
#include <stdexcept>

namespace augmented_hub::hearthline {

class LanternWindowCounter {
public:
    using Clock = std::chrono::steady_clock;
    using TimePoint = Clock::time_point;

    explicit LanternWindowCounter(std::chrono::seconds window)
        : window_(window) {
        if (window_.count() <= 0) {
            throw std::invalid_argument("window must be positive");
        }
    }

    std::size_t record(TimePoint now = Clock::now()) {
        purgeExpired(now);
        timestamps_.push_back(now);
        return timestamps_.size();
    }

    [[nodiscard]] std::size_t count(TimePoint now = Clock::now()) {
        purgeExpired(now);
        return timestamps_.size();
    }

    void clear() {
        timestamps_.clear();
    }

private:
    void purgeExpired(TimePoint now) {
        const TimePoint cutoff = now - window_;

        while (!timestamps_.empty() && timestamps_.front() <= cutoff) {
            timestamps_.pop_front();
        }
    }

    std::chrono::seconds window_;
    std::deque<TimePoint> timestamps_;
};

} // namespace augmented_hub::hearthline
