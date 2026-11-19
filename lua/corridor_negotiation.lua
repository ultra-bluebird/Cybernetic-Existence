local corridor_negotiation = {}

local UINT32_MODULUS = 4294967296
local UINT32_MULTIPLIER = 1664525
local UINT32_INCREMENT = 1013904223

local ActorKind = {
    PEDESTRIAN = "pedestrian",
    MOBILITY_DEVICE_USER = "mobility_device_user",
    DELIVERY_BOT = "delivery_bot",
    EMERGENCY_RESPONDER = "emergency_responder",
}

local Decision = {
    GRANT_PASSAGE = "grant_passage",
    HOLD_AT_YIELD_ZONE = "hold_at_yield_zone",
    ESCORTED_PASSAGE_REQUIRED = "escorted_passage_required",
    UNSAFE_CONFIGURATION = "unsafe_configuration",
}

local function is_non_empty_string(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

local function is_non_negative_integer(value)
    return type(value) == "number" and value >= 0 and value % 1 == 0
end

local function is_unit_interval(value)
    return type(value) == "number" and value >= 0 and value <= 1
end

local function require_condition(condition, message)
    if not condition then
        error(message, 3)
    end
end

local function clamp_unit_interval(value)
    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function deterministic_next(seed)
    require_condition(
        is_non_negative_integer(seed) and seed < UINT32_MODULUS,
        "seed must be an unsigned 32-bit integer"
    )

    return (seed * UINT32_MULTIPLIER + UINT32_INCREMENT) % UINT32_MODULUS
end

local function deterministic_unit_random(seed)
    local next_seed = deterministic_next(seed)
    return next_seed, next_seed / UINT32_MODULUS
end

local function actor_priority_class(actor)
    if actor.kind == ActorKind.EMERGENCY_RESPONDER then
        return 5
    end

    if actor.kind == ActorKind.MOBILITY_DEVICE_USER then
        return 4
    end

    if actor.kind == ActorKind.PEDESTRIAN then
        return 3
    end

    if actor.kind == ActorKind.DELIVERY_BOT then
        return 2
    end

    return 1
end

local function continuity_urgency_basis_points(actor)
    local battery_urgency = 0

    if actor.battery_state_of_charge ~= nil then
        battery_urgency = math.floor(
            (1 - clamp_unit_interval(actor.battery_state_of_charge)) * 10000
        )
    end

    local thermal_urgency = actor.thermal_refuge_urgency_basis_points or 0
    local connectivity_urgency = actor.connectivity_urgency_basis_points or 0
    local declared_access_urgency = actor.declared_access_urgency_basis_points or 0

    return math.max(
        battery_urgency,
        thermal_urgency,
        connectivity_urgency,
        declared_access_urgency
    )
end

local function validate_actor(actor)
    require_condition(type(actor) == "table", "actor must be a table")
    require_condition(is_non_empty_string(actor.actor_id), "actor_id is required")
    require_condition(is_non_empty_string(actor.kind), "actor kind is required")
    require_condition(
        actor.kind == ActorKind.PEDESTRIAN
            or actor.kind == ActorKind.MOBILITY_DEVICE_USER
            or actor.kind == ActorKind.DELIVERY_BOT
            or actor.kind == ActorKind.EMERGENCY_RESPONDER,
        "actor kind is unsupported"
    )
    require_condition(
        is_non_negative_integer(actor.arrival_sequence),
        "arrival_sequence must be a non-negative integer"
    )
    require_condition(
        is_non_negative_integer(actor.required_clear_width_millimeters),
        "required_clear_width_millimeters must be a non-negative integer"
    )

    if actor.battery_state_of_charge ~= nil then
        require_condition(
            is_unit_interval(actor.battery_state_of_charge),
            "battery_state_of_charge must be within [0, 1]"
        )
    end

    for _, field_name in ipairs({
        "thermal_refuge_urgency_basis_points",
        "connectivity_urgency_basis_points",
        "declared_access_urgency_basis_points",
    }) do
        if actor[field_name] ~= nil then
            require_condition(
                is_non_negative_integer(actor[field_name])
                    and actor[field_name] <= 10000,
                field_name .. " must be an integer within [0, 10000]"
            )
        end
    end
end

local function compare_actors(left, right)
    local left_priority_class = actor_priority_class(left)
    local right_priority_class = actor_priority_class(right)

    if left_priority_class ~= right_priority_class then
        return left_priority_class > right_priority_class
    end

    local left_urgency = continuity_urgency_basis_points(left)
    local right_urgency = continuity_urgency_basis_points(right)

    if left_urgency ~= right_urgency then
        return left_urgency > right_urgency
    end

    if left.arrival_sequence ~= right.arrival_sequence then
        return left.arrival_sequence < right.arrival_sequence
    end

    return left.actor_id < right.actor_id
end

local function has_pedestrian_or_mobility_actor(actors)
    for _, actor in ipairs(actors) do
        if actor.kind == ActorKind.PEDESTRIAN
            or actor.kind == ActorKind.MOBILITY_DEVICE_USER
            or actor.kind == ActorKind.EMERGENCY_RESPONDER then
            return true
        end
    end

    return false
end

function corridor_negotiation.negotiate(request)
    require_condition(type(request) == "table", "request must be a table")
    require_condition(
        is_non_negative_integer(request.corridor_clear_width_millimeters),
        "corridor_clear_width_millimeters must be a non-negative integer"
    )
    require_condition(type(request.actors) == "table", "actors must be a table")
    require_condition(#request.actors > 0, "at least one actor is required")

    local actors = {}

    for index, actor in ipairs(request.actors) do
        validate_actor(actor)
        actors[index] = actor
    end

    table.sort(actors, compare_actors)

    local highest_priority_actor = actors[1]

    if highest_priority_actor.required_clear_width_millimeters
        > request.corridor_clear_width_millimeters then
        return {
            decision = Decision.UNSAFE_CONFIGURATION,
            granted_actor_id = nil,
            held_actor_ids = {},
            priority_token = nil,
            explanation =
                "No actor is granted passage because the highest-priority actor requires more clear width than the corridor provides. The corridor requires an accessible alternate route, human assistance path, or physical redesign.",
        }
    end

    local bots_must_yield = has_pedestrian_or_mobility_actor(actors)
    local held_actor_ids = {}

    for _, actor in ipairs(actors) do
        if actor.actor_id ~= highest_priority_actor.actor_id then
            table.insert(held_actor_ids, actor.actor_id)
        end
    end

    local decision = Decision.GRANT_PASSAGE

    if highest_priority_actor.kind == ActorKind.DELIVERY_BOT and bots_must_yield then
        decision = Decision.HOLD_AT_YIELD_ZONE
    end

    if highest_priority_actor.kind == ActorKind.DELIVERY_BOT
        and not bots_must_yield
        and request.delivery_bot_requires_supervision then
        decision = Decision.ESCORTED_PASSAGE_REQUIRED
    end

    return {
        decision = decision,
        granted_actor_id = highest_priority_actor.actor_id,
        held_actor_ids = held_actor_ids,
        priority_token = {
            actor_id = highest_priority_actor.actor_id,
            actor_kind = highest_priority_actor.kind,
            priority_class = actor_priority_class(highest_priority_actor),
            continuity_urgency_basis_points =
                continuity_urgency_basis_points(highest_priority_actor),
            arrival_sequence = highest_priority_actor.arrival_sequence,
        },
        explanation =
            "Priority is determined first by physical safety and mobility access, then by declared continuity urgency, then by arrival sequence, and finally by stable actor identifier. Delivery bots always yield to pedestrians, mobility-device users, and emergency responders.",
    }
end

function corridor_negotiation.run_monte_carlo(config)
    require_condition(type(config) == "table", "config must be a table")
    require_condition(
        is_non_negative_integer(config.seed) and config.seed < UINT32_MODULUS,
        "seed must be an unsigned 32-bit integer"
    )
    require_condition(
        is_non_negative_integer(config.trials) and config.trials > 0,
        "trials must be a positive integer"
    )
    require_condition(
        is_non_negative_integer(config.corridor_clear_width_millimeters),
        "corridor_clear_width_millimeters must be a non-negative integer"
    )

    local seed = config.seed
    local pedestrian_priority_grants = 0
    local mobility_priority_grants = 0
    local delivery_bot_priority_grants = 0
    local unsafe_configuration_count = 0
    local bot_yield_count = 0

    for trial = 1, config.trials do
        local random_value
        seed, random_value = deterministic_unit_random(seed)

        local mobility_actor_present = random_value < config.mobility_actor_arrival_probability

        seed, random_value = deterministic_unit_random(seed)
        local delivery_bot_present =
            random_value < config.delivery_bot_arrival_probability

        local actors = {
            {
                actor_id = "pedestrian-" .. tostring(trial),
                kind = ActorKind.PEDESTRIAN,
                arrival_sequence = trial * 10,
                required_clear_width_millimeters = 700,
            },
        }

        if mobility_actor_present then
            seed, random_value = deterministic_unit_random(seed)

            table.insert(actors, {
                actor_id = "mobility-" .. tostring(trial),
                kind = ActorKind.MOBILITY_DEVICE_USER,
                arrival_sequence = trial * 10 + 1,
                required_clear_width_millimeters = 950,
                battery_state_of_charge = random_value,
                declared_access_urgency_basis_points = 2500,
            })
        end

        if delivery_bot_present then
            table.insert(actors, {
                actor_id = "bot-" .. tostring(trial),
                kind = ActorKind.DELIVERY_BOT,
                arrival_sequence = trial * 10 + 2,
                required_clear_width_millimeters = 600,
                battery_state_of_charge = 0.50,
            })
        end

        local outcome = corridor_negotiation.negotiate({
            corridor_clear_width_millimeters =
                config.corridor_clear_width_millimeters,
            actors = actors,
            delivery_bot_requires_supervision =
                config.delivery_bot_requires_supervision or false,
        })

        if outcome.decision == Decision.UNSAFE_CONFIGURATION then
            unsafe_configuration_count = unsafe_configuration_count + 1
        elseif outcome.priority_token.actor_kind == ActorKind.MOBILITY_DEVICE_USER then
            mobility_priority_grants = mobility_priority_grants + 1
        elseif outcome.priority_token.actor_kind == ActorKind.PEDESTRIAN then
            pedestrian_priority_grants = pedestrian_priority_grants + 1
        elseif outcome.priority_token.actor_kind == ActorKind.DELIVERY_BOT then
            delivery_bot_priority_grants = delivery_bot_priority_grants + 1
        end

        if delivery_bot_present and outcome.granted_actor_id ~= ("bot-" .. tostring(trial)) then
            bot_yield_count = bot_yield_count + 1
        end
    end

    return {
        seed = config.seed,
        trials = config.trials,
        pedestrian_priority_grants = pedestrian_priority_grants,
        mobility_priority_grants = mobility_priority_grants,
        delivery_bot_priority_grants = delivery_bot_priority_grants,
        unsafe_configuration_count = unsafe_configuration_count,
        delivery_bot_yield_count = bot_yield_count,
        delivery_bot_yield_ratio = bot_yield_count / config.trials,
    }
end

corridor_negotiation.ActorKind = ActorKind
corridor_negotiation.Decision = Decision

return corridor_negotiation
