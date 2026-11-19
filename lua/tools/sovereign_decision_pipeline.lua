-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/sovereign_decision_pipeline.lua
-- Destination: lua/tools/

local SovereignDecisionPipeline = {}
SovereignDecisionPipeline.__index = SovereignDecisionPipeline

local allowed_decision_kinds = {
    augmentation_preference = true,
    data_sharing = true,
    identity_claim = true,
    interface_preference = true,
    service_authorization = true,
}

local allowed_data_scopes = {
    adapted_output = true,
    aggregate_quality_metric = true,
    pseudonymous_reference = true,
    redacted_policy_report = true,
    semantic_intent = true,
}

local allowed_decisions = {
    allow = true,
    deny = true,
    defer = true,
}

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function finite_number(value, field)
    assert(
        type(value) == "number"
            and value == value
            and value ~= math.huge
            and value ~= -math.huge,
        (field or "value") .. " must be a finite number"
    )
    return value
end

local function clamp01(value)
    value = finite_number(value, "score")

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic decision values are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function stable_reference(namespace, value)
    local state = 2166136261
    local material = namespace .. "|" .. value

    for index = 1, #material do
        state = (state * 16777619 + material:byte(index)) % 4294967296
    end

    return string.format("decision:%08x", state)
end

local function normalize_scopes(scopes)
    assert(type(scopes) == "table", "data_scopes must be a table")

    local normalized = {}
    local count = 0

    for _, scope in ipairs(scopes) do
        scope = required_text(scope, "data scope")
        assert(allowed_data_scopes[scope], "unsupported data scope: " .. scope)

        if not normalized[scope] then
            normalized[scope] = true
            count = count + 1
        end
    end

    return normalized, count
end

function SovereignDecisionPipeline.new(config)
    config = config or {}

    return setmetatable({
        namespace = required_text(
            config.namespace or "sovereign-decision-pipeline",
            "namespace"
        ),
        decisions = {},
        pending = {},
        audit_events = {},
        sequence = 0,
    }, SovereignDecisionPipeline)
end

function SovereignDecisionPipeline:propose(proposal)
    assert(type(proposal) == "table", "proposal must be a table")

    local subject_reference = required_text(
        proposal.subject_reference,
        "subject_reference"
    )
    local decision_kind = required_text(
        proposal.decision_kind,
        "decision_kind"
    )

    assert(allowed_decision_kinds[decision_kind],
        "unsupported decision_kind")

    local proposal_nonce = required_text(
        proposal.local_proposal_nonce,
        "local_proposal_nonce"
    )

    local decision_reference = stable_reference(
        self.namespace,
        subject_reference .. "|" .. proposal_nonce
    )

    assert(not self.pending[decision_reference],
        "a pending proposal already uses this decision reference")
    assert(not self.decisions[decision_reference],
        "a finalized decision already uses this decision reference")

    local data_scopes, scope_count = normalize_scopes(
        proposal.data_scopes or {}
    )

    local pending = {
        decision_reference = decision_reference,
        subject_reference = subject_reference,
        decision_kind = decision_kind,
        purpose = required_text(proposal.purpose, "purpose"),
        target_reference = proposal.target_reference
            and required_text(proposal.target_reference, "target_reference")
            or "local_only",
        data_scopes = data_scopes,
        data_scope_count = scope_count,
        irreversible = proposal.irreversible == true,
        proposed_at_utc = proposal.proposed_at_utc or utc_now(),
        context = copy_value(proposal.context or {}),
        external_execution_requested =
            proposal.external_execution_requested == true,
    }

    assert(
        not pending.external_execution_requested,
        "this pipeline is local and advisory; external execution is not supported"
    )

    self.pending[decision_reference] = pending
    self:_append_audit("decision_proposed", decision_reference, {
        decision_kind = decision_kind,
        data_scope_count = scope_count,
        irreversible = pending.irreversible,
    })

    return copy_value(pending)
end

function SovereignDecisionPipeline:finalize(decision_reference, confirmation)
    decision_reference = required_text(
        decision_reference,
        "decision_reference"
    )
    assert(type(confirmation) == "table", "confirmation must be a table")

    local pending = assert(
        self.pending[decision_reference],
        "pending decision proposal not found"
    )

    assert(
        confirmation.user_is_final_authority == true,
        "the user must explicitly confirm final authority"
    )

    local decision = required_text(confirmation.decision, "decision")
    assert(allowed_decisions[decision], "decision must be allow, deny, or defer")

    if pending.irreversible and decision == "allow" then
        assert(
            confirmation.explicit_irrevocable_confirmation == true,
            "irreversible approval requires explicit confirmation"
        )
    end

    local finalized = {
        decision_reference = pending.decision_reference,
        subject_reference = pending.subject_reference,
        decision_kind = pending.decision_kind,
        purpose = pending.purpose,
        target_reference = pending.target_reference,
        data_scopes = copy_value(pending.data_scopes),
        decision = decision,
        user_is_final_authority = true,
        irreversible = pending.irreversible,
        revocation_available = pending.irreversible ~= true,
        finalized_at_utc = confirmation.finalized_at_utc or utc_now(),
        rationale = confirmation.rationale
            and required_text(confirmation.rationale, "rationale")
            or "user-directed decision",
        context = copy_value(pending.context),
        external_execution_performed = false,
        knowledge_factor = confirmation.evidence_complete == true and 0.85 or 0.65,
        eco_impact_value = clamp01(confirmation.eco_impact_value or 0.50),
        harm_risk = clamp01(
            (pending.irreversible and decision == "allow" and 0.25 or 0.05)
                + (decision == "defer" and 0.05 or 0)
        ),
    }

    self.pending[decision_reference] = nil
    self.decisions[decision_reference] = finalized

    self:_append_audit("decision_finalized", decision_reference, {
        decision = decision,
        irreversible = finalized.irreversible,
        revocation_available = finalized.revocation_available,
        external_execution_performed = false,
    })

    return copy_value(finalized)
end

function SovereignDecisionPipeline:revoke(decision_reference, revocation)
    decision_reference = required_text(
        decision_reference,
        "decision_reference"
    )
    assert(type(revocation) == "table", "revocation must be a table")

    local decision = assert(
        self.decisions[decision_reference],
        "finalized decision not found"
    )

    assert(
        decision.revocation_available,
        "this finalized decision does not support revocation"
    )
    assert(
        revocation.user_is_final_authority == true,
        "the user must explicitly authorize revocation"
    )

    local revoked = copy_value(decision)
    revoked.decision = "deny"
    revoked.revoked = true
    revoked.revoked_at_utc = revocation.revoked_at_utc or utc_now()
    revoked.revocation_reason = required_text(
        revocation.reason,
        "revocation.reason"
    )
    revoked.harm_risk = 0.05

    self.decisions[decision_reference] = revoked

    self:_append_audit("decision_revoked", decision_reference, {
        decision_kind = revoked.decision_kind,
        reason = revoked.revocation_reason,
    })

    return copy_value(revoked)
end

function SovereignDecisionPipeline:resolve(decision_reference)
    decision_reference = required_text(
        decision_reference,
        "decision_reference"
    )

    local finalized = self.decisions[decision_reference]

    if finalized then
        return {
            state = "finalized",
            decision = copy_value(finalized),
        }
    end

    local pending = self.pending[decision_reference]

    if pending then
        return {
            state = "pending_user_confirmation",
            decision = copy_value(pending),
        }
    end

    return nil, "decision reference not found"
end

function SovereignDecisionPipeline:_append_audit(
    event_type,
    decision_reference,
    details
)
    self.sequence = self.sequence + 1

    self.audit_events[#self.audit_events + 1] = {
        sequence = self.sequence,
        event_type = event_type,
        decision_reference = decision_reference,
        details = copy_value(details or {}),
        occurred_at_utc = utc_now(),
        knowledge_factor = 0.80,
        eco_impact_value = 0.50,
        harm_risk = 0.10,
    }
end

function SovereignDecisionPipeline:audit_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local events = {}
    local highest_harm_risk = 0

    for _, event in ipairs(self.audit_events) do
        if event.sequence > sequence then
            events[#events + 1] = copy_value(event)
            highest_harm_risk = math.max(
                highest_harm_risk,
                event.harm_risk
            )
        end
    end

    return {
        from_sequence = sequence,
        event_count = #events,
        events = events,
        knowledge_factor = #events == 0 and 0 or 0.80,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return SovereignDecisionPipeline
