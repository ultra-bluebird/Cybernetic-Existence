-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or execution authority.
--
-- Arithmetic over supplied copy-disposition assertions.
-- No deletion, network, file, device, persistence, or cryptographic actions.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"
local MAX_COPIES = 4096

local STATES = {
    deleted_verified = true,
    access_restricted = true,
    scheduled_expiry = true,
    retained_reviewed_basis = true,
    external_unconfirmed = true,
    unknown = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function array_length(value)
    if not plain(value) then return nil end

    local count, maximum = 0, 0
    for key in next, value do
        count = count + 1
        if count > MAX_COPIES
            or type(key) ~= "number"
            or key < 1 or key > MAX_COPIES
            or key % 1 ~= 0 then
            return nil
        end
        maximum = math.max(maximum, key)
    end

    if maximum ~= count then return nil end
    return count
end

local function reference(value)
    return type(value) == "string"
        and #value > 0 and #value <= 128
        and value:match("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

local function invalid(reason)
    return {
        status = "validation_error",
        implementation_version = VERSION,
        reason = reason
    }
end

function M.summarize(copies)
    local n = array_length(copies)
    if n == nil then
        return invalid("bounded_dense_copy_array_required")
    end

    local counts = {}
    for state in pairs(STATES) do counts[state] = 0 end

    for i = 1, n do
        local copy = copies[i]
        if not plain(copy) then
            return invalid("plain_copy_record_required")
        end

        for key in next, copy do
            if key ~= "disposition" and key ~= "basis_reference" then
                return invalid("unknown_copy_field")
            end
        end

        if type(copy.disposition) ~= "string"
            or not STATES[copy.disposition]
            or not reference(copy.basis_reference) then
            return invalid("invalid_copy_record")
        end

        counts[copy.disposition] = counts[copy.disposition] + 1
    end

    local fractions = {}
    for state, count in pairs(counts) do
        if n == 0 then
            fractions[state] = {
                status = "not_assessed",
                reason = "no_known_copy_records"
            }
        else
            fractions[state] = {
                status = "computed",
                numerator = count,
                denominator = n,
                value = count / n
            }
        end
    end

    local residual = n - counts.deleted_verified

    return {
        status = n > 0 and "computed" or "not_assessed",
        implementation_version = VERSION,
        scope = "supplied_known_copy_inventory",
        known_copy_count = n,
        counts = counts,
        fractions = fractions,
        nondeleted_or_unresolved_count = residual,
        evidence_status = {
            inventory_completeness = "not_verified",
            deletion_assertions = "not_verified_by_this_utility",
            retention_authority = "not_verified_by_this_utility",
            external_copy_status = "not_independently_verified"
        }
    }
end

function M.self_test()
    local result = M.summarize({
        {
            disposition = "deleted_verified",
            basis_reference = "synthetic_deletion_check"
        },
        {
            disposition = "scheduled_expiry",
            basis_reference = "synthetic_backup_schedule"
        },
        {
            disposition = "external_unconfirmed",
            basis_reference = "synthetic_recipient_request"
        }
    })

    assert(result.known_copy_count == 3)
    assert(result.counts.deleted_verified == 1)
    assert(result.nondeleted_or_unresolved_count == 2)
    assert(result.fractions.deleted_verified.numerator == 1)
    assert(result.fractions.deleted_verified.denominator == 3)

    local empty = M.summarize({})
    assert(empty.status == "not_assessed")
    assert(empty.fractions.deleted_verified.status == "not_assessed")

    local invalid_state = M.summarize({
        {
            disposition = "everything_erased",
            basis_reference = "synthetic_claim"
        }
    })
    assert(invalid_state.reason == "invalid_copy_record")

    local private_payload = M.summarize({
        {
            disposition = "unknown",
            basis_reference = "synthetic_review",
            private_content = "not accepted"
        }
    })
    assert(private_payload.reason == "unknown_copy_field")

    return {
        status = "self_checks_passed",
        scope = "synthetic_receipt_arithmetic_and_validation"
    }
end

return M
