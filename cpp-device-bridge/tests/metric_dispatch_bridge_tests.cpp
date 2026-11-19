#include "../include/metric_dispatch_bridge.hpp"
#include "../include/metric_serialization.hpp"

#include <cassert>
#include <string>

using augmented_hub::environmental_metrics::JsonNode;
using augmented_hub::environmental_metrics::MetricDispatchBridge;
using augmented_hub::environmental_metrics::MetricName;
using augmented_hub::environmental_metrics::SurfaceBurnClockInput;
using augmented_hub::environmental_metrics::to_json;

int main() {
    {
        const auto metric = MetricDispatchBridge::parse_metric_name(
            "surface_burn_clock"
        );

        assert(metric.has_value());
        assert(*metric == MetricName::SurfaceBurnClock);
        assert(MetricDispatchBridge::is_supported_metric(
            "surface_burn_clock"
        ));
    }

    {
        const auto schema = MetricDispatchBridge::schema(
            MetricName::SurfaceBurnClock
        );

        assert(schema.canonical_name == "surface_burn_clock");

        bool found_surface_temperature_input = false;
        for (const auto& field : schema.input_fields) {
            if (field.name == "air_temperature_c") {
                found_surface_temperature_input = true;
                break;
            }
        }

        assert(found_surface_temperature_input);
    }

    {
        const SurfaceBurnClockInput input{
            "asphalt",
            43.0,
            950.0,
            2.0,
            0.0,
            0.0,
            210.0,
            55.0,
            0.95,
            0.90,
        };

        const std::string request_input_json = to_json(input);

        assert(
            request_input_json.find("\"material\":\"asphalt\"")
            != std::string::npos
        );
        assert(
            request_input_json.find("\"air_temperature_c\":43")
            != std::string::npos
        );
    }

    {
        const JsonNode valid_input = JsonNode::object({
            {
                "air_temperature_c",
                JsonNode::scalar(JsonNode::Kind::Number),
            },
            {
                "solar_radiation_w_m2",
                JsonNode::scalar(JsonNode::Kind::Number),
            },
            {
                "observation_coverage",
                JsonNode::scalar(JsonNode::Kind::Number),
            },
        });

        const auto result = MetricDispatchBridge::validate_aggregate_only(
            valid_input
        );

        assert(result.allowed);
    }

    {
        const JsonNode prohibited_input = JsonNode::object({
            {
                "surface",
                JsonNode::object({
                    {
                        "medical_history",
                        JsonNode::scalar(JsonNode::Kind::String),
                    },
                }),
            },
        });

        const auto result = MetricDispatchBridge::validate_aggregate_only(
            prohibited_input
        );

        assert(!result.allowed);
        assert(result.issue.has_value());
        assert(result.issue->reason == "prohibited_key");
    }

    /*
     * Integration assertion:
     *
     * When wired to MetricDispatchClient and the local canonical dispatcher,
     * the request built above must yield a JSON response whose `result` object
     * contains `estimated_surface_temperature_c`.
     *
     * This assertion belongs in a socket integration test because the header-only
     * bridge exposes schemas and serialization, while the dispatcher computes
     * canonical results.
     */
    return 0;
}
