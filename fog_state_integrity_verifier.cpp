#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace augmentedhub::fog {

struct HashLogEntry {
    std::string event_id;
    std::string queue_id;
    std::uint64_t sequence_number;
    std::string previous_hash;
    std::string event_hash;
    std::vector<std::uint8_t> framed_hash_input;
};

struct VerificationResult {
    bool valid;
    std::size_t verified_count;
    std::optional<std::string> failed_event_id;
    std::string failure_reason;
};

class Sha256Provider {
public:
    virtual ~Sha256Provider() = default;

    virtual std::array<std::uint8_t, 32> digest(
        const std::vector<std::uint8_t>& input
    ) const = 0;
};

[[nodiscard]] bool is_lowercase_sha256_hex(
    const std::string& value
) {
    if (value.size() != 64U) {
        return false;
    }

    for (const char character : value) {
        const bool digit = character >= '0' && character <= '9';
        const bool lowercase_hex =
            character >= 'a' && character <= 'f';

        if (!digit && !lowercase_hex) {
            return false;
        }
    }

    return true;
}

[[nodiscard]] std::string to_lower_hex(
    const std::array<std::uint8_t, 32>& digest
) {
    static constexpr char digits[] = "0123456789abcdef";

    std::string output;
    output.reserve(64U);

    for (const std::uint8_t byte : digest) {
        output.push_back(digits[(byte >> 4U) & 0x0FU]);
        output.push_back(digits[byte & 0x0FU]);
    }

    return output;
}

[[nodiscard]] VerificationResult verify(
    const std::vector<HashLogEntry>& entries,
    const Sha256Provider& sha256
) {
    if (entries.empty()) {
        return VerificationResult{
            .valid = true,
            .verified_count = 0U,
            .failed_event_id = std::nullopt,
            .failure_reason = ""
        };
    }

    for (std::size_t index = 0U; index < entries.size(); ++index) {
        const HashLogEntry& entry = entries[index];

        if (entry.event_id.empty()
            || entry.queue_id.empty()
            || entry.framed_hash_input.empty()
            || !is_lowercase_sha256_hex(entry.previous_hash)
            || !is_lowercase_sha256_hex(entry.event_hash)) {
            return VerificationResult{
                .valid = false,
                .verified_count = index,
                .failed_event_id = entry.event_id,
                .failure_reason = "malformed integrity-log entry"
            };
        }

        if (index == 0U) {
            constexpr const char* genesis =
                "0000000000000000000000000000000000000000000000000000000000000000";

            if (entry.sequence_number != 0U
                || entry.previous_hash != genesis) {
                return VerificationResult{
                    .valid = false,
                    .verified_count = index,
                    .failed_event_id = entry.event_id,
                    .failure_reason = "invalid genesis entry"
                };
            }
        } else {
            const HashLogEntry& prior = entries[index - 1U];

            if (entry.queue_id != prior.queue_id
                || entry.sequence_number
                    != prior.sequence_number + 1U
                || entry.previous_hash != prior.event_hash) {
                return VerificationResult{
                    .valid = false,
                    .verified_count = index,
                    .failed_event_id = entry.event_id,
                    .failure_reason = "broken sequence or prior-hash link"
                };
            }
        }

        const std::string computed_hash =
            to_lower_hex(sha256.digest(entry.framed_hash_input));

        if (computed_hash != entry.event_hash) {
            return VerificationResult{
                .valid = false,
                .verified_count = index,
                .failed_event_id = entry.event_id,
                .failure_reason = "event hash mismatch"
            };
        }
    }

    return VerificationResult{
        .valid = true,
        .verified_count = entries.size(),
        .failed_event_id = std::nullopt,
        .failure_reason = ""
    };
}

}  // namespace augmentedhub::fog
