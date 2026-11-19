local identity_protection_rule = {}

local function nonempty_string(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

function identity_protection_rule.evaluate(declaration)
    if type(declaration) ~= "table"
        or type(declaration.voluntarily_provided) ~= "boolean"
        or not nonempty_string(declaration.self_description)
        or type(declaration.requests_sensitive_data_collection) ~= "boolean"
        or type(declaration.requests_identity_verification) ~= "boolean"
        or type(declaration.requests_harm_or_rights_deprivation_for_others) ~= "boolean" then
        return {
            decision = "INVALID_DECLARATION",
            commitments = {
                "do_not_infer_identity",
                "maintain_non_discrimination",
                "offer_accessible_voluntary_correction"
            }
        }
    end

    if declaration.requests_harm_or_rights_deprivation_for_others then
        return {
            decision = "PROTECT_AND_ESCALATE_HARM_CONSTRAINT",
            commitments = {
                "protect_from_discrimination",
                "do_not_implement_harmful_or_coercive_request",
                "offer_accessible_human_review"
            }
        }
    end

    local commitments = {
        "protect_without_identity_adjudication",
        "respect_self_asserted_identity",
        "do_not_collect_neural_biometric_health_or_device_data",
        "do_not_require_identity_verification",
        "provide_accessible_grievance_and_review"
    }

    if declaration.requests_sensitive_data_collection
        or declaration.requests_identity_verification then
        table.insert(commitments, "decline_sensitive_collection_while_preserving_protection")
    end

    return {
        decision = "PROTECT_WITHOUT_ADJUDICATION",
        commitments = commitments
    }
end

return identity_protection_rule
