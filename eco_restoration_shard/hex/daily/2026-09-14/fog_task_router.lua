local allowed_media = {
    known_safe = true,
    unmodeled_media = true,
    pfas_suspected = true,
    hazardous_material = true,
    unknown = true
}

local function split_csv(line)
    local fields = {}
    for value in string.gmatch(line .. ",", "(.-),") do
        table.insert(fields, value)
    end
    return fields
end

local function unit_interval(value)
    return value ~= nil and value >= 0.0 and value <= 1.0
end

local function number_or_nil(value)
    local parsed = tonumber(value)
    if parsed == nil or parsed ~= parsed or parsed == math.huge or parsed == -math.huge then
        return nil
    end
    return parsed
end

local function route(media_class, knowledge_factor, eco_impact_value, harm_risk)
    if not allowed_media[media_class] then
        return "reject", "unsupported media_class"
    end

    if not unit_interval(knowledge_factor)
        or not unit_interval(eco_impact_value)
        or not unit_interval(harm_risk) then
        return "reject", "invalid KER values"
    end

    if media_class == "hazardous_material" then
        return "reject", "physical dispatch prohibited for hazardous material"
    end

    if media_class ~= "known_safe" then
        return "manual_review", "FOG media requires operator review"
    end

    if knowledge_factor < 0.75 then
        return "manual_review", "knowledge factor below threshold"
    end

    if eco_impact_value < 0.55 then
        return "manual_review", "eco impact value below threshold"
    end

    if harm_risk > 0.30 then
        return "manual_review", "harm risk exceeds automatic-admission threshold"
    end

    return "eligible_for_operator_approval", "known safe media and KER thresholds satisfied"
end

io.write("workload_id,media_class,knowledge_factor,eco_impact_value,harm_risk,route,reason\n")

local first_line = true
for line in io.lines() do
    if first_line then
        first_line = false
    elseif line ~= "" then
        local fields = split_csv(line)

        if #fields ~= 5 then
            io.write(",,,,,reject,expected 5 CSV columns\n")
        else
            local workload_id = fields[1]
            local media_class = fields[2]
            local knowledge_factor = number_or_nil(fields[3])
            local eco_impact_value = number_or_nil(fields[4])
            local harm_risk = number_or_nil(fields[5])

            local route_name, reason = route(
                media_class,
                knowledge_factor,
                eco_impact_value,
                harm_risk
            )

            io.write(string.format(
                "%s,%s,%s,%s,%s,%s,%s\n",
                workload_id,
                media_class,
                fields[3],
                fields[4],
                fields[5],
                route_name,
                reason
            ))
        end
    end
end
