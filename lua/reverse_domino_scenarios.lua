-- Pure expected-value scenario model.
-- Fractional sites represent expectations, not partial real organizations.
-- Every coefficient is an explicit assumption, not an observed effect.
local M = {}
M.version = "1.0.0"

local function fail(field, message)
    error({code = "invalid_scenario", field = field, message = message}, 0)
end

local function number(value, field)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge then
        fail(field, "Expected a finite number.")
    end
end

local function nonnegative(value, field)
    number(value, field)
    if value < 0 then
        fail(field, "Expected a nonnegative number.")
    end
end

local function probability(value, field)
    nonnegative(value, field)
    if value > 1 then
        fail(field, "Expected a value from zero through one.")
    end
end

local function text(value, field)
    if type(value) ~= "string" or not value:match("%S") then
        fail(field, "Expected nonempty text.")
    end
end

function M.simulate(config)
    if type(config) ~= "table" or getmetatable(config) ~= nil then
        fail("config", "Expected a plain table.")
    end

    text(config.assumption_basis, "assumption_basis")
    text(config.period_unit, "period_unit")

    if type(config.rights_review_passed) ~= "boolean" then
        fail("rights_review_passed", "Expected a boolean.")
    end

    for _, field in ipairs({
        "sites", "initial_sites", "periods", "contacts_per_site",
        "hours_saved_per_active_site", "maintenance_hours_per_site",
        "setup_hours_per_new_site", "gross_kwh_saved_per_active_site",
        "operating_kwh_per_site", "setup_kwh_per_new_site",
        "rebound_fraction"
    }) do
        nonnegative(config[field], field)
    end

    for _, field in ipairs({
        "adoption_probability", "review_pass_probability",
        "attrition_probability", "reinvestment_fraction"
    }) do
        probability(config[field], field)
    end

    if config.sites < 1 or config.sites % 1 ~= 0 then
        fail("sites", "Expected a positive integer.")
    end
    if config.initial_sites > config.sites
        or config.initial_sites % 1 ~= 0 then
        fail("initial_sites", "Expected an integer within site capacity.")
    end
    if config.periods < 1 or config.periods > 1000
        or config.periods % 1 ~= 0 then
        fail("periods", "Expected an integer from one through 1000.")
    end

    if not config.rights_review_passed then
        return {
            status = "blocked",
            reason = "rights_review_not_passed",
            periods = {}
        }
    end

    local active = config.initial_sites
    local ever_adopted = active
    local rows = {}

    for period = 1, config.periods do
        local remaining = config.sites - ever_adopted
        local potential = active
            * config.contacts_per_site
            * config.adoption_probability
            * config.review_pass_probability
            * remaining / config.sites
        local new_sites = math.min(remaining, potential)
        local retained = active * (1 - config.attrition_probability)

        -- Current sites contribute this period; new sites start next period.
        local net_hours = active
            * (config.hours_saved_per_active_site
                - config.maintenance_hours_per_site)
            - new_sites * config.setup_hours_per_new_site

        local net_kwh = active
            * (config.gross_kwh_saved_per_active_site
                * (1 - config.rebound_fraction)
                - config.operating_kwh_per_site)
            - new_sites * config.setup_kwh_per_new_site

        number(net_hours, "computed_net_hours")
        number(net_kwh, "computed_net_kwh")

        rows[#rows + 1] = {
            period = period,
            active_sites_at_start = active,
            new_sites_at_end = new_sites,
            active_sites_at_end = retained + new_sites,
            net_hours = net_hours,
            reinvestment_capacity_hours =
                math.max(0, net_hours) * config.reinvestment_fraction,
            net_kwh = net_kwh
        }

        active = retained + new_sites
        ever_adopted = ever_adopted + new_sites
    end

    local replication = nil
    if config.attrition_probability > 0 then
        replication = config.contacts_per_site
            * config.adoption_probability
            * config.review_pass_probability
            / config.attrition_probability
    end

    return {
        status = "scenario_only",
        assumption_basis = config.assumption_basis,
        period_unit = config.period_unit,
        early_replication_approximation = replication,
        replication_unavailable_reason =
            config.attrition_probability == 0
            and "zero_attrition_requires_finite_horizon_interpretation"
            or nil,
        periods = rows,
        limitation = "No causal, ecological, or deployment claim is implied."
    }
end

return M
