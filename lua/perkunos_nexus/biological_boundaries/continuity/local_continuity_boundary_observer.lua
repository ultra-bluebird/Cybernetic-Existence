-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Role: local manifest continuity review and private-description commitments.
-- Prometheus-Praxis / Perkunos-Nexus; Lua 5.3 or Lua 5.4.
-- No firmware, physical recovery, interruption, network, or device APIs.
-- Private state and cryptographic opening material never enter this module.

local M = {}
local floor, huge = math.floor, math.huge
local MAX = 9007199254740991

local CONFIG_KEYS = {
    scope_ref=true,
    contract_version=true,
    manifest_schema_ref=true,
    boundary_schema_ref=true,
    crypto_scheme_ref=true,
    scheme_review_ref=true,
    essential_components=true,
    maximum_snapshot_age_buckets=true,
}

local PORT_KEYS = {
    admit=true,
    clock_bucket=true,
    read_snapshot=true,
    commit_private_boundary=true,
    check_private_boundary=true,
    commitment_equal=true,
}

local SNAPSHOT_KEYS = {
    scope_ref=true,
    manifest_schema_ref=true,
    epoch=true,
    observation_bucket=true,
    components=true,
    network_state=true,
    local_operation_state=true,
    dependency_assessment=true,
    provenance_ref=true,
}

local COMMITMENT_KEYS = {
    scope_ref=true,
    boundary_schema_ref=true,
    scheme_ref=true,
    state_version=true,
    private_state_ref=true,
    commitment_ref=true,
    binding_record_ref=true,
}

local CHECK_KEYS = {
    scope_ref=true,
    boundary_schema_ref=true,
    scheme_ref=true,
    state_version=true,
    private_state_ref=true,
    commitment_ref=true,
    matches=true,
}

local NETWORK = { online=true, outage=true, unknown=true }
local OPERATION = { available=true, unavailable=true, unknown=true }
local DEPENDENCIES = {
    local_dependencies_declared=true,
    remote_dependency_present=true,
    unknown=true,
}

local function integer(x, low, high)
    return type(x) == "number" and x == x
        and x ~= huge and x ~= -huge
        and x >= low and x <= high and x == floor(x)
end

local function plain(t)
    return type(t) == "table" and getmetatable(t) == nil
end

local function exact(t, allowed, expected)
    if not plain(t) then return false end
    local count = 0
    for key in next, t do
        count = count+1
        if count > expected or allowed[key] ~= true then return false end
    end
    return count == expected
end

local function ref(value)
    return type(value) == "string"
        and #value >= 1 and #value <= 256
        and value:match("^[A-Za-z0-9_:/%.%-]+$") ~= nil
end

local function copy_validated(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in next, value do
        result[key] = copy_validated(item)
    end
    return result
end

local function sorted_keys(t)
    local keys = {}
    for key in next, t do keys[#keys+1] = key end
    table.sort(keys)
    return keys
end

local function failure(code)
    return nil, {
        code=code,
        not_a_legal_finding=true,
        not_a_person_score=true,
        actuation_authority=false,
        system_effect_scope="module_observation_only",
    }
end

local function result(status)
    return {
        status=status,
        not_a_legal_finding=true,
        not_a_person_score=true,
        actuation_authority=false,
        system_effect_scope="module_observation_only",
        biological_state_verified=false,
        covert_action_established=false,
    }
end

local function read_components(value)
    if not plain(value) then return nil end
    local result, count = {}, 0

    for component, commitment in next, value do
        count = count+1
        if count > 128 or not ref(component) or not ref(commitment) then
            return nil
        end
        result[component] = commitment
    end

    if count == 0 then return nil end
    return result
end

function M.new(config, ports, initialization_token)
    if not exact(config, CONFIG_KEYS, 8)
        or not ref(config.scope_ref)
        or not integer(config.contract_version, 1, 2147483647)
        or not ref(config.manifest_schema_ref)
        or not ref(config.boundary_schema_ref)
        or not ref(config.crypto_scheme_ref)
        or not ref(config.scheme_review_ref)
        or not integer(config.maximum_snapshot_age_buckets, 0, MAX)
        or not plain(config.essential_components)
        or not exact(ports, PORT_KEYS, 6) then
        return failure("invalid_configuration")
    end

    local essential, count = {}, 0
    for component, required in next, config.essential_components do
        count = count+1
        if count > 128 or not ref(component) or required ~= true then
            return failure("invalid_essential_component_set")
        end
        essential[component] = true
    end
    if count == 0 then return failure("essential_components_required") end

    for key in next, PORT_KEYS do
        if type(ports[key]) ~= "function" then
            return failure("missing_local_adapter")
        end
    end

    local c = copy_validated(config)
    local admit = ports.admit
    local clock_bucket = ports.clock_bucket
    local read_snapshot = ports.read_snapshot
    local commit_boundary = ports.commit_private_boundary
    local check_boundary = ports.check_private_boundary
    local equal = ports.commitment_equal

    local baselines = {}
    local last_bucket
    local busy = false

    local function call(adapter, ...)
        local ok, value = pcall(adapter, ...)
        if not ok then return nil, "adapter_exception" end
        return value
    end

    local function authorize(token, operation, payload)
        if type(token) ~= "string" or #token < 1 or #token > 128 then
            return false
        end
        local accepted = call(
            admit, token, operation, c.scope_ref,
            c.contract_version, copy_validated(payload))
        return accepted == true
    end

    if not authorize(initialization_token,
        "initialize_local_continuity_observer", c) then
        return failure("initialization_not_admitted")
    end

    local function run(operation)
        if busy then return failure("operation_in_progress") end
        busy = true
        local ok, value, issue = pcall(operation)
        busy = false
        if not ok then return failure("observer_operation_failed") end
        return value, issue
    end

    local function current_snapshot()
        local now, clock_error = call(clock_bucket)
        if not integer(now, 0, MAX)
            or (last_bucket ~= nil and now < last_bucket) then
            return nil, clock_error or "clock_invalid_or_regressed"
        end
        last_bucket = now

        local supplied, read_error = call(read_snapshot, c.scope_ref)
        if not exact(supplied, SNAPSHOT_KEYS, 9)
            or supplied.scope_ref ~= c.scope_ref
            or supplied.manifest_schema_ref ~= c.manifest_schema_ref
            or not integer(supplied.epoch, 1, 2147483647)
            or not integer(supplied.observation_bucket, 0, now)
            or now-supplied.observation_bucket > c.maximum_snapshot_age_buckets
            or NETWORK[supplied.network_state] ~= true
            or OPERATION[supplied.local_operation_state] ~= true
            or DEPENDENCIES[supplied.dependency_assessment] ~= true
            or not ref(supplied.provenance_ref) then
            return nil, read_error or "snapshot_invalid_or_stale"
        end

        local components = read_components(supplied.components)
        if components == nil then return nil, "invalid_component_manifest" end

        local snapshot = {
            scope_ref=supplied.scope_ref,
            manifest_schema_ref=supplied.manifest_schema_ref,
            epoch=floor(supplied.epoch),
            observation_bucket=floor(supplied.observation_bucket),
            components=components,
            network_state=supplied.network_state,
            local_operation_state=supplied.local_operation_state,
            dependency_assessment=supplied.dependency_assessment,
            provenance_ref=supplied.provenance_ref,
        }

        return snapshot
    end

    local function capture_baseline(token)
        return run(function()
            local snapshot, issue = current_snapshot()
            if snapshot == nil then return failure(issue) end
            if #baselines >= 16 then return failure("baseline_capacity_reached") end

            if not authorize(token, "retain_continuity_comparison_baseline", snapshot) then
                return failure("baseline_not_admitted")
            end

            baselines[#baselines+1] = copy_validated(snapshot)

            local output = result("comparison_baseline_retained")
            output.baseline_ref = #baselines
            output.epoch = snapshot.epoch
            output.operational_state_backed_up = false
            output.durable = false
            output.validation_required = {
                "durable_state_preservation_mechanism",
                "manifest_to_system_correspondence",
                "actual_offline_task_exercises",
            }
            return output
        end)
    end

    local function compare_baseline(baseline_ref, token)
        return run(function()
            if not integer(baseline_ref, 1, #baselines) then
                return failure("comparison_baseline_unavailable")
            end

            local observed, issue = current_snapshot()
            if observed == nil then return failure(issue) end

            local baseline = baselines[baseline_ref]
            if not authorize(token, "compare_local_continuity", {
                baseline_ref=baseline_ref,
                reference=baseline,
                observed=observed,
            }) then
                return failure("continuity_review_not_admitted")
            end

            local missing, changed, additional, essential_missing = {}, {}, {}, {}
            local keys = sorted_keys(baseline.components)

            for i = 1, #keys do
                local key = keys[i]
                if observed.components[key] == nil then
                    missing[#missing+1] = key
                else
                    local match, compare_error = call(
                        equal, baseline.components[key], observed.components[key])
                    if compare_error ~= nil or type(match) ~= "boolean" then
                        return failure("commitment_comparison_unresolved")
                    end
                    if not match then changed[#changed+1] = key end
                end
            end

            keys = sorted_keys(observed.components)
            for i = 1, #keys do
                local key = keys[i]
                if baseline.components[key] == nil then
                    additional[#additional+1] = key
                end
            end

            keys = sorted_keys(essential)
            for i = 1, #keys do
                if observed.components[keys[i]] == nil then
                    essential_missing[#essential_missing+1] = keys[i]
                end
            end

            local epoch_relation = observed.epoch == baseline.epoch
                and "same_epoch"
                or (observed.epoch < baseline.epoch
                    and "older_epoch_observed" or "newer_epoch_observed")

            local discrepancy = #missing > 0 or #changed > 0
                or #additional > 0 or #essential_missing > 0
                or observed.epoch < baseline.epoch

            local output = result(discrepancy
                and "state_discrepancy_review" or "listed_components_match")
            output.baseline_ref = baseline_ref
            output.epoch_relation = epoch_relation
            output.missing_components = missing
            output.changed_components = changed
            output.additional_components = additional
            output.essential_components_missing_from_manifest = essential_missing
            output.network_state = observed.network_state
            output.local_operation_state = observed.local_operation_state
            output.dependency_assessment = observed.dependency_assessment
            output.observation_provenance_ref = observed.provenance_ref
            output.offline_capability_demonstrated = false
            output.restoration_performed = false
            output.validation_required = {
                "authenticate_observation_and_anchor_lineage",
                "check_authorized_changes_before_attributing_intent",
                "exercise_essential_tasks_during_outage",
                "verify_forward_recovery_fidelity",
            }
            return output
        end)
    end

    local function create_boundary_commitment(private_ref, state_version, token)
        return run(function()
            if not ref(private_ref)
                or not integer(state_version, 1, 2147483647) then
                return failure("invalid_private_boundary_reference")
            end

            local request = {
                scope_ref=c.scope_ref,
                private_state_ref=private_ref,
                state_version=state_version,
                boundary_schema_ref=c.boundary_schema_ref,
                scheme_ref=c.crypto_scheme_ref,
                scheme_review_ref=c.scheme_review_ref,
            }

            if not authorize(token, "commit_private_boundary_description", request) then
                return failure("boundary_commitment_not_admitted")
            end

            local record, issue = call(commit_boundary, copy_validated(request))
            if not exact(record, COMMITMENT_KEYS, 7)
                or record.scope_ref ~= c.scope_ref
                or record.boundary_schema_ref ~= c.boundary_schema_ref
                or record.scheme_ref ~= c.crypto_scheme_ref
                or record.state_version ~= state_version
                or record.private_state_ref ~= private_ref
                or not ref(record.commitment_ref)
                or not ref(record.binding_record_ref) then
                return failure(issue or "boundary_commitment_binding_unresolved")
            end

            local output = result("private_description_commitment_reported")
            output.record = copy_validated(record)
            output.private_state_included = false
            output.opening_material_included = false
            output.hiding_and_binding_verified_by_module = false
            output.zero_knowledge_protocol_implemented = false
            output.validation_required = {
                "scheme_and_randomness_review",
                "private_state_schema_and_measurement_provenance",
                "protected_opening_material_and_local_storage",
                "separate_release_admission_if_disclosed",
            }
            return output
        end)
    end

    local function verify_boundary_commitment(record, token)
        return run(function()
            if not exact(record, COMMITMENT_KEYS, 7)
                or record.scope_ref ~= c.scope_ref
                or record.boundary_schema_ref ~= c.boundary_schema_ref
                or record.scheme_ref ~= c.crypto_scheme_ref
                or not integer(record.state_version, 1, 2147483647)
                or not ref(record.private_state_ref)
                or not ref(record.commitment_ref)
                or not ref(record.binding_record_ref) then
                return failure("invalid_boundary_commitment_record")
            end

            local private = copy_validated(record)
            if not authorize(token, "check_private_boundary_description", private) then
                return failure("boundary_check_not_admitted")
            end

            local checked, issue = call(check_boundary, copy_validated(private))
            if not exact(checked, CHECK_KEYS, 7)
                or checked.scope_ref ~= private.scope_ref
                or checked.boundary_schema_ref ~= private.boundary_schema_ref
                or checked.scheme_ref ~= private.scheme_ref
                or checked.state_version ~= private.state_version
                or checked.private_state_ref ~= private.private_state_ref
                or checked.commitment_ref ~= private.commitment_ref
                or type(checked.matches) ~= "boolean" then
                return failure(issue or "boundary_check_binding_unresolved")
            end

            local output = result(checked.matches
                and "adapter_reports_private_description_match"
                or "adapter_reports_private_description_mismatch")
            output.matches_asserted_by_adapter = checked.matches
            output.zero_knowledge_protocol_implemented = false
            output.validation_required = {
                "verify_adapter_and_protected_opening_material",
                "confirm_description_corresponds_to_observed_system",
                "separate_biological_assessment_if_claimed",
            }
            return output
        end)
    end

    return {
        capture_baseline=capture_baseline,
        compare_baseline=compare_baseline,
        create_boundary_commitment=create_boundary_commitment,
        verify_boundary_commitment=verify_boundary_commitment,
    }
end

return M
