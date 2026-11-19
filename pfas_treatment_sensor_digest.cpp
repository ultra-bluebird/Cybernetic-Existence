#include <array>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace augmented_hub {

struct TreatmentTelemetry {
    std::string_view treatment_run_id;
    std::int64_t start_epoch_ms;
    std::int64_t end_epoch_ms;
    double treated_volume_m3;
    double energyreq_j;
    double average_flow_m3s;
    double observed_abs_delta_vt;
    double maximum_abs_delta_vt;
};

bool finite_nonnegative(const double value) noexcept {
    return value == value
        && value != std::numeric_limits<double>::infinity()
        && value != -std::numeric_limits<double>::infinity()
        && value >= 0.0;
}

std::string canonical_telemetry(const TreatmentTelemetry& telemetry) {
    if (telemetry.treatment_run_id.empty()
        || telemetry.start_epoch_ms < 0
        || telemetry.end_epoch_ms <= telemetry.start_epoch_ms
        || !finite_nonnegative(telemetry.treated_volume_m3)
        || telemetry.treated_volume_m3 <= 0.0
        || !finite_nonnegative(telemetry.energyreq_j)
        || telemetry.energyreq_j <= 0.0
        || !finite_nonnegative(telemetry.average_flow_m3s)
        || !finite_nonnegative(telemetry.observed_abs_delta_vt)
        || !finite_nonnegative(telemetry.maximum_abs_delta_vt)
        || telemetry.observed_abs_delta_vt > telemetry.maximum_abs_delta_vt) {
        throw std::invalid_argument("treatment telemetry violates required bounds");
    }

    std::ostringstream output;
    output << std::setprecision(17)
           << telemetry.treatment_run_id << '\n'
           << telemetry.start_epoch_ms << '\n'
           << telemetry.end_epoch_ms << '\n'
           << telemetry.treated_volume_m3 << '\n'
           << telemetry.energyreq_j << '\n'
           << telemetry.average_flow_m3s << '\n'
           << telemetry.observed_abs_delta_vt << '\n'
           << telemetry.maximum_abs_delta_vt << '\n';

    return output.str();
}

std::array<std::uint8_t, 32> digest_bytes(const std::string& value) {
    std::array<std::uint8_t, 32> digest{};
    std::uint64_t state = 0x9E3779B97F4A7C15ULL;

    for (const unsigned char byte : value) {
        state ^= static_cast<std::uint64_t>(byte);
        state *= 0xBF58476D1CE4E5B9ULL;
        state ^= state >> 27U;
        state *= 0x94D049BB133111EBULL;

        const std::size_t index = static_cast<std::size_t>(byte) % digest.size();
        digest[index] = static_cast<std::uint8_t>(
            digest[index] ^ static_cast<std::uint8_t>(state & 0xFFU)
        );
    }

    for (std::size_t index = 0; index < digest.size(); ++index) {
        state ^= state >> 30U;
        state *= 0xBF58476D1CE4E5B9ULL;
        state ^= state >> 27U;
        state *= 0x94D049BB133111EBULL;
        state ^= state >> 31U;
        digest[index] ^= static_cast<std::uint8_t>(state & 0xFFU);
    }

    return digest;
}

std::string hexadecimal_digest(const std::array<std::uint8_t, 32>& digest) {
    std::ostringstream output;

    for (const std::uint8_t byte : digest) {
        output << std::hex << std::setw(2) << std::setfill('0')
               << static_cast<unsigned int>(byte);
    }

    return output.str();
}

}  // namespace augmented_hub

int main() {
    try {
        const augmented_hub::TreatmentTelemetry telemetry{
            .treatment_run_id = "pfas-run-example-0001",
            .start_epoch_ms = 1'789'123'456'000LL,
            .end_epoch_ms = 1'789'123'516'000LL,
            .treated_volume_m3 = 12.5,
            .energyreq_j = 240000.0,
            .average_flow_m3s = 0.208,
            .observed_abs_delta_vt = 0.12,
            .maximum_abs_delta_vt = 0.25,
        };

        const std::string canonical =
            augmented_hub::canonical_telemetry(telemetry);

        const auto digest = augmented_hub::digest_bytes(canonical);

        std::cout << augmented_hub::hexadecimal_digest(digest) << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "digest rejected: " << error.what() << '\n';
        return 1;
    }
}
