local corridor_negotiation = require("corridor_negotiation")

local properties = {}

local function assert_equal(left, right, message)
    if left ~= right then
        error(message .. ": expected " .. tostring(right) .. ", found " .. tostring(left))
    end
end

local function run_pedestrian_precedence_property()
    local actor_kinds = {
        corridor_negotiation.ActorKind.PEDESTRIAN,
        corridor_negotiation.ActorKind.MOBILITY_DEVICE_USER,
    }

    for _, protected_actor_kind in ipairs(actor_kinds) do
        for battery_basis_points = 0, 10000, 1000 do
            local outcome = corridor_negotiation.negotiate({
                corridor_clear_width_millimeters = 1400,
                actors = {
                    {
                        actor_id = "protected-actor",
                        kind = protected_actor_kind,
                        arrival_sequence = 2,
                        required_clear_width_millimeters = 900,
                        battery_state_of_charge = battery_basis_points / 10000,
                    },
                    {
                        actor_id = "delivery-bot",
                        kind = corridor_negotiation.ActorKind.DELIVERY_BOT,
                        arrival_sequence = 1,
                        required_clear_width_millimeters = 600,
                        battery_state_of_charge = 0,
                    },
                },
            })

            assert_equal(
                outcome.granted_actor_id,
                "protected-actor",
                "delivery bot received passage ahead of a protected corridor user"
            )
        end
    end
end

local function run_identity_label_invariance_property()
    local base_actor = {
        arrival_sequence = 1,
        required_clear_width_millimeters = 900,
        battery_state_of_charge = 0.25,
        declared_access_urgency_basis_points = 4000,
    }

    local outcomes = {}

    for _, label in ipairs({
        "cybernetic host",
        "mobility-device user",
        "self-described access participant",
        "community corridor user",
    }) do
        local outcome = corridor_negotiation.negotiate({
            corridor_clear_width_millimeters = 1400,
            actors = {
                {
                    actor_id = "actor-" .. label,
                    kind = corridor_negotiation.ActorKind.MOBILITY_DEVICE_USER,
                    arrival_sequence = base_actor.arrival_sequence,
                    required_clear_width_millimeters =
                        base_actor.required_clear_width_millimeters,
                    battery_state_of_charge = base_actor.battery_state_of_charge,
                    declared_access_urgency_basis_points =
                        base_actor.declared_access_urgency_basis_points,
                    self_declared_planning_category = label,
                },
                {
                    actor_id = "delivery-bot",
                    kind = corridor_negotiation.ActorKind.DELIVERY_BOT,
                    arrival_sequence = 2,
                    required_clear_width_millimeters = 600,
                },
            },
        })

        table.insert(outcomes, outcome.decision)
    end

    for index = 2, #outcomes do
        assert_equal(
            outcomes[index],
            outcomes[1],
            "identity label changed the corridor decision"
        )
    end
end

local function run_missing_urgency_non_penalty_property()
    local outcome = corridor_negotiation.negotiate({
        corridor_clear_width_millimeters = 1400,
        actors = {
            {
                actor_id = "mobility-user-without-battery-data",
                kind = corridor_negotiation.ActorKind.MOBILITY_DEVICE_USER,
                arrival_sequence = 2,
                required_clear_width_millimeters = 900,
            },
            {
                actor_id = "delivery-bot-with-low-battery",
                kind = corridor_negotiation.ActorKind.DELIVERY_BOT,
                arrival_sequence = 1,
                required_clear_width_millimeters = 600,
                battery_state_of_charge = 0.01,
            },
        },
    })

    assert_equal(
        outcome.granted_actor_id,
        "mobility-user-without-battery-data",
        "missing optional urgency data reduced mobility access priority"
    )
end

function properties.run()
    run_pedestrian_precedence_property()
    run_identity_label_invariance_property()
    run_missing_urgency_non_penalty_property()

    return {
        status = "passed",
        properties = {
            "pedestrian_precedence",
            "identity_label_invariance",
            "missing_urgency_non_penalty",
        },
    }
end

return properties
