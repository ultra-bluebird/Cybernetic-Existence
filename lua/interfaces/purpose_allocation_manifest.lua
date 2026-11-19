-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only.
-- No identity, consent, authorization, or execution authority.
--
-- Interface manifest only. No decision kernel or solver.
-- No network, file, device, cryptographic, or persistence operations.
-- Lua 5.1+.

local M = {}

local PINS = {
    ["config/governance/purpose-and-allocation-contract.yaml"] = "0.1.0",
    ["docs/governance/disclosure-checkpoint-contract.md"] = "0.1.0",
    ["docs/governance/disclosure-selection-contract.md"] = "0.1.0",
    ["config/governance/change-and-remedy-contract.yaml"] = "0.1.0",
    ["docs/research/reconstruction-study-protocol.md"] = "0.1.0"
}

local MANIFEST = {
    interface_version = "0.2.0",
    specification_path =
        "docs/interfaces/purpose-allocation-interface.md",
    review_status = "proposed_interface_review",
    architecture = "isolated_orchestrator_target_not_implemented",

    enums = {
        effect_valuation = {
            "confirmed", "disconfirmed", "unresolved"
        },
        evidence_status = {
            "sufficient", "insufficient", "disputed"
        },
        firewall_route = {
            "prohibited_operation",
            "assessment_review_required",
            "no_declared_prohibition_confirmed",
            "validation_error",
            "dependency_unavailable"
        },
        allocation_status = {
            "optimal",
            "feasible",
            "infeasible",
            "unknown",
            "model_invalid",
            "policy_review_required",
            "soft_relaxed_violating"
        },
        obligation_status = {
            "open", "escalated", "repair_pending", "resolved"
        },
        assessment_status = {
            "not_scored",
            "scored",
            "not_applicable",
            "assessment_conflicted"
        },
        consumer_route = {
            "refused_for_execution",
            "escalation_recorded",
            "requires_implementation_authorization"
        }
    },

    methods = {
        firewall = {
            required_input = {
                "schema_version",
                "operation_label",
                "assessment_scope",
                "taxonomy_version",
                "evidence_standard",
                "assessment_reference",
                "effect_assessments"
            },
            required_output = {
                "schema_version",
                "route",
                "assessment_reference",
                "findings_reference"
            }
        },

        allocate = {
            required_input = {
                "schema_version",
                "model_version",
                "rights_assessment_reference",
                "authorization_reference",
                "checkpoint_reference",
                "resource_unit",
                "energy_unit",
                "planning_horizon",
                "budget",
                "portfolios",
                "numeric_policy"
            },
            common_output = {
                "schema_version",
                "model_version",
                "status",
                "termination_reason",
                "evidence_reference"
            }
        },

        consume_result = {
            required_input = {
                "allocation_result_reference",
                "original_obligation_reference",
                "review_context"
            },
            required_output = {
                "route",
                "obligation_reference",
                "decision_evidence_reference"
            }
        }
    },

    obligation_required = {
        "case_reference",
        "obligation_reference",
        "original_intake_time",
        "original_deadline",
        "owner",
        "accessible_contact_route",
        "status",
        "escalation_count",
        "ever_breached",
        "currently_unresolved",
        "event_references",
        "continuity_reference"
    },

    assessment_fields = {
        knowledge_factor = "higher_favorable",
        eco_impact_value = "higher_favorable",
        harm_risk = "lower_favorable",
        accessibility_impact = "higher_favorable",
        rights_alignment = "higher_favorable"
    },

    numeric_policy = {
        model_class = "finite_portfolios",
        representation = "bounded_nonnegative_integer",
        optimality_claim = "exact",
        absolute_gap = 0,
        relative_gap = 0,
        returned_optima = "one_arbitrary_verified_optimum"
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

local function valid_text(value, maximum)
    return type(value) == "string"
        and #value > 0
        and #value <= maximum
        and value:match("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

function M.snapshot()
    local result = clone(MANIFEST)
    result.dependencies = clone(PINS)
    return result
end

function M.check_declared_versions(declared)
    if type(declared) ~= "table"
        or getmetatable(declared) ~= nil then
        return {
            status = "validation_error",
            reason = "plain_dependency_map_required"
        }
    end

    local count = 0
    for path, version in next, declared do
        count = count + 1

        if count > 32
            or not valid_text(path, 256)
            or not valid_text(version, 64) then
            return {
                status = "validation_error",
                reason = "invalid_dependency_entry"
            }
        end

        if PINS[path] == nil then
            return {
                status = "validation_error",
                reason = "undeclared_dependency"
            }
        end
    end

    local findings = {}
    local mismatch = false

    for path, expected in next, PINS do
        if declared[path] == nil then
            mismatch = true
            findings[path] = {
                status = "missing",
                expected = expected
            }
        elseif declared[path] ~= expected then
            mismatch = true
            findings[path] = {
                status = "version_mismatch",
                expected = expected,
                declared = declared[path]
            }
        else
            findings[path] = {
                status = "declared_version_matches",
                expected = expected
            }
        end
    end

    return {
        status = mismatch
            and "dependency_declarations_incomplete"
            or "dependency_declarations_match",
        findings = findings
    }
end

return M
