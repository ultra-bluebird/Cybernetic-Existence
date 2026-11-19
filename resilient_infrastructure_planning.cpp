#include "resilient_infrastructure_planning.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <unordered_set>
#include <utility>

namespace augmented_hub::resilient_infrastructure {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

double distance_meters(
    double first_x,
    double first_y,
    double second_x,
    double second_y) noexcept {

    const double delta_x = first_x - second_x;
    const double delta_y = first_y - second_y;

    return std::sqrt(delta_x * delta_x + delta_y * delta_y);
}

bool weather_allows_task(
    const MaintenanceTask& task,
    const WeatherState& weather,
    const SchedulingPolicy& policy) noexcept {

    if (!task.weather_sensitive) {
        return true;
    }

    return !weather.severe_weather_advisory &&
        weather.precipitation_probability <=
            policy.maximum_precipitation_probability &&
        weather.wind_speed_m_per_second <=
            policy.maximum_wind_speed_m_per_second;
}

double task_score(
    const MaintenanceTask& task,
    const MaintenancePriorityWeights& weights) noexcept {

    return
        weights.ecological_weight * task.ecological_urgency +
        weights.social_weight * task.social_access_impact +
        weights.reliability_weight * task.reliability_impact -
        weights.risk_weight * task.safety_risk;
}

double daily_generation_kwh(const EnergySourceForecast& forecast) noexcept {
    return
        forecast.solar_incident_energy_kwh * forecast.solar_efficiency +
        forecast.piezo_mechanical_energy_kwh * forecast.piezo_efficiency +
        forecast.thermal_incident_energy_kwh * forecast.thermal_efficiency;
}

double tile_daily_energy_kwh(const PiezoelectricTileOption& option) noexcept {
    constexpr double joules_per_kwh = 3'600'000.0;

    return
        option.expected_footfalls_per_day *
        option.electrical_energy_per_footfall_joules /
        joules_per_kwh;
}

double tile_utility(const PiezoelectricTileOption& option) noexcept {
    return
        tile_daily_energy_kwh(option) *
        option.service_life_score *
        option.surface_accessibility_score;
}

}  // namespace

std::expected<MaintenanceScheduleResult, PlanningError>
schedule_maintenance_tasks(
    const std::vector<MaintenanceBot>& bots,
    const std::vector<MaintenanceTask>& tasks,
    const WeatherState& weather,
    const SchedulingPolicy& policy) {

    if (bots.empty() || tasks.empty()) {
        return std::unexpected(PlanningError::empty_input);
    }

    if (!finite_unit_interval(weather.precipitation_probability) ||
        !finite_nonnegative(weather.wind_speed_m_per_second) ||
        !finite_nonnegative(policy.minimum_assignment_score) ||
        !finite_unit_interval(policy.maximum_precipitation_probability) ||
        !finite_nonnegative(policy.maximum_wind_speed_m_per_second) ||
        !finite_nonnegative(policy.weights.ecological_weight) ||
        !finite_nonnegative(policy.weights.social_weight) ||
        !finite_nonnegative(policy.weights.reliability_weight) ||
        !finite_nonnegative(policy.weights.risk_weight)) {
        return std::unexpected(PlanningError::invalid_numeric_input);
    }

    std::unordered_set<std::string> identifiers;

    for (const auto& bot : bots) {
        if (bot.bot_id.empty() ||
            !identifiers.insert(bot.bot_id).second ||
            !finite_nonnegative(bot.position_x_m) ||
            !finite_nonnegative(bot.position_y_m) ||
            !finite_nonnegative(bot.available_energy_wh) ||
            !finite_nonnegative(bot.reserve_energy_wh) ||
            !finite_nonnegative(bot.travel_energy_wh_per_meter)) {
            return std::unexpected(PlanningError::invalid_numeric_input);
        }
    }

    identifiers.clear();

    for (const auto& task : tasks) {
        if (task.task_id.empty() ||
            !identifiers.insert(task.task_id).second ||
            !finite_nonnegative(task.position_x_m) ||
            !finite_nonnegative(task.position_y_m) ||
            !finite_nonnegative(task.service_energy_wh) ||
            !finite_unit_interval(task.ecological_urgency) ||
            !finite_unit_interval(task.social_access_impact) ||
            !finite_unit_interval(task.reliability_impact) ||
            !finite_unit_interval(task.safety_risk)) {
            return std::unexpected(PlanningError::invalid_numeric_input);
        }
    }

    struct RankedTask {
        const MaintenanceTask* task{};
        double score{};
    };

    std::vector<RankedTask> ranked_tasks;
    ranked_tasks.reserve(tasks.size());

    for (const auto& task : tasks) {
        ranked_tasks.push_back(RankedTask{
            .task = &task,
            .score = task_score(task, policy.weights)
        });
    }

    std::sort(
        ranked_tasks.begin(),
        ranked_tasks.end(),
        [](const RankedTask& left, const RankedTask& right) {
            return left.score > right.score;
        });

    std::vector<MaintenanceBot> working_bots = bots;
    MaintenanceScheduleResult result{};

    for (const auto& ranked_task : ranked_tasks) {
        const MaintenanceTask& task = *ranked_task.task;

        if (ranked_task.score < policy.minimum_assignment_score ||
            !weather_allows_task(task, weather, policy)) {
            result.held_task_ids.push_back(task.task_id);
            continue;
        }

        std::size_t selected_bot_index = working_bots.size();
        double selected_energy_use = std::numeric_limits<double>::infinity();

        for (std::size_t bot_index = 0;
             bot_index < working_bots.size();
             ++bot_index) {

            const MaintenanceBot& bot = working_bots[bot_index];

            if (task.weather_sensitive && !bot.weather_capable) {
                continue;
            }

            const double travel_distance = distance_meters(
                bot.position_x_m,
                bot.position_y_m,
                task.position_x_m,
                task.position_y_m);

            const double travel_energy =
                travel_distance * bot.travel_energy_wh_per_meter;

            const double return_energy =
                policy.require_return_reserve ? travel_energy : 0.0;

            const double required_energy =
                travel_energy + task.service_energy_wh + return_energy;

            if (bot.available_energy_wh <
                required_energy + bot.reserve_energy_wh) {
                continue;
            }

            if (required_energy < selected_energy_use) {
                selected_bot_index = bot_index;
                selected_energy_use = required_energy;
            }
        }

        if (selected_bot_index == working_bots.size()) {
            result.held_task_ids.push_back(task.task_id);
            continue;
        }

        MaintenanceBot& selected_bot = working_bots[selected_bot_index];

        selected_bot.available_energy_wh -= selected_energy_use;
        selected_bot.position_x_m = task.position_x_m;
        selected_bot.position_y_m = task.position_y_m;

        result.scheduled_tasks.push_back(ScheduledTask{
            .task_id = task.task_id,
            .bot_id = selected_bot.bot_id,
            .priority_score = ranked_task.score,
            .projected_energy_use_wh = selected_energy_use,
            .status = task.requires_human_confirmation
                ? TaskStatus::hold_for_review
                : TaskStatus::scheduled,
            .plain_language_explanation =
                task.requires_human_confirmation
                    ? "The task is energy-feasible and prioritized by ecological urgency, social access impact, reliability, and risk. It is held for human confirmation before field execution."
                    : "The task is energy-feasible and scheduled using ecological urgency, social access impact, reliability, risk, weather, and return-reserve constraints."
        });

        result.total_priority_score += ranked_task.score;
    }

    if (result.scheduled_tasks.empty()) {
        return std::unexpected(PlanningError::no_feasible_assignment);
    }

    result.plain_language_explanation =
        "The schedule uses task-level ecological, access, reliability, and safety evidence. It does not use personal identity, augmentation status, biometric data, or private accessibility preferences.";

    return result;
}

std::expected<EnergyResilienceResult> evaluate_gathering_hub_resilience(
    const std::vector<EnergySourceForecast>& daily_forecasts,
    const BatteryStorage& battery,
    const CriticalLoadProfile& load_profile,
    const std::vector<PiezoelectricTileOption>& tile_options,
    const EnergyResiliencePolicy& policy) {

    if (daily_forecasts.size() < policy.autonomy_days ||
        tile_options.empty() ||
        policy.autonomy_days == 0U) {
        return std::unexpected(PlanningError::empty_input);
    }

    if (!finite_nonnegative(battery.nominal_capacity_kwh) ||
        !finite_unit_interval(battery.initial_state_of_charge) ||
        !finite_unit_interval(battery.maximum_depth_of_discharge) ||
        !finite_unit_interval(battery.self_discharge_fraction_per_day) ||
        !finite_unit_interval(battery.round_trip_efficiency) ||
        !finite_nonnegative(load_profile.sensor_arrays_kwh_per_day) ||
        !finite_nonnegative(load_profile.assistance_panels_kwh_per_day) ||
        !finite_nonnegative(load_profile.wireless_charging_kwh_per_day) ||
        !finite_unit_interval(load_profile.safety_margin_fraction) ||
        !finite_unit_interval(policy.minimum_reserve_fraction)) {
        return std::unexpected(PlanningError::invalid_numeric_input);
    }

    for (const auto& forecast : daily_forecasts) {
        if (!finite_nonnegative(forecast.solar_incident_energy_kwh) ||
            !finite_unit_interval(forecast.solar_efficiency) ||
            !finite_nonnegative(forecast.piezo_mechanical_energy_kwh) ||
            !finite_unit_interval(forecast.piezo_efficiency) ||
            !finite_nonnegative(forecast.thermal_incident_energy_kwh) ||
            !finite_unit_interval(forecast.thermal_efficiency)) {
            return std::unexpected(PlanningError::invalid_numeric_input);
        }
    }

    PiezoelectricTileOption recommended_tile = tile_options.front();

    for (const auto& tile : tile_options) {
        if (!finite_nonnegative(tile.tile_area_m2) ||
            !finite_nonnegative(tile.expected_footfalls_per_day) ||
            !finite_nonnegative(tile.electrical_energy_per_footfall_joules) ||
            !finite_unit_interval(tile.service_life_score) ||
            !finite_unit_interval(tile.surface_accessibility_score)) {
            return std::unexpected(PlanningError::invalid_numeric_input);
        }

        if (tile_utility(tile) > tile_utility(recommended_tile)) {
            recommended_tile = tile;
        }
    }

    const double daily_critical_demand =
        (load_profile.sensor_arrays_kwh_per_day +
         load_profile.assistance_panels_kwh_per_day) *
        (1.0 + load_profile.safety_margin_fraction);

    const double daily_optional_demand =
        load_profile.wireless_charging_kwh_per_day *
        (1.0 + load_profile.safety_margin_fraction);

    double usable_storage =
        battery.nominal_capacity_kwh *
        battery.initial_state_of_charge *
        battery.maximum_depth_of_discharge;

    const double initial_usable_storage = usable_storage;
    double renewable_generation = 0.0;
    double critical_demand = 0.0;
    double optional_demand = 0.0;
    bool critical_loads_supported = true;
    bool optional_loads_supported = true;

    for (std::size_t day = 0; day < policy.autonomy_days; ++day) {
        usable_storage *= 1.0 - battery.self_discharge_fraction_per_day;

        const double daily_generation =
            daily_generation_kwh(daily_forecasts[day]);

        renewable_generation += daily_generation;
        usable_storage += daily_generation * battery.round_trip_efficiency;

        critical_demand += daily_critical_demand;

        if (usable_storage + kEpsilon < daily_critical_demand) {
            critical_loads_supported = false;
            break;
        }

        usable_storage -= daily_critical_demand;

        optional_demand += daily_optional_demand;

        if (usable_storage + kEpsilon < daily_optional_demand) {
            optional_loads_supported = false;

            if (!policy.wireless_charging_is_sheddable) {
                critical_loads_supported = false;
                break;
            }
        } else {
            usable_storage -= daily_optional_demand;
        }
    }

    const double minimum_reserve =
        battery.nominal_capacity_kwh * policy.minimum_reserve_fraction;

    critical_loads_supported =
        critical_loads_supported && usable_storage + kEpsilon >= minimum_reserve;

    return EnergyResilienceResult{
        .renewable_generation_kwh = renewable_generation,
        .usable_initial_storage_kwh = initial_usable_storage,
        .critical_demand_kwh = critical_demand,
        .optional_demand_kwh = optional_demand,
        .remaining_energy_kwh = std::max(usable_storage, 0.0),
        .critical_loads_supported = critical_loads_supported,
        .optional_loads_supported = optional_loads_supported,
        .recommended_piezo_material = recommended_tile.material,
        .recommended_tile_area_m2 = recommended_tile.tile_area_m2,
        .plain_language_explanation =
            critical_loads_supported
                ? "The modeled renewable generation and usable storage support the configured five-day critical-load window with the required reserve. Piezoelectric tiles are evaluated as supplementary harvested energy and accessible public-flooring infrastructure."
                : "The modeled system does not preserve the required critical-load reserve through the configured autonomy window. The evidence should remain in planning review while storage, critical-load tiers, generation forecasts, or load-shedding policy are evaluated."
    };
}

}  // namespace augmented_hub::resilient_infrastructure
