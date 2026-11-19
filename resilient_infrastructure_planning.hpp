#ifndef AUGMENTED_HUB_RESILIENT_INFRASTRUCTURE_PLANNING_HPP
#define AUGMENTED_HUB_RESILIENT_INFRASTRUCTURE_PLANNING_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::resilient_infrastructure {

enum class PlanningError {
    empty_input,
    invalid_numeric_input,
    duplicate_identifier,
    insufficient_fleet_energy,
    no_feasible_assignment,
    insufficient_resilience_energy
};

enum class MaintenanceTaskKind {
    sensor_service,
    automatic_door_repair,
    solar_panel_cleaning,
    storm_drain_inspection
};

enum class TaskStatus {
    pending,
    scheduled,
    hold_for_review
};

struct MaintenanceBot {
    std::string bot_id;
    double position_x_m{};
    double position_y_m{};
    double available_energy_wh{};
    double reserve_energy_wh{};
    double travel_energy_wh_per_meter{};
    bool weather_capable{};
};

struct MaintenanceTask {
    std::string task_id;
    MaintenanceTaskKind kind{};
    double position_x_m{};
    double position_y_m{};
    double service_energy_wh{};
    double ecological_urgency{};
    double social_access_impact{};
    double reliability_impact{};
    double safety_risk{};
    bool weather_sensitive{};
    bool requires_human_confirmation{};
};

struct WeatherState {
    double precipitation_probability{};
    double wind_speed_m_per_second{};
    bool severe_weather_advisory{};
};

struct MaintenancePriorityWeights {
    double ecological_weight{};
    double social_weight{};
    double reliability_weight{};
    double risk_weight{};
};

struct SchedulingPolicy {
    MaintenancePriorityWeights weights;
    double minimum_assignment_score{};
    double maximum_precipitation_probability{0.50};
    double maximum_wind_speed_m_per_second{12.0};
    bool require_return_reserve{true};
};

struct ScheduledTask {
    std::string task_id;
    std::string bot_id;
    double priority_score{};
    double projected_energy_use_wh{};
    TaskStatus status{TaskStatus::pending};
    std::string plain_language_explanation;
};

struct MaintenanceScheduleResult {
    std::vector<ScheduledTask> scheduled_tasks;
    std::vector<std::string> held_task_ids;
    double total_priority_score{};
    std::string plain_language_explanation;
};

enum class PiezoelectricMaterial {
    pzt,
    pvdf,
    composite
};

struct EnergySourceForecast {
    double solar_incident_energy_kwh{};
    double solar_efficiency{};
    double piezo_mechanical_energy_kwh{};
    double piezo_efficiency{};
    double thermal_incident_energy_kwh{};
    double thermal_efficiency{};
};

struct BatteryStorage {
    double nominal_capacity_kwh{};
    double initial_state_of_charge{};
    double maximum_depth_of_discharge{};
    double self_discharge_fraction_per_day{};
    double round_trip_efficiency{};
};

struct CriticalLoadProfile {
    double sensor_arrays_kwh_per_day{};
    double assistance_panels_kwh_per_day{};
    double wireless_charging_kwh_per_day{};
    double safety_margin_fraction{};
};

struct PiezoelectricTileOption {
    PiezoelectricMaterial material{};
    double tile_area_m2{};
    double expected_footfalls_per_day{};
    double electrical_energy_per_footfall_joules{};
    double service_life_score{};
    double surface_accessibility_score{};
};

struct EnergyResiliencePolicy {
    std::size_t autonomy_days{5};
    double minimum_reserve_fraction{0.10};
    bool wireless_charging_is_sheddable{true};
};

struct EnergyResilienceResult {
    double renewable_generation_kwh{};
    double usable_initial_storage_kwh{};
    double critical_demand_kwh{};
    double optional_demand_kwh{};
    double remaining_energy_kwh{};
    bool critical_loads_supported{};
    bool optional_loads_supported{};
    PiezoelectricMaterial recommended_piezo_material{
        PiezoelectricMaterial::pvdf
    };
    double recommended_tile_area_m2{};
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<MaintenanceScheduleResult, PlanningError>
schedule_maintenance_tasks(
    const std::vector<MaintenanceBot>& bots,
    const std::vector<MaintenanceTask>& tasks,
    const WeatherState& weather,
    const SchedulingPolicy& policy);

[[nodiscard]] std::expected<EnergyResilienceResult, PlanningError>
evaluate_gathering_hub_resilience(
    const std::vector<EnergySourceForecast>& daily_forecasts,
    const BatteryStorage& battery,
    const CriticalLoadProfile& load_profile,
    const std::vector<PiezoelectricTileOption>& tile_options,
    const EnergyResiliencePolicy& policy);

}  // namespace augmented_hub::resilient_infrastructure

#endif
