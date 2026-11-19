#ifndef AUGMENTED_HUB_PREDICTIVE_MAINTENANCE_AND_INFRASTRUCTURE_GRAPH_HPP
#define AUGMENTED_HUB_PREDICTIVE_MAINTENANCE_AND_INFRASTRUCTURE_GRAPH_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::predictive_infrastructure {

enum class PredictiveInfrastructureError {
    empty_input,
    invalid_numeric_input,
    duplicate_identifier,
    invalid_time_order,
    insufficient_history,
    invalid_graph_reference,
    prohibited_graph_feature,
    unsafe_prediction_request
};

enum class MaintenanceRecommendation {
    continue_monitoring,
    inspection_candidate,
    preventive_maintenance_candidate,
    urgent_human_review
};

enum class InfrastructureNodeType {
    environmental_sensor,
    actuator,
    assistance_panel,
    power_bus,
    energy_source,
    transit_asset,
    water_asset,
    communication_gateway,
    facility
};

enum class InfrastructureEdgeType {
    electrical_supply,
    water_flow,
    physical_proximity,
    communication_link,
    control_dependency,
    service_dependency,
    maintenance_dependency
};

struct DegradationObservation {
    double timestamp_seconds{};
    double degradation_score{};
    double environmental_stress_score{};
    double measurement_uncertainty{};
    bool calibration_current{};
};

struct RemainingUsefulLifePolicy {
    double preventive_maintenance_rul_days{30.0};
    double urgent_review_rul_days{7.0};
    double maximum_relative_rul_uncertainty{0.50};
    double minimum_confidence{0.70};
    std::size_t minimum_history_points{10};
};

struct RemainingUsefulLifeAssessment {
    double expected_rul_days{};
    double lower_rul_days{};
    double upper_rul_days{};
    double relative_uncertainty{};
    double confidence{};
    MaintenanceRecommendation recommendation{
        MaintenanceRecommendation::continue_monitoring
    };
    bool human_review_required{};
    std::string plain_language_explanation;
};

struct InfrastructureGraphNode {
    std::string node_id;
    InfrastructureNodeType node_type{};
    double health_score{};
    double anomaly_score{};
    double criticality_score{};
    bool safety_critical{};
    bool essential_access_function{};
    bool contains_personal_data{};
};

struct InfrastructureGraphEdge {
    std::string source_node_id;
    std::string target_node_id;
    InfrastructureEdgeType edge_type{};
    double dependency_weight{};
    double propagation_delay_seconds{};
    bool bidirectional{};
};

struct GraphPropagationPolicy {
    double anomaly_activation_threshold{0.70};
    double propagation_decay{0.80};
    double urgent_cascade_risk_threshold{0.75};
    std::size_t maximum_propagation_hops{3};
    bool prohibit_personal_data_features{true};
};

struct GraphCascadeAssessment {
    std::vector<std::string> elevated_risk_node_ids;
    double maximum_propagated_risk{};
    bool essential_access_risk_detected{};
    bool safety_critical_risk_detected{};
    bool human_review_required{};
    std::string plain_language_explanation;
};

[[nodiscard]]
std::expected<RemainingUsefulLifeAssessment, PredictiveInfrastructureError>
estimate_remaining_useful_life(
    const std::vector<DegradationObservation>& history,
    const RemainingUsefulLifePolicy& policy);

[[nodiscard]]
std::expected<GraphCascadeAssessment, PredictiveInfrastructureError>
assess_infrastructure_cascade_risk(
    const std::vector<InfrastructureGraphNode>& nodes,
    const std::vector<InfrastructureGraphEdge>& edges,
    const GraphPropagationPolicy& policy);

}  // namespace augmented_hub::predictive_infrastructure

#endif
