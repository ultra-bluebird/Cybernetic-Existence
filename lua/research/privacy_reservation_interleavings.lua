-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or execution authority.
--
-- Finite research model: two workers, one request each.
-- No network, file, device, persistence, or actual privacy releases.
-- Not a concurrent store implementation.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"

local EVENTS = {
    {worker = "a", stage = "check"},
    {worker = "a", stage = "finish"},
    {worker = "b", stage = "check"},
    {worker = "b", stage = "finish"}
}

local function precedes(order, worker)
    local checked = false
    for i = 1, #order do
        local event = order[i]
        if event.worker == worker then
            if event.stage == "check" then
                checked = true
            elseif not checked then
                return false
            end
        end
    end
    return true
end

local function simulate(order)
    local budget, cost = 100, 60
    local naive_remaining, naive_spent = budget, 0
    local naive_approved = {}

    local available, reserved, spent = budget, 0, 0
    local accepted = {}

    for i = 1, #order do
        local event = order[i]
        local worker = event.worker

        if event.stage == "check" then
            naive_approved[worker] = naive_remaining >= cost

            accepted[worker] = available >= cost
            if accepted[worker] then
                available = available - cost
                reserved = reserved + cost
            end
        else
            if naive_approved[worker] then
                naive_remaining = naive_remaining - cost
                naive_spent = naive_spent + cost
            end

            if accepted[worker] then
                reserved = reserved - cost
                spent = spent + cost
            end
        end

        assert(available >= 0, "negative available capacity")
        assert(reserved >= 0, "negative reserved capacity")
        assert(spent >= 0, "negative spent capacity")
        assert(available + reserved + spent == budget,
            "reservation conservation failed")
    end

    return {
        naive_spent = naive_spent,
        naive_violation = naive_spent > budget,
        reservation_spent = spent,
        reservation_violation = spent > budget
    }
end

function M.run()
    local used, order, results = {}, {}, {}

    local function visit()
        if #order == #EVENTS then
            if precedes(order, "a") and precedes(order, "b") then
                results[#results + 1] = simulate(order)
            end
            return
        end

        for i = 1, #EVENTS do
            if not used[i] then
                used[i] = true
                order[#order + 1] = EVENTS[i]
                visit()
                order[#order] = nil
                used[i] = nil
            end
        end
    end

    visit()

    local naive_failures, reservation_failures = 0, 0
    for i = 1, #results do
        if results[i].naive_violation then
            naive_failures = naive_failures + 1
        end
        if results[i].reservation_violation then
            reservation_failures = reservation_failures + 1
        end
    end

    return {
        implementation_version = VERSION,
        scope = "two_worker_finite_interleaving_model",
        interleavings = #results,
        naive_violations = naive_failures,
        reservation_violations = reservation_failures,
        results = results
    }
end

function M.self_test()
    local report = M.run()
    assert(report.interleavings == 6)
    assert(report.naive_violations == 4)
    assert(report.reservation_violations == 0)

    return {
        status = "self_checks_passed",
        scope = report.scope
    }
end

return M
