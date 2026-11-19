-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Closed implementation profile; not a clinical plausibility specification.

local M = {}

local profile = {
    PORTION_BASES = {
        weighed = true, household_measure = true,
        package_label = true, visual_estimate = true,
        unknown_basis = true
    },
    PREPARATION_STATES = {
        raw = true, cooked = true, processed = true, mixed_recipe = true
    },
    NUTRIENT_UNITS = {
        g = true, mg = true, ug = true, kcal = true
    },
    NUTRIENTS = {
        protein = { unit = "g", maximum_per_100g = 100 },
        total_carbohydrate = { unit = "g", maximum_per_100g = 100 },
        fat = { unit = "g", maximum_per_100g = 100 },
        water = { unit = "g", maximum_per_100g = 100 },
        iron = { unit = "mg", maximum_per_100g = 100000 },
        vitamin_b12 = { unit = "ug", maximum_per_100g = 100000000 },
        dietary_energy = { unit = "kcal", maximum_per_100g = 10000 }
    },
    MAX_PORTION_MASS_G = 1000000000,
    MAX_RECORD_FIELDS = 32,
    SCHEMA_VERSIONS = {
        composition = "composition-record-v2",
        contribution_input = "portion-contribution-input-v2",
        contribution_output = "portion-contribution-v2",
        update_output = "composition-update-plan-v2",
        unavailable_output = "portion-operation-unavailable-v2"
    }
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in next, value do result[key] = copy(item) end
    return result
end

function M.get()
    return copy(profile)
end

return M
