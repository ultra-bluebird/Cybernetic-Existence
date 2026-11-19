local corridor_negotiation = require("corridor_negotiation")

local result = corridor_negotiation.negotiate({
    corridor_clear_width_millimeters = 1200,
    actors = {
        {
            actor_id = "delivery-bot-a",
            kind = corridor_negotiation.ActorKind.DELIVERY_BOT,
            arrival_sequence = 1,
            required_clear_width_millimeters = 600,
            battery_state_of_charge = 0.10,
        },
        {
            actor_id = "mobility-user-a",
            kind = corridor_negotiation.ActorKind.MOBILITY_DEVICE_USER,
            arrival_sequence = 2,
            required_clear_width_millimeters = 950,
            battery_state_of_charge = 0.08,
            declared_access_urgency_basis_points = 2500,
        },
    },
})

assert(result.decision == corridor_negotiation.Decision.GRANT_PASSAGE)
assert(result.granted_actor_id == "mobility-user-a")
assert(result.priority_token.actor_kind == corridor_negotiation.ActorKind.MOBILITY_DEVICE_USER)

local unsafe_result = corridor_negotiation.negotiate({
    corridor_clear_width_millimeters = 800,
    actors = {
        {
            actor_id = "mobility-user-wide-device",
            kind = corridor_negotiation.ActorKind.MOBILITY_DEVICE_USER,
            arrival_sequence = 1,
            required_clear_width_millimeters = 950,
        },
    },
})

assert(unsafe_result.decision == corridor_negotiation.Decision.UNSAFE_CONFIGURATION)

local simulation = corridor_negotiation.run_monte_carlo({
    seed = 7291,
    trials = 1000,
    corridor_clear_width_millimeters = 1200,
    mobility_actor_arrival_probability = 0.40,
    delivery_bot_arrival_probability = 0.65,
})

assert(simulation.trials == 1000)
assert(simulation.delivery_bot_yield_count > 0)
assert(simulation.mobility_priority_grants > 0)
