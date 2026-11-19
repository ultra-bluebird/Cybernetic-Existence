-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only.
-- No verified identity, consent, capability, or execution authority.
--
-- Interface-review artifact, not a governance engine.
-- No network, file, device, cryptographic, or persistence operations.
-- Lua 5.1+.

local M = {}

local SEMANTICS = {
    version = "0.2.1-proposed",
    status = "review_required",

    dependency_matching = "exact_version_equality",
    compatibility_target = "assume_guarantee_observable_refinement",

    migration = {
        missing_action_authorization = "unknown",
        unresolved_to_established = "forbidden",
        confirmation_from_label_only = "forbidden",
        breaking_schema_change = "explicit_migration_required"
    },

    boundaries = {
        external = {
            entry = "decode_and_validate",
            shape_failure = "validation_error"
        },
        internal = {
            entry = "evaluate_validated_record",
            invariant_failure = "programmer_error"
        },
        dependency = {
            entry = "obtain_dependency",
            unavailable = "dependency_unavailable"
        }
    },

    effect_support = {
        representation = "positive_negative_support_pair",
        states = {
            neither = {positive = false, negative = false},
            positive_only = {positive = true, negative = false},
            negative_only = {positive = false, negative = true},
            conflicting = {positive = true, negative = true}
        },
        evidence_quality_is_separate = true,
        closure_fragment = "finite_ground_positive_implications",
        contraposition = "not_permitted",
        contradiction_erases_positive_support = "not_permitted"
    },

    selection_modes = {
        any_verified_optimum = {
            selected_portfolio_required = true,
            selection_mechanism_required = true
        },
        deterministic_approved_tiebreak = {
            policy_version_required = true,
            canonicalization_required = true
        }
    },

    consumer = {
        execution = {"refused", "awaiting_authorization"},
        obligation = {
            "existing_obligation_retained",
            "escalation_recorded",
            "escalation_pending"
        },
        dependency = {"available", "unavailable", "unresolved"}
    },

    obligation = {
        breach_memory_scope = "retained_obligation_lifetime",
        reopen_sets_unresolved = true,
        supported_resolution_clears_unresolved = true,
        archive_erases_breach = false,
        deletion_policy = "separately_authorized_records_governance"
    },

    certificate_policy = {
        explicit_finite_portfolios = "complete_recomputation",
        integer_model = "approved_proof_format_and_checker",
        continuous_or_mixed_integer = "separate_approved_policy",
        unsupported = "no_verified_optimal_claim"
    },

    assurance = {
        implementation = "separate_attribute",
        execution = "separate_attribute",
        reviewer_independence = "separate_attribute",
        operational_observation = "separate_attribute",
        scope = "required"
    }
}

local function clone(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, item in next, value do
        result[key] = clone(item)
    end
    return result
end

local function text(value)
    return type(value) == "string"
        and #value > 0
        and #value <= 128
        and value:match("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

function M.snapshot()
    return clone(SEMANTICS)
end

function M.review_migration_declaration(record)
    if type(record) ~= "table"
        or getmetatable(record) ~= nil then
        return {
            status = "validation_error",
            reason = "plain_record_required"
        }
    end

    local allowed = {
        source_version = true,
        target_version = true,
        migration_reference = true,
        missing_authorization_rule = true,
        unresolved_state_rule = true,
        evidence_reference = true
    }

    for key in next, record do
        if not allowed[key] then
            return {
                status = "validation_error",
                reason = "unknown_field"
            }
        end
    end

    for _, field in ipairs({
        "source_version",
        "target_version",
        "migration_reference",
        "evidence_reference"
    }) do
        if not text(record[field]) then
            return {
                status = "validation_error",
                reason = "missing_or_invalid_reference"
            }
        end
    end

    if record.missing_authorization_rule ~= "unknown" then
        return {
            status = "declaration_rejected",
            reason = "missing_authorization_must_remain_unknown"
        }
    end

    if record.unresolved_state_rule ~= "preserve_unresolved" then
        return {
            status = "declaration_rejected",
            reason = "unresolved_state_must_not_be_promoted"
        }
    end

    return {
        status = "declaration_ready_for_behavioral_review",
        source_version = record.source_version,
        target_version = record.target_version,
        migration_reference = record.migration_reference,
        evidence_reference = record.evidence_reference
    }
end

return M
