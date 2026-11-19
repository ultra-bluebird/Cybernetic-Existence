#include "governance_envelope.hpp"

#include <cctype>
#include <stdexcept>
#include <string>
#include <string_view>

namespace augmented_hub::environmental_metrics {

namespace {

[[nodiscard]] std::size_t skip_whitespace(
    std::string_view value,
    std::size_t index
) noexcept {
    while (index < value.size()
        && std::isspace(static_cast<unsigned char>(value[index])) != 0) {
        ++index;
    }

    return index;
}

[[nodiscard]] bool is_json_object(
    std::string_view value
) noexcept {
    const std::size_t first = skip_whitespace(value, 0U);

    if (first == value.size() || value[first] != '{') {
        return false;
    }

    std::size_t last = value.size();
    while (last > first
        && std::isspace(
            static_cast<unsigned char>(value[last - 1U])
        ) != 0) {
        --last;
    }

    return last > first && value[last - 1U] == '}';
}

[[nodiscard]] bool has_root_governance_key(
    std::string_view response_json
) noexcept {
    bool in_string = false;
    bool escaped = false;
    std::size_t object_depth = 0U;
    std::string current_key;
    bool reading_root_key = false;
    bool expecting_root_key = false;

    for (std::size_t index = 0U; index < response_json.size(); ++index) {
        const char character = response_json[index];

        if (in_string) {
            if (escaped) {
                escaped = false;
                if (reading_root_key) {
                    current_key.push_back(character);
                }
                continue;
            }

            if (character == '\\') {
                escaped = true;
                continue;
            }

            if (character == '"') {
                in_string = false;

                if (reading_root_key) {
                    std::size_t next = skip_whitespace(
                        response_json,
                        index + 1U
                    );

                    if (next < response_json.size()
                        && response_json[next] == ':'
                        && current_key == "governance") {
                        return true;
                    }

                    reading_root_key = false;
                }

                continue;
            }

            if (reading_root_key) {
                current_key.push_back(character);
            }

            continue;
        }

        if (character == '"') {
            in_string = true;
            current_key.clear();
            reading_root_key = object_depth == 1U && expecting_root_key;
            continue;
        }

        if (character == '{') {
            ++object_depth;

            if (object_depth == 1U) {
                expecting_root_key = true;
            }

            continue;
        }

        if (character == '}') {
            if (object_depth > 0U) {
                --object_depth;
            }

            continue;
        }

        if (object_depth == 1U && character == ',') {
            expecting_root_key = true;
            continue;
        }

        if (object_depth == 1U
            && !std::isspace(static_cast<unsigned char>(character))) {
            expecting_root_key = false;
        }
    }

    return false;
}

[[nodiscard]] std::size_t closing_brace_index(
    std::string_view value
) {
    std::size_t index = value.size();

    while (index > 0U
        && std::isspace(
            static_cast<unsigned char>(value[index - 1U])
        ) != 0) {
        --index;
    }

    if (index == 0U || value[index - 1U] != '}') {
        throw std::invalid_argument(
            "response_json must be a non-empty JSON object"
        );
    }

    return index - 1U;
}

}  // namespace

std::string governance_envelope_json(
    const GovernanceEnvelope& envelope
) {
    if (!is_valid_governance_envelope(envelope)) {
        throw std::invalid_argument(
            "governance envelope must preserve aggregate-only decision-support invariants"
        );
    }

    std::string result;
    result.reserve(192U);
    result += "{";
    result += "\"scope\":\"";
    result += governance_scope_name(envelope.scope);
    result += "\",";
    result += "\"individual_profiling\":false,";
    result += "\"automated_adverse_action\":false,";
    result += "\"external_action\":false";
    result += "}";

    return result;
}

std::string attach_governance_envelope(
    std::string_view response_json,
    const GovernanceEnvelope& envelope
) {
    if (!is_json_object(response_json)) {
        throw std::invalid_argument(
            "response_json must be a non-empty JSON object"
        );
    }

    if (has_root_governance_key(response_json)) {
        throw std::invalid_argument(
            "response_json already contains a root governance field"
        );
    }

    const std::string governance_json = governance_envelope_json(envelope);
    const std::size_t closing_brace = closing_brace_index(response_json);

    std::string response;
    response.reserve(
        response_json.size() + governance_json.size() + 16U
    );

    response.append(response_json.substr(0U, closing_brace));

    const std::size_t content_start = skip_whitespace(response_json, 0U);
    const bool has_members = closing_brace > content_start + 1U;

    if (has_members) {
        response.push_back(',');
    }

    response += "\"governance\":";
    response += governance_json;
    response.push_back('}');
    response.append(response_json.substr(closing_brace + 1U));

    return response;
}

}  // namespace augmented_hub::environmental_metrics
