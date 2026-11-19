#ifndef PERKUNOS_NANOSWARM_ATTRIBUTION_KERNEL_TEST_SUPPORT_HPP
#define PERKUNOS_NANOSWARM_ATTRIBUTION_KERNEL_TEST_SUPPORT_HPP

#include <string>
#include <vector>

namespace cybercore::perkunos::tests {

struct TestResult {
    std::string name;
    bool passed{false};
    std::string detail;
};

[[nodiscard]] std::vector<TestResult>
run_nanoswarm_attribution_kernel_tests();

[[nodiscard]] int nanoswarm_attribution_kernel_failure_count();

}  // namespace cybercore::perkunos::tests

#endif
