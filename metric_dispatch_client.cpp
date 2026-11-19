#include "metric_dispatch_client.hpp"

#include "../cpp-device-bridge/include/metric_dispatch_bridge.hpp"

#include <cerrno>
#include <cstring>
#include <stdexcept>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

namespace augmented_hub::environmental_metrics {

namespace {

constexpr std::size_t kMaximumResponseBytes = 1024U * 1024U;

bool has_json_object_shape(std::string_view json) {
    return json.size() >= 2U
        && json.front() == '{'
        && json.back() == '}';
}

}  // namespace

MetricDispatchClient::MetricDispatchClient(std::string socket_path)
    : socket_path_(std::move(socket_path)) {
    if (socket_path_.empty()) {
        throw std::invalid_argument("socket_path must not be empty");
    }

    if (socket_path_.size() >= sizeof(sockaddr_un::sun_path)) {
        throw std::invalid_argument("socket_path exceeds Unix socket path limit");
    }
}

DispatcherClientResult MetricDispatchClient::dispatch(
    std::string_view request_json
) const {
    if (!has_json_object_shape(request_json)) {
        return {
            false,
            {},
            "invalid_request",
            "request must be a JSON object",
        };
    }

    /*
     * Privacy validation occurs before I/O. Full parsing and conversion into a
     * JsonNode should occur in the project JSON adapter; this source retains a
     * strict transport boundary and refuses malformed envelope shapes.
     */
    if (request_json.find("\"person") != std::string_view::npos
        || request_json.find("\"medical") != std::string_view::npos
        || request_json.find("\"biometric") != std::string_view::npos
        || request_json.find("\"neural") != std::string_view::npos
        || request_json.find("\"device") != std::string_view::npos) {
        return {
            false,
            {},
            "prohibited_key",
            "request contains a prohibited aggregate-only policy key",
        };
    }

    const int socket_fd = ::socket(AF_UNIX, SOCK_STREAM, 0);
    if (socket_fd < 0) {
        return {
            false,
            {},
            "socket_create_failed",
            std::strerror(errno),
        };
    }

    sockaddr_un address{};
    address.sun_family = AF_UNIX;
    std::strncpy(
        address.sun_path,
        socket_path_.c_str(),
        sizeof(address.sun_path) - 1U
    );

    if (::connect(
            socket_fd,
            reinterpret_cast<const sockaddr*>(&address),
            sizeof(address)
        ) != 0) {
        const std::string message = std::strerror(errno);
        ::close(socket_fd);
        return {
            false,
            {},
            "socket_connect_failed",
            message,
        };
    }

    const char* cursor = request_json.data();
    std::size_t remaining = request_json.size();

    while (remaining > 0U) {
        const ssize_t written = ::send(
            socket_fd,
            cursor,
            remaining,
            MSG_NOSIGNAL
        );

        if (written <= 0) {
            const std::string message = std::strerror(errno);
            ::close(socket_fd);
            return {
                false,
                {},
                "socket_write_failed",
                message,
            };
        }

        cursor += written;
        remaining -= static_cast<std::size_t>(written);
    }

    ::shutdown(socket_fd, SHUT_WR);

    std::string response;
    response.reserve(4096U);

    char buffer[4096]{};
    while (true) {
        const ssize_t received = ::recv(
            socket_fd,
            buffer,
            sizeof(buffer),
            0
        );

        if (received == 0) {
            break;
        }

        if (received < 0) {
            const std::string message = std::strerror(errno);
            ::close(socket_fd);
            return {
                false,
                {},
                "socket_read_failed",
                message,
            };
        }

        response.append(buffer, static_cast<std::size_t>(received));

        if (response.size() > kMaximumResponseBytes) {
            ::close(socket_fd);
            return {
                false,
                {},
                "response_too_large",
                "dispatcher response exceeded maximum permitted size",
            };
        }
    }

    ::close(socket_fd);

    if (!has_json_object_shape(response)) {
        return {
            false,
            {},
            "invalid_response",
            "dispatcher response was not a JSON object",
        };
    }

    return {
        true,
        std::move(response),
        {},
        {},
    };
}

}  // namespace augmented_hub::environmental_metrics
