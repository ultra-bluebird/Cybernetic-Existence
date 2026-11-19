local corridor_negotiation = require("corridor_negotiation")

local verification = {}

local ActorKind = corridor_negotiation.ActorKind
local Decision = corridor_negotiation.Decision

local CLEAR_WIDTHS_MILLIMETERS = {
    700,
    900,
    1000,
    1200,
    1400,
}

local REQUIRED_WIDTHS_MILLIMETERS = {
    600,
    700,
    900,
    1000,
}

local BATTERY_STATES = {
    nil,
    0.05,
    0.20,
    0.50,
    0.80,
}

local PROTECTED_ACTOR_KINDS = {
    ActorKind.PEDESTRIAN,
    ActorKind.MOBILITY_DEVICE_USER,
    ActorKind.EMERGENCY_RESPONDER,
}

local function assert_condition(condition, message)
    if not condition then
        error(message, 2)
    end
end

local function actor(
    actor_id,
    kind,
    arrival_sequence,
    required_clear_width_millimeters,
    battery_state_of_charge,
    planning_category
)
    local value = {
        actor_id = actor_id,
        kind = kind,
        arrival_sequence = arrival_sequence,
        required_clear_width_millimeters = required_clear_width_millimeters,
    }

    if battery_state_of_charge ~= nil then
        value.battery_state_of_charge = battery_state_of_charge
    end

    if planning_category ~= nil then
        value.self_declared_planning_category = planning_category
    end

    return value
end

local function verify_totality()
    for _, corridor_width in ipairs(CLEAR_WIDTHS_MILLIMETERS) do
        for _, required_width in ipairs(REQUIRED_WIDTHS_MILLIMETERS) do
            local result = corridor_negotiation.negotiate({
                corridor_clear_width_millimeters = corridor_width,
                actors = {
                    actor(
                        "pedestrian",
                        ActorKind.PEDESTRIAN,
                        1,
                        required_width,
                        nil,
                        "community corridor user"
                    ),
                },
            })

            assert_condition(
                result.decision == Decision.GRANT_PASSAGE
                    or result.decision == Decision.HOLD_AT_YIELD_ZONE
                    or result.decision == Decision.ESCORTED_PASSAGE_REQUIRED
                    or result.decision == Decision.UNSAFE_CONFIGURATION,
                "validated state produced an unknown decision"
            )

            assert_condition(
                result.explanation ~= nil and result.explanation ~= "",
                "validated state did not produce an explanation"
            )
        end
    end
end

local function verify_pedestrian_first_precedence()
    for _, protected_kind in ipairs(PROTECTED_ACTOR_KINDS) do
        for _, corridor_width in ipairs(CLEAR_WIDTHS_MILLIMETERS) do
            for _, protected_width in ipairs(REQUIRED_WIDTHS_MILLIMETERS) do
                for _, bot_battery_state in ipairs(BATTERY_STATES) do
                    local result = corridor_negotiation.negotiate({
                        corridor_clear_width_millimeters = corridor_width,
                        actors = {
                            actor(
                                "protected-actor",
                                protected_kind,
                                2,
                                protected_width,
                                nil,
                                "self-asserted access participant"
                            ),
                            actor(
                                "delivery-bot",
                                ActorKind.DELIVERY_BOT,
                                1,
                                600,
                                bot_battery_state,
                                nil
                            ),
                        },
                    })

                    if protected_width <= corridor_width then
                        assert_condition(
                            result.granted_actor_id ~= "delivery-bot",
                            "delivery bot was granted passage while a protected actor was present"
                        )
                    end
                end
            end
        end
    end
end

local function verify_no_forced_passage()
    for _, corridor_width in ipairs(CLEAR_WIDTHS_MILLIMETERS) do
        for _, required_width in ipairs(REQUIRED_WIDTHS_MILLIMETERS) do
            if required_width > corridor_width then
                local result = corridor_negotiation.negotiate({
                    corridor_clear_width_millimeters = corridor_width,
                    actors = {
                        actor(
                            "higher-priority-actor",
                            ActorKind.MOBILITY_DEVICE_USER,
                            1,
                            required_width,
                            0.20,
                            "cybernetic host"
                        ),
                    },
                })

                assert_condition(
                    result.decision == Decision.UNSAFE_CONFIGURATION,
                    "insufficient corridor width did not produce unsafe_configuration"
                )

                assert_condition(
                    result.granted_actor_id == nil,
                    "insufficient corridor width produced a passage grant"
                )
            end
        end
    end
end

local function verify_category_non_discrimination()
    local categories = {
        "cybernetic host",
        "mobility-device user",
        "assistive technology user",
        "community corridor user",
    }

    for _, corridor_width in ipairs(CLEAR_WIDTHS_MILLIMETERS) do
        for _, battery_state in ipairs(BATTERY_STATES) do
            local expected_decision = nil
            local expected_priority_class = nil

            for _, category in ipairs(categories) do
                local result = corridor_negotiation.negotiate({
                    corridor_clear_width_millimeters = corridor_width,
                    actors = {
                        actor(
                            "access-actor",
                            ActorKind.MOBILITY_DEVICE_USER,
                            1,
                            900,
                            battery_state,
                            category
                        ),
                        actor(
                            "delivery-bot",
                            ActorKind.DELIVERY_BOT,
                            2,
                            600,
                            0.01,
                            nil
                        ),
                    },
                })

                if expected_decision == nil then
                    expected_decision = result.decision
                    expected_priority_class = result.priority_token
                        and result.priority_token.priority_class
                        or nil
                else
                    assert_condition(
                        result.decision == expected_decision,
                        "self-declared category changed the decision"
                    )

                    local current_priority_class = result.priority_token
                        and result.priority_token.priority_class
                        or nil

                    assert_condition(
                        current_priority_class == expected_priority_class,
                        "self-declared category changed the priority class"
                    )
                end
            end
        end
    end
end

local function verify_missing_battery_non_penalty()
    for _, corridor_width in ipairs(CLEAR_WIDTHS_MILLIMETERS) do
        local result = corridor_negotiation.negotiate({
            corridor_clear_width_millimeters = corridor_width,
            actors = {
                actor(
                    "mobility-actor-without-battery",
                    ActorKind.MOBILITY_DEVICE_USER,
                    2,
                    900,
                    nil,
                    "self-asserted access participant"
                ),
                actor(
                    "low-battery-delivery-bot",
                    ActorKind.DELIVERY_BOT,
                    1,
                    600,
                    0.01,
                    nil
                ),
            },
        })

        if corridor_width >= 900 then
            assert_condition(
                result.granted_actor_id == "mobility-actor-without-battery",
                "absence of optional battery data reduced mobility access precedence"
            )
        end
    end
end

function verification.run()
    verify_totality()
    verify_pedestrian_first_precedence()
    verify_no_forced_passage()
    verify_category_non_discrimination()
    verify_missing_battery_non_penalty()

    return {
        status = "passed",
        verified_invariants = {
            "totality",
            "pedestrian_first_precedence",
            "no_forced_passage",
            "category_non_discrimination",
            "missing_optional_battery_non_penalty",
        },
        model_bounds = {
            corridor_clear_widths_millimeters = CLEAR_WIDTHS_MILLIMETERS,
            required_clear_widths_millimeters = REQUIRED_WIDTHS_MILLIMETERS,
            battery_states = {
                "absent",
                0.05,
                0.20,
                0.50,
                0.80,
            },
        },
    }
end

return verification
