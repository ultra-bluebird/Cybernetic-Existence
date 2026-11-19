#ifndef AUGMENTED_HUB_METRIC_DISPATCH_CLIENT_HPP
#define AUGMENTED_HUB_METRIC_DISPATCH_CLIENT_HPP

#include <string>
#include <string_view>

namespace augmented_hub::environmental_metrics {

struct DispatcherClientResult {
    bool ok{false};
    std::string response_json;
    std::string error_code;
    std::string error_message;
};

class MetricDispatchClient final {
public:
    explicit MetricDispatchClient(std::string socket_path);

    [[nodiscard]] DispatcherClientResult dispatch(
        std::string_view request_json
    ) const;

private:
    std::string socket_path_;
};

}  // namespace augmented_hub::environmental_metrics

#endif
