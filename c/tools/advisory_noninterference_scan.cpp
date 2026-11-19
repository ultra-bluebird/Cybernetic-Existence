#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace augmented_hub::tools {

struct Finding {
    std::filesystem::path path;
    std::string token;
    std::size_t line_number{};
};

[[nodiscard]] bool has_allowed_extension(const std::filesystem::path& path) {
    const std::string extension = path.extension().string();

    return extension == ".cpp" ||
        extension == ".hpp" ||
        extension == ".h" ||
        extension == ".java" ||
        extension == ".kt" ||
        extension == ".lua" ||
        extension == ".sql" ||
        extension == ".aln";
}

[[nodiscard]] std::vector<std::string> forbidden_tokens() {
    return {
        "curl_easy_init",
        "libcurl",
        "java.net.HttpURLConnection",
        "java.net.http",
        "java.net.Socket",
        "java.net.DatagramSocket",
        "Socket(",
        "ServerSocket(",
        "Runtime.getRuntime().exec",
        "ProcessBuilder",
        "system(",
        "popen(",
        "fork(",
        "execve(",
        "CreateProcess",
        "gpio",
        "serialport",
        "serialPort",
        "USBDevice",
        "hidapi",
        "actuator",
        "hardware_control",
        "device_control",
        "external_api",
        "physical_control"
    };
}

[[nodiscard]] std::vector<Finding> scan(
    const std::filesystem::path& root,
    const std::vector<std::string>& tokens) {

    std::vector<Finding> findings;

    for (const auto& entry :
         std::filesystem::recursive_directory_iterator(root)) {
        if (!entry.is_regular_file() || !has_allowed_extension(entry.path())) {
            continue;
        }

        std::ifstream input(entry.path());

        if (!input) {
            throw std::runtime_error(
                "unable to open source file: " + entry.path().string()
            );
        }

        std::string line;
        std::size_t line_number = 0;

        while (std::getline(input, line)) {
            ++line_number;

            for (const std::string& token : tokens) {
                if (line.find(token) != std::string::npos) {
                    findings.push_back({entry.path(), token, line_number});
                }
            }
        }
    }

    return findings;
}

}  // namespace augmented_hub::tools

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cerr << "usage: advisory_noninterference_scan <source-root>\n";
        return 2;
    }

    try {
        const auto findings = augmented_hub::tools::scan(
            argv[1],
            augmented_hub::tools::forbidden_tokens()
        );

        if (!findings.empty()) {
            for (const auto& finding : findings) {
                std::cerr
                    << finding.path.string()
                    << ":"
                    << finding.line_number
                    << ": forbidden capability token: "
                    << finding.token
                    << "\n";
            }

            return 1;
        }

        std::cout << "{\"status\":\"passed\",\"reason\":\"no forbidden advisory capability tokens found\"}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "{\"status\":\"withheld\",\"reason\":\""
                  << error.what() << "\"}\n";
        return 1;
    }
}
