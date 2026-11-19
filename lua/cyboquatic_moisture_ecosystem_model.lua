local CyboquaticMoistureEcosystemModel = {}

local GRAVITY_M_PER_S2 = 9.80665
local MIN_PRESSURE_PA = 1.0
local MAX_SPECIFIC_HUMIDITY_KG_PER_KG = 0.1
local MAX_WIND_SPEED_M_PER_S = 150.0
local MAX_CARBON_INTENSITY_KGCO2E_PER_KWH = 5.0

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function require_number(name, value, minimum, maximum)
    if not is_finite_number(value) then
        error(name .. " must be a finite number")
    end

    if minimum ~= nil and value < minimum then
        error(name .. " must be at least " .. tostring(minimum))
    end

    if maximum ~= nil and value > maximum then
        error(name .. " must be at most " .. tostring(maximum))
    end

    return value
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function normalize(value, safe_limit, hard_limit)
    if not is_finite_number(value) then
        return 1.0
    end

    if hard_limit <= safe_limit then
        error("hard_limit must be greater than safe_limit")
    end

    if value <= safe_limit then
        return 0.0
    end

    return clamp((value - safe_limit) / (hard_limit - safe_limit), 0.0, 1.0)
end

local function vector_magnitude(x_component, y_component)
    return math.sqrt(x_component * x_component + y_component * y_component)
end

local function degrees_from_vector(x_component, y_component)
    local radians = math.atan(y_component, x_component)
    local degrees = math.deg(radians)

    if degrees < 0.0 then
        return degrees + 360.0
    end

    return degrees
end

local function weighted_mean(samples, extractor)
    local numerator = 0.0
    local denominator = 0.0

    for _, sample in ipairs(samples) do
        local weight = sample.pressure_thickness_pa
        numerator = numerator + extractor(sample) * weight
        denominator = denominator + weight
    end

    if denominator <= 0.0 then
        return math.huge
    end

    return numerator / denominator
end

function CyboquaticMoistureEcosystemModel.integrated_vapor_transport(samples)
    if type(samples) ~= "table" or #samples == 0 then
        error("samples must be a non-empty table")
    end

    local ivt_x_kg_m_s = 0.0
    local ivt_y_kg_m_s = 0.0
    local total_pressure_depth_pa = 0.0

    for index, sample in ipairs(samples) do
        if type(sample) ~= "table" then
            error("sample " .. tostring(index) .. " must be a table")
        end

        local specific_humidity = require_number(
            "specific_humidity_kg_per_kg",
            sample.specific_humidity_kg_per_kg,
            0.0,
            MAX_SPECIFIC_HUMIDITY_KG_PER_KG
        )

        local wind_u_m_per_s = require_number(
            "wind_u_m_per_s",
            sample.wind_u_m_per_s,
            -MAX_WIND_SPEED_M_PER_S,
            MAX_WIND_SPEED_M_PER_S
        )

        local wind_v_m_per_s = require_number(
            "wind_v_m_per_s",
            sample.wind_v_m_per_s,
            -MAX_WIND_SPEED_M_PER_S,
            MAX_WIND_SPEED_M_PER_S
        )

        local pressure_thickness_pa = require_number(
            "pressure_thickness_pa",
            sample.pressure_thickness_pa,
            MIN_PRESSURE_PA,
            nil
        )

        ivt_x_kg_m_s = ivt_x_kg_m_s
            + (specific_humidity * wind_u_m_per_s * pressure_thickness_pa / GRAVITY_M_PER_S2)

        ivt_y_kg_m_s = ivt_y_kg_m_s
            + (specific_humidity * wind_v_m_per_s * pressure_thickness_pa / GRAVITY_M_PER_S2)

        total_pressure_depth_pa = total_pressure_depth_pa + pressure_thickness_pa
    end

    local magnitude_kg_m_s = vector_magnitude(ivt_x_kg_m_s, ivt_y_kg_m_s)
    local direction_degrees = degrees_from_vector(ivt_x_kg_m_s, ivt_y_kg_m_s)

    return {
        ivt_x_kg_m_s = ivt_x_kg_m_s,
        ivt_y_kg_m_s = ivt_y_kg_m_s,
        magnitude_kg_m_s = magnitude_kg_m_s,
        direction_degrees = direction_degrees,
        pressure_depth_pa = total_pressure_depth_pa,
        mean_specific_humidity_kg_per_kg = weighted_mean(
            samples,
            function(sample)
                return sample.specific_humidity_kg_per_kg
            end
        ),
        mean_wind_speed_m_per_s = weighted_mean(
            samples,
            function(sample)
                return vector_magnitude(
                    sample.wind_u_m_per_s,
                    sample.wind_v_m_per_s
                )
            end
        )
    }
end

function CyboquaticMoistureEcosystemModel.classify_moisture_transport(ivt_magnitude_kg_m_s)
    require_number(
        "ivt_magnitude_kg_m_s",
        ivt_magnitude_kg_m_s,
        0.0,
        nil
    )

    if ivt_magnitude_kg_m_s < 250.0 then
        return {
            category = "low",
            interpretation = "Limited large-scale moisture transport. Prioritize conservation, heat-safety readiness, and local water retention.",
            ecological_readiness = "Maintain infiltration, canopy, habitat, and drought-resilience operations."
        }
    end

    if ivt_magnitude_kg_m_s < 500.0 then
        return {
            category = "elevated",
            interpretation = "Elevated moisture transport. Increase observation frequency and prepare capture, runoff-quality, and recharge systems.",
            ecological_readiness = "Inspect basins, bioswales, wetlands, and stormwater treatment corridors."
        }
    end

    return {
        category = "high",
        interpretation = "High moisture transport. Treat as a natural-weather preparedness signal, not evidence of controllable precipitation.",
        ecological_readiness = "Prepare flood-safe capture, managed aquifer recharge, erosion protection, and water-quality monitoring."
    }
end

function CyboquaticMoistureEcosystemModel.water_transport_energy(input)
    if type(input) ~= "table" then
        error("input must be a table")
    end

    local water_density_kg_per_m3 = require_number(
        "water_density_kg_per_m3",
        input.water_density_kg_per_m3 or 997.0,
        950.0,
        1050.0
    )

    local flow_m3_per_s = require_number(
        "flow_m3_per_s",
        input.flow_m3_per_s,
        0.0,
        nil
    )

    local total_dynamic_head_m = require_number(
        "total_dynamic_head_m",
        input.total_dynamic_head_m,
        0.0,
        nil
    )

    local pump_efficiency = require_number(
        "pump_efficiency",
        input.pump_efficiency,
        0.01,
        1.0
    )

    local hours = require_number(
        "hours",
        input.hours,
        0.0,
        nil
    )

    local grid_carbon_intensity_kgco2e_per_kwh = require_number(
        "grid_carbon_intensity_kgco2e_per_kwh",
        input.grid_carbon_intensity_kgco2e_per_kwh,
        0.0,
        MAX_CARBON_INTENSITY_KGCO2E_PER_KWH
    )

    local renewable_fraction = require_number(
        "renewable_fraction",
        input.renewable_fraction or 0.0,
        0.0,
        1.0
    )

    local leakage_fraction = require_number(
        "leakage_fraction",
        input.leakage_fraction or 0.0,
        0.0,
        0.99
    )

    local hydraulic_power_w = water_density_kg_per_m3
        * GRAVITY_M_PER_S2
        * flow_m3_per_s
        * total_dynamic_head_m

    local electric_power_w = hydraulic_power_w / pump_efficiency
    local energy_kwh = electric_power_w * hours / 1000.0
    local sent_volume_m3 = flow_m3_per_s * hours * 3600.0
    local delivered_volume_m3 = sent_volume_m3 * (1.0 - leakage_fraction)
    local nonrenewable_energy_kwh = energy_kwh * (1.0 - renewable_fraction)

    local carbon_kgco2e = nonrenewable_energy_kwh
        * grid_carbon_intensity_kgco2e_per_kwh

    local energy_intensity_kwh_per_m3 = math.huge
    local carbon_intensity_kgco2e_per_m3 = math.huge

    if delivered_volume_m3 > 0.0 then
        energy_intensity_kwh_per_m3 = energy_kwh / delivered_volume_m3
        carbon_intensity_kgco2e_per_m3 = carbon_kgco2e / delivered_volume_m3
    end

    return {
        hydraulic_power_w = hydraulic_power_w,
        electric_power_w = electric_power_w,
        energy_kwh = energy_kwh,
        sent_volume_m3 = sent_volume_m3,
        delivered_volume_m3 = delivered_volume_m3,
        water_delivery_efficiency = delivered_volume_m3 / math.max(sent_volume_m3, 1.0),
        energy_intensity_kwh_per_m3 = energy_intensity_kwh_per_m3,
        carbon_kgco2e = carbon_kgco2e,
        carbon_intensity_kgco2e_per_m3 = carbon_intensity_kgco2e_per_m3
    }
end

function CyboquaticMoistureEcosystemModel.evaluate_ecosystem_readiness(input)
    if type(input) ~= "table" then
        error("input must be a table")
    end

    local ivt_magnitude_kg_m_s = require_number(
        "ivt_magnitude_kg_m_s",
        input.ivt_magnitude_kg_m_s,
        0.0,
        nil
    )

    local soil_moisture_fraction = require_number(
        "soil_moisture_fraction",
        input.soil_moisture_fraction,
        0.0,
        1.0
    )

    local reservoir_free_capacity_m3 = require_number(
        "reservoir_free_capacity_m3",
        input.reservoir_free_capacity_m3,
        0.0,
        nil
    )

    local infiltration_capacity_m3_per_h = require_number(
        "infiltration_capacity_m3_per_h",
        input.infiltration_capacity_m3_per_h,
        0.0,
        nil
    )

    local water_quality_risk = require_number(
        "water_quality_risk",
        input.water_quality_risk,
        0.0,
        1.0
    )

    local heat_risk = require_number(
        "heat_risk",
        input.heat_risk,
        0.0,
        1.0
    )

    local ivt_risk = normalize(ivt_magnitude_kg_m_s, 250.0, 1000.0)
    local saturated_soil_risk = normalize(soil_moisture_fraction, 0.70, 0.98)
    local storage_risk = 1.0 - clamp(reservoir_free_capacity_m3 / 1000000.0, 0.0, 1.0)
    local infiltration_risk = 1.0 - clamp(infiltration_capacity_m3_per_h / 5000.0, 0.0, 1.0)

    local aggregate_risk = clamp(
        0.25 * ivt_risk
            + 0.20 * saturated_soil_risk
            + 0.20 * storage_risk
            + 0.15 * infiltration_risk
            + 0.10 * water_quality_risk
            + 0.10 * heat_risk,
        0.0,
        1.0
    )

    local actions = {}

    if ivt_magnitude_kg_m_s >= 500.0 then
        table.insert(actions, "Activate high-frequency weather, inflow, and water-quality monitoring.")
        table.insert(actions, "Prepare managed aquifer recharge and retention assets only within verified water-quality and flood-safety corridors.")
    else
        table.insert(actions, "Maintain routine monitoring and prioritize local drought resilience, shade, and water-retention measures.")
    end

    if soil_moisture_fraction >= 0.70 then
        table.insert(actions, "Limit infiltration loading until soil saturation, erosion, and water-quality conditions are reviewed.")
    else
        table.insert(actions, "Inspect bioswales, infiltration basins, and restoration soils for safe capacity to retain future runoff.")
    end

    if reservoir_free_capacity_m3 <= 0.0 then
        table.insert(actions, "Do not route additional water to the reservoir until storage safety is restored.")
    end

    if water_quality_risk >= 0.50 then
        table.insert(actions, "Require treatment verification before recharge, habitat release, or any public-facing water use.")
    end

    if heat_risk >= 0.50 then
        table.insert(actions, "Prioritize accessible heat-safety services, shade, cooling access, and non-aerosol water strategies.")
    end

    return {
        aggregate_risk = aggregate_risk,
        ivt_risk = ivt_risk,
        saturated_soil_risk = saturated_soil_risk,
        storage_risk = storage_risk,
        infiltration_risk = infiltration_risk,
        approved_for_automatic_release = false,
        rationale = "This model produces planning recommendations only. It never authorizes weather modification, public water release, or ecological discharge without human, community, and regulatory review.",
        recommended_actions = actions
    }
end

function CyboquaticMoistureEcosystemModel.safe_shortest_path(graph, source_id, destination_id)
    if type(graph) ~= "table" then
        error("graph must be a table")
    end

    if graph[source_id] == nil then
        error("source_id is not present in graph")
    end

    if graph[destination_id] == nil then
        error("destination_id is not present in graph")
    end

    local distance = {}
    local previous = {}
    local visited = {}

    for node_id, _ in pairs(graph) do
        distance[node_id] = math.huge
    end

    distance[source_id] = 0.0

    while true do
        local current_node = nil
        local current_distance = math.huge

        for node_id, candidate_distance in pairs(distance) do
            if not visited[node_id] and candidate_distance < current_distance then
                current_node = node_id
                current_distance = candidate_distance
            end
        end

        if current_node == nil or current_node == destination_id then
            break
        end

        visited[current_node] = true

        for _, edge in ipairs(graph[current_node]) do
            if type(edge) ~= "table" then
                error("every graph edge must be a table")
            end

            local target = edge.to
            local carbon_cost = require_number(
                "edge.carbon_cost",
                edge.carbon_cost,
                0.0,
                nil
            )

            local water_loss_cost = require_number(
                "edge.water_loss_cost",
                edge.water_loss_cost or 0.0,
                0.0,
                nil
            )

            local ecosystem_risk_cost = require_number(
                "edge.ecosystem_risk_cost",
                edge.ecosystem_risk_cost or 0.0,
                0.0,
                nil
            )

            local community_burden_cost = require_number(
                "edge.community_burden_cost",
                edge.community_burden_cost or 0.0,
                0.0,
                nil
            )

            local edge_cost = carbon_cost
                + water_loss_cost
                + ecosystem_risk_cost
                + community_burden_cost

            local candidate_distance = distance[current_node] + edge_cost

            if distance[target] == nil then
                distance[target] = math.huge
                previous[target] = nil
            end

            if candidate_distance < distance[target] then
                distance[target] = candidate_distance
                previous[target] = current_node
            end
        end
    end

    if distance[destination_id] == math.huge then
        return {
            reachable = false,
            total_cost = math.huge,
            route = {},
            rationale = "No approved path exists under the supplied carbon, water-loss, ecosystem-risk, and community-burden costs."
        }
    end

    local route = {}
    local cursor = destination_id

    while cursor ~= nil do
        table.insert(route, 1, cursor)
        cursor = previous[cursor]
    end

    return {
        reachable = true,
        total_cost = distance[destination_id],
        route = route,
        rationale = "The route minimizes the supplied combined impact cost. It is a decision-support result and requires water-rights, ecological-flow, community, and operational review."
    }
end

function CyboquaticMoistureEcosystemModel.example()
    local atmosphere = CyboquaticMoistureEcosystemModel.integrated_vapor_transport({
        {
            specific_humidity_kg_per_kg = 0.010,
            wind_u_m_per_s = 16.0,
            wind_v_m_per_s = 4.0,
            pressure_thickness_pa = 15000.0
        },
        {
            specific_humidity_kg_per_kg = 0.007,
            wind_u_m_per_s = 20.0,
            wind_v_m_per_s = 5.0,
            pressure_thickness_pa = 18000.0
        },
        {
            specific_humidity_kg_per_kg = 0.003,
            wind_u_m_per_s = 25.0,
            wind_v_m_per_s = 7.0,
            pressure_thickness_pa = 12000.0
        }
    })

    local moisture_classification =
        CyboquaticMoistureEcosystemModel.classify_moisture_transport(
            atmosphere.magnitude_kg_m_s
        )

    local transport = CyboquaticMoistureEcosystemModel.water_transport_energy({
        flow_m3_per_s = 0.25,
        total_dynamic_head_m = 95.0,
        pump_efficiency = 0.78,
        hours = 6.0,
        grid_carbon_intensity_kgco2e_per_kwh = 0.35,
        renewable_fraction = 0.70,
        leakage_fraction = 0.02
    })

    local ecosystem = CyboquaticMoistureEcosystemModel.evaluate_ecosystem_readiness({
        ivt_magnitude_kg_m_s = atmosphere.magnitude_kg_m_s,
        soil_moisture_fraction = 0.42,
        reservoir_free_capacity_m3 = 350000.0,
        infiltration_capacity_m3_per_h = 1500.0,
        water_quality_risk = 0.15,
        heat_risk = 0.78
    })

    local graph = {
        source = {
            {
                to = "gravity_storage",
                carbon_cost = 2.0,
                water_loss_cost = 0.2,
                ecosystem_risk_cost = 0.3,
                community_burden_cost = 0.1
            },
            {
                to = "pumped_storage",
                carbon_cost = 5.0,
                water_loss_cost = 0.1,
                ecosystem_risk_cost = 0.2,
                community_burden_cost = 0.1
            }
        },
        gravity_storage = {
            {
                to = "restoration_site",
                carbon_cost = 1.0,
                water_loss_cost = 0.2,
                ecosystem_risk_cost = 0.2,
                community_burden_cost = 0.1
            }
        },
        pumped_storage = {
            {
                to = "restoration_site",
                carbon_cost = 2.5,
                water_loss_cost = 0.1,
                ecosystem_risk_cost = 0.2,
                community_burden_cost = 0.1
            }
        },
        restoration_site = {}
    }

    local route = CyboquaticMoistureEcosystemModel.safe_shortest_path(
        graph,
        "source",
        "restoration_site"
    )

    return {
        atmosphere = atmosphere,
        moisture_classification = moisture_classification,
        transport = transport,
        ecosystem = ecosystem,
        route = route
    }
end

return CyboquaticMoistureEcosystemModel
