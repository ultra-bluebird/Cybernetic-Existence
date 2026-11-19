local corridor_negotiation = require("corridor_negotiation")

local metrics = {}

local function require_condition(condition, message)
    if not condition then
        error(message, 2)
    end
end

local function quantile(sorted_values, probability)
    require_condition(type(sorted_values) == "table", "sorted_values must be a table")
    require_condition(#sorted_values > 0, "sorted_values must not be empty")
    require_condition(
        type(probability) == "number" and probability >= 0 and probability <= 1,
        "probability must be within [0, 1]"
    )

    local position = math.ceil(probability * #sorted_values)

    if position < 1 then
        position = 1
    end

    return sorted_values[position]
end

local function mean(values)
    require_condition(type(values) == "table", "values must be a table")

    if #values == 0 then
        return 0
    end

    local total = 0

    for _, value in ipairs(values) do
        total = total + value
    end

    return total / #values
end

local function population_standard_deviation(values, values_mean)
    require_condition(type(values) == "table", "values must be a table")

    if #values == 0 then
        return 0
    end

    local squared_sum = 0

    for _, value in ipairs(values) do
        local deviation = value - values_mean
        squared_sum = squared_sum + deviation * deviation
    end

    return math.sqrt(squared_sum / #values)
end

local function normal_approximation_interval(proportion, trial_count)
    require_condition(
        type(proportion) == "number" and proportion >= 0 and proportion <= 1,
        "proportion must be within [0, 1]"
    )
    require_condition(
        type(trial_count) == "number" and trial_count > 0 and trial_count % 1 == 0,
        "trial_count must be a positive integer"
    )

    local standard_error = math.sqrt(
        proportion * (1 - proportion) / trial_count
    )

    local half_width = 1.96 * standard_error

    return {
        lower = math.max(0, proportion - half_width),
        upper = math.min(1, proportion + half_width),
        standard_error = standard_error,
    }
end

local function run_simulation(config)
    local result = corridor_negotiation.run_monte_carlo(config)

    local bot_yield_ratio = result.delivery_bot_yield_ratio
    local unsafe_configuration_ratio =
        result.unsafe_configuration_count / result.trials

    return {
        seed = result.seed,
        trials = result.trials,
        pedestrian_priority_grants = result.pedestrian_priority_grants,
        mobility_priority_grants = result.mobility_priority_grants,
        delivery_bot_priority_grants = result.delivery_bot_priority_grants,
        unsafe_configuration_count = result.unsafe_configuration_count,
        delivery_bot_yield_count = result.delivery_bot_yield_count,
        delivery_bot_yield_ratio = bot_yield_ratio,
        unsafe_configuration_ratio = unsafe_configuration_ratio,
        delivery_bot_yield_interval =
            normal_approximation_interval(bot_yield_ratio, result.trials),
        unsafe_configuration_interval =
            normal_approximation_interval(
                unsafe_configuration_ratio,
                result.trials
            ),
    }
end

function metrics.run_seed_series(config, seeds)
    require_condition(type(config) == "table", "config must be a table")
    require_condition(type(seeds) == "table", "seeds must be a table")
    require_condition(#seeds > 0, "seeds must not be empty")

    local runs = {}
    local bot_yield_ratios = {}
    local unsafe_ratios = {}

    for index, seed in ipairs(seeds) do
        local run_config = {}

        for key, value in pairs(config) do
            run_config[key] = value
        end

        run_config.seed = seed

        local result = run_simulation(run_config)

        runs[index] = result
        bot_yield_ratios[index] = result.delivery_bot_yield_ratio
        unsafe_ratios[index] = result.unsafe_configuration_ratio
    end

    table.sort(bot_yield_ratios)
    table.sort(unsafe_ratios)

    local mean_bot_yield = mean(bot_yield_ratios)
    local mean_unsafe_ratio = mean(unsafe_ratios)

    return {
        runs = runs,
        aggregate = {
            run_count = #runs,
            mean_delivery_bot_yield_ratio = mean_bot_yield,
            delivery_bot_yield_standard_deviation =
                population_standard_deviation(
                    bot_yield_ratios,
                    mean_bot_yield
                ),
            delivery_bot_yield_median =
                quantile(bot_yield_ratios, 0.50),
            delivery_bot_yield_p95 =
                quantile(bot_yield_ratios, 0.95),
            mean_unsafe_configuration_ratio = mean_unsafe_ratio,
            unsafe_configuration_standard_deviation =
                population_standard_deviation(
                    unsafe_ratios,
                    mean_unsafe_ratio
                ),
            unsafe_configuration_median =
                quantile(unsafe_ratios, 0.50),
            unsafe_configuration_p95 =
                quantile(unsafe_ratios, 0.95),
        },
    }
end

function metrics.compare_with_common_random_numbers(
    baseline_config,
    candidate_config,
    seeds
)
    require_condition(
        type(baseline_config) == "table",
        "baseline_config must be a table"
    )
    require_condition(
        type(candidate_config) == "table",
        "candidate_config must be a table"
    )
    require_condition(type(seeds) == "table", "seeds must be a table")
    require_condition(#seeds > 0, "seeds must not be empty")

    local paired_differences = {}

    for index, seed in ipairs(seeds) do
        local baseline_run_config = {}
        local candidate_run_config = {}

        for key, value in pairs(baseline_config) do
            baseline_run_config[key] = value
        end

        for key, value in pairs(candidate_config) do
            candidate_run_config[key] = value
        end

        baseline_run_config.seed = seed
        candidate_run_config.seed = seed

        local baseline_result = run_simulation(baseline_run_config)
        local candidate_result = run_simulation(candidate_run_config)

        paired_differences[index] = {
            seed = seed,
            delivery_bot_yield_ratio_difference =
                candidate_result.delivery_bot_yield_ratio
                - baseline_result.delivery_bot_yield_ratio,
            unsafe_configuration_ratio_difference =
                candidate_result.unsafe_configuration_ratio
                - baseline_result.unsafe_configuration_ratio,
            mobility_priority_grant_difference =
                candidate_result.mobility_priority_grants
                - baseline_result.mobility_priority_grants,
        }
    end

    local yield_differences = {}
    local unsafe_differences = {}
    local mobility_differences = {}

    for index, difference in ipairs(paired_differences) do
        yield_differences[index] =
            difference.delivery_bot_yield_ratio_difference
        unsafe_differences[index] =
            difference.unsafe_configuration_ratio_difference
        mobility_differences[index] =
            difference.mobility_priority_grant_difference
    end

    return {
        paired_differences = paired_differences,
        aggregate = {
            mean_delivery_bot_yield_ratio_difference =
                mean(yield_differences),
            mean_unsafe_configuration_ratio_difference =
                mean(unsafe_differences),
            mean_mobility_priority_grant_difference =
                mean(mobility_differences),
        },
    }
end

return metrics
