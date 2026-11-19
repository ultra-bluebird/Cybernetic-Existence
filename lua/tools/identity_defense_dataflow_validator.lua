local identity_defense_dataflow_validator = {}

local Validator = {}
Validator.__index = Validator

local forbidden_keys = {
    address = true,
    biometric = true,
    birthdate = true,
    date_of_birth = true,
    device_id = true,
    email = true,
    face_embedding = true,
    fingerprint = true,
    full_name = true,
    government_id = true,
    ip_address = true,
    iris = true,
    location = true,
    medical_record = true,
    phone = true,
    raw_identifier = true,
    retina = true,
    social_security = true,
    voiceprint = true,
}

local sensitive_patterns = {
    { name = "email", pattern = "[%w%._%+%-]+@[%w%-]+%.[%w%.%-]+" },
    { name = "ipv4", pattern = "%f[%d]%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?%f[%D]" },
    { name = "phone_like", pattern = "%f[%d]%d%d?%d?[%s%-%)]%d%d%d[%s%-]%d%d%d%d%f[%D]" },
    { name = "government_identifier_like", pattern = "%f[%d]%d%d%d?%-%d%d%-%d%d%d%d%f[%D]" },
}

local allowed_flow_kinds = {
    aggregate_metric = true,
    anonymized_summary = true,
    consent_status = true,
    derived_risk_score = true,
    pseudonymous_reference = true,
    redacted_report = true,
}

local recognized_routes = {
    legal = true,
    ethical = true,
    technical = true,
}

local supported_formats = {
    yaml = true,
    toml = true,
    markdown = true,
    json_ld = true,
    rdf = true,
    csv = true,
    sql = true,
    structured_text = true,
    symbolic_notation = true,
    html = true,
}

local route_requirements = {
    legal = {
        "jurisdiction_declared",
        "source_classification_declared",
        "enforceability_not_overclaimed",
    },
    ethical = {
        "dignity_checked",
        "consent_checked",
        "privacy_checked",
        "non_pathologization_checked",
    },
    technical = {
        "data_minimization_checked",
        "continuity_fallback_checked",
        "human_review_checked",
        "auditability_checked",
    },
}

local function finite(value, name)
    assert(type(value) == "number", name .. " must be a number")
    assert(value == value, name .. " must not be NaN")
    assert(value ~= math.huge and value ~= -math.huge, name .. " must be finite")
    return value
end

local function probability(value, name)
    value = finite(value, name)
    assert(value >= 0 and value <= 1, name .. " must be in [0, 1]")
    return value
end

local function boolean(value, name)
    assert(type(value) == "boolean", name .. " must be boolean")
    return value
end

local function nonempty_string(value, name)
    assert(type(value) == "string" and value:match("%S"),
        name .. " must be a non-empty string")
    return value
end

local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function utc_timestamp(value, name)
    if value == nil then
        return utc_now()
    end

    nonempty_string(value, name)
    assert(value:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"),
        name .. " must use UTC format YYYY-MM-DDTHH:MM:SSZ")
    return value
end

local function clamp01(value)
    value = finite(value, "score")
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function shallow_copy(value)
    local result = {}
    for key, item in pairs(value) do
        result[key] = item
    end
    return result
end

local function deep_copy(value, visited)
    if type(value) ~= "table" then
        return value
    end

    visited = visited or {}
    assert(not visited[value], "cyclic tables are not supported")

    visited[value] = true
    local copied = {}

    for key, item in pairs(value) do
        copied[deep_copy(key, visited)] = deep_copy(item, visited)
    end

    visited[value] = nil
    return copied
end

local function immutable_copy(value)
    local copied = deep_copy(value)

    local function freeze(item, visited)
        if type(item) ~= "table" then
            return item
        end

        visited = visited or {}
        if visited[item] then
            return item
        end

        visited[item] = true
        for _, child in pairs(item) do
            freeze(child, visited)
        end

        return setmetatable(item, {
            __newindex = function()
                error("validator records are immutable", 2)
            end,
            __metatable = "immutable",
        })
    end

    return freeze(copied)
end

local function set_from_array(values, name)
    assert(type(values) == "table", name .. " must be an array")

    local result = {}
    for index, value in ipairs(values) do
        result[nonempty_string(value, name .. "[" .. index .. "]")] = true
    end

    return result
end

local function sorted_keys(set)
    local keys = {}
    for key in pairs(set) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function average(values, name)
    assert(type(values) == "table" and #values > 0,
        name .. " must be a non-empty array")

    local total = 0
    for index, value in ipairs(values) do
        total = total + probability(value, name .. "[" .. index .. "]")
    end

    return total / #values
end

local function record_finding(findings, kind, path, detail)
    findings[#findings + 1] = {
        kind = kind,
        path = path,
        detail = detail,
    }
end

local function contains_forbidden_key(payload, path, findings, visited)
    if type(payload) ~= "table" then
        return
    end

    visited = visited or {}
    assert(not visited[payload], "cyclic payload tables are not supported")
    visited[payload] = true

    for key, value in pairs(payload) do
        local key_text = tostring(key)
        local normalized_key = key_text:lower()
        local next_path = path == "" and key_text or (path .. "." .. key_text)

        if forbidden_keys[normalized_key] then
            record_finding(
                findings,
                "forbidden_field",
                next_path,
                "raw identity field is prohibited in policy and AI outputs"
            )
        end

        contains_forbidden_key(value, next_path, findings, visited)
    end

    visited[payload] = nil
end

local function scan_text(text, path, findings)
    if type(text) ~= "string" then
        return
    end

    for _, rule in ipairs(sensitive_patterns) do
        if text:find(rule.pattern) then
            record_finding(
                findings,
                "sensitive_text_pattern",
                path,
                "detected " .. rule.name .. " pattern"
            )
        end
    end
end

local function scan_payload_text(payload, path, findings, visited)
    local kind = type(payload)

    if kind == "string" then
        scan_text(payload, path, findings)
        return
    end

    if kind ~= "table" then
        return
    end

    visited = visited or {}
    assert(not visited[payload], "cyclic payload tables are not supported")
    visited[payload] = true

    for key, value in pairs(payload) do
        local next_path = path == ""
            and tostring(key)
            or (path .. "." .. tostring(key))
        scan_payload_text(value, next_path, findings, visited)
    end

    visited[payload] = nil
end

local function canonical_finding_summary(findings)
    local counts = {}

    for _, finding in ipairs(findings) do
        counts[finding.kind] = (counts[finding.kind] or 0) + 1
    end

    return counts
end

local function is_allowed_flow_kind(flow_kind)
    return allowed_flow_kinds[flow_kind] == true
end

local function flow_metrics(finding_count, schema_validated)
    local knowledge_factor = schema_validated and 0.85 or 0.55
    local eco_impact_value = 0.50
    local harm_risk = finding_count == 0
        and 0.05
        or math.min(1.0, 0.25 + finding_count * 0.20)

    return knowledge_factor, eco_impact_value, harm_risk
end

function Validator.new(config)
    config = config or {}

    return setmetatable({
        maximum_report_risk = clamp01(config.maximum_report_risk or 0.20),
        monitoring_events = {},
        monitored_sources = {},
        sequence = 0,
    }, Validator)
end

function Validator:validate(flow)
    assert(type(flow) == "table", "flow must be a table")

    local source = nonempty_string(flow.source, "source")
    local destination = nonempty_string(flow.destination, "destination")
    local flow_kind = nonempty_string(flow.flow_kind, "flow_kind")
    local findings = {}

    if not is_allowed_flow_kind(flow_kind) then
        record_finding(
            findings,
            "disallowed_flow_kind",
            "flow_kind",
            "raw or unspecified data flow kinds are not permitted"
        )
    end

    contains_forbidden_key(flow.payload, "payload", findings)
    scan_payload_text(flow.payload, "payload", findings)

    local knowledge_factor, eco_impact_value, harm_risk = flow_metrics(
        #findings,
        flow.schema_validated == true
    )

    return immutable_copy({
        source = source,
        destination = destination,
        flow_kind = flow_kind,
        accepted = #findings == 0 and harm_risk <= self.maximum_report_risk,
        findings = findings,
        finding_summary = canonical_finding_summary(findings),
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
        assessed_at_utc = utc_timestamp(flow.assessed_at_utc, "assessed_at_utc"),
    })
end

function Validator:register_source(source_id, metadata)
    source_id = nonempty_string(source_id, "source_id")
    metadata = metadata or {}
    assert(type(metadata) == "table", "metadata must be a table")

    local record = immutable_copy({
        source_id = source_id,
        label = metadata.label and nonempty_string(metadata.label, "metadata.label")
            or source_id,
        enabled = metadata.enabled ~= false,
        registered_at_utc = utc_timestamp(
            metadata.registered_at_utc,
            "metadata.registered_at_utc"
        ),
    })

    self.monitored_sources[source_id] = record
    return record
end

function Validator:set_source_enabled(source_id, enabled)
    source_id = nonempty_string(source_id, "source_id")
    enabled = boolean(enabled, "enabled")

    local current = self.monitored_sources[source_id]
    assert(current, "source is not registered for continuous monitoring")

    local updated = immutable_copy({
        source_id = current.source_id,
        label = current.label,
        enabled = enabled,
        registered_at_utc = current.registered_at_utc,
    })

    self.monitored_sources[source_id] = updated
    return updated
end

function Validator:monitor(flow)
    assert(type(flow) == "table", "flow must be a table")

    local source = nonempty_string(flow.source, "source")
    local registration = self.monitored_sources[source]

    assert(registration, "source is not registered for continuous monitoring")
    assert(registration.enabled, "source monitoring is disabled")

    local result = self:validate(flow)
    self.sequence = self.sequence + 1

    local event = immutable_copy({
        sequence = self.sequence,
        source = result.source,
        destination = result.destination,
        flow_kind = result.flow_kind,
        accepted = result.accepted,
        finding_count = #result.findings,
        finding_summary = result.finding_summary,
        findings = result.findings,
        knowledge_factor = result.knowledge_factor,
        eco_impact_value = result.eco_impact_value,
        harm_risk = result.harm_risk,
        assessed_at_utc = result.assessed_at_utc,
    })

    self.monitoring_events[#self.monitoring_events + 1] = event
    return event
end

function Validator:monitor_batch(flows)
    assert(type(flows) == "table", "flows must be an array")

    local results = {
        total = 0,
        accepted = 0,
        rejected = 0,
        highest_harm_risk = 0,
        events = {},
    }

    for index, flow in ipairs(flows) do
        assert(type(flow) == "table", "flows[" .. index .. "] must be a table")

        local event = self:monitor(flow)
        results.total = results.total + 1
        results.events[#results.events + 1] = event
        results.highest_harm_risk = math.max(results.highest_harm_risk, event.harm_risk)

        if event.accepted then
            results.accepted = results.accepted + 1
        else
            results.rejected = results.rejected + 1
        end
    end

    results.knowledge_factor = results.total == 0
        and 0
        or results.accepted / results.total
    results.eco_impact_value = 0.50
    results.harm_risk = results.highest_harm_risk
    results.generated_at_utc = utc_now()

    return immutable_copy(results)
end

function Validator:report_since(sequence)
    sequence = sequence or 0
    finite(sequence, "sequence")
    assert(sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer")

    local report = {
        from_sequence = sequence,
        through_sequence = self.sequence,
        events = {},
        total = 0,
        accepted = 0,
        rejected = 0,
        highest_harm_risk = 0,
        finding_counts = {},
    }

    for _, event in ipairs(self.monitoring_events) do
        if event.sequence > sequence then
            report.events[#report.events + 1] = event
            report.total = report.total + 1
            report.highest_harm_risk = math.max(report.highest_harm_risk, event.harm_risk)

            if event.accepted then
                report.accepted = report.accepted + 1
            else
                report.rejected = report.rejected + 1
            end

            for kind, count in pairs(event.finding_summary) do
                report.finding_counts[kind] = (report.finding_counts[kind] or 0) + count
            end
        end
    end

    report.knowledge_factor = report.total == 0
        and 0
        or report.accepted / report.total
    report.eco_impact_value = 0.50
    report.harm_risk = report.highest_harm_risk
    report.generated_at_utc = utc_now()

    return immutable_copy(report)
end

function Validator:source_status(source_id)
    source_id = nonempty_string(source_id, "source_id")

    local source = self.monitored_sources[source_id]
    if not source then
        return nil, "source is not registered"
    end

    return source
end

function identity_defense_dataflow_validator.new(config)
    return Validator.new(config)
end

function identity_defense_dataflow_validator.validate_dataflow(input)
    assert(type(input) == "table", "input must be a table")

    local original_terms_quoted = boolean(
        input.original_terms_quoted,
        "original_terms_quoted"
    )
    local protected_terms_preserved = boolean(
        input.protected_terms_preserved,
        "protected_terms_preserved"
    )
    local restatement_labeled = boolean(
        input.restatement_labeled,
        "restatement_labeled"
    )
    local user_meaning_confirmed = boolean(
        input.user_meaning_confirmed,
        "user_meaning_confirmed"
    )
    local material_ambiguity = boolean(
        input.material_ambiguity,
        "material_ambiguity"
    )
    local clarification_requested = boolean(
        input.clarification_requested,
        "clarification_requested"
    )
    local clarification_count = finite(
        input.clarification_count,
        "clarification_count"
    )

    assert(clarification_count >= 0 and clarification_count % 1 == 0,
        "clarification_count must be a non-negative integer")

    local terms_checked = original_terms_quoted
        and protected_terms_preserved
        and restatement_labeled

    local clarification_safe = clarification_count <= 1
        and (
            user_meaning_confirmed
            or not material_ambiguity
            or clarification_requested
        )

    local ready_to_route = terms_checked and clarification_safe

    return immutable_copy({
        quote_and_preserve_ready = terms_checked,
        meaning_confirmation_ready = user_meaning_confirmed or not material_ambiguity,
        clarification_safe = clarification_safe,
        ready_to_route = ready_to_route,
        decision = ready_to_route
            and "route the request only through a declared legal, ethical, or technical analysis layer"
            or "preserve original wording and ask at most one focused clarification question before routing",
    })
end

function identity_defense_dataflow_validator.validate_layer_route(input)
    assert(type(input) == "table", "input must be a table")

    local routes = set_from_array(input.routes, "routes")
    local requested_artifact = nonempty_string(
        input.requested_artifact,
        "requested_artifact"
    )
    local requested_next_step = boolean(
        input.requested_next_step,
        "requested_next_step"
    )

    local invalid_routes = {}
    local selected_routes = sorted_keys(routes)

    for _, route in ipairs(selected_routes) do
        if not recognized_routes[route] then
            invalid_routes[#invalid_routes + 1] = route
        end
    end

    local routes_valid = #selected_routes > 0 and #invalid_routes == 0

    return immutable_copy({
        routes = routes,
        selected_routes = selected_routes,
        routes_valid = routes_valid,
        invalid_routes = invalid_routes,
        requested_artifact = requested_artifact,
        requested_next_step = requested_next_step,
        route_requirements = route_requirements,
        decision = routes_valid
            and "produce the requested reusable artifact with declared analysis boundaries"
            or "do not route until at least one recognized analysis layer is selected",
    })
end

function identity_defense_dataflow_validator.validate_representation_plan(input)
    assert(type(input) == "table", "input must be a table")

    local formats = set_from_array(input.formats, "formats")
    local selected_formats = sorted_keys(formats)
    local unsupported_formats = {}
    local selected_supported = 0

    for _, format in ipairs(selected_formats) do
        if supported_formats[format] then
            selected_supported = selected_supported + 1
        else
            unsupported_formats[#unsupported_formats + 1] = format
        end
    end

    return immutable_copy({
        selected_formats = selected_formats,
        selected_supported_format_count = selected_supported,
        unsupported_formats = unsupported_formats,
        representation_ready = selected_supported > 0,
        constraints = {
            "use_portable_human_readable_formats",
            "keep_protected_terms_in_primary_representation",
            "do_not_require_semantic_web_or_database_infrastructure",
            "do_not_require_identity_or_health_disclosure_for_format_selection",
            "provide_structured_text_or_symbolic_notation_when_requested",
        },
        decision = selected_supported > 0
            and "use the selected portable representation with a readable export path"
            or "select at least one supported, portable representation before creating an artifact",
    })
end

function identity_defense_dataflow_validator.validate_research_artifact(input)
    assert(type(input) == "table", "input must be a table")

    local reusable = boolean(input.reusable, "reusable")
    local original_terms_preserved = boolean(
        input.original_terms_preserved,
        "original_terms_preserved"
    )
    local uncertainty_disclosed = boolean(
        input.uncertainty_disclosed,
        "uncertainty_disclosed"
    )
    local evidence_source_declared = boolean(
        input.evidence_source_declared,
        "evidence_source_declared"
    )
    local privacy_minimized = boolean(
        input.privacy_minimized,
        "privacy_minimized"
    )
    local accessible_format_available = boolean(
        input.accessible_format_available,
        "accessible_format_available"
    )
    local next_step_bounded = boolean(
        input.next_step_bounded,
        "next_step_bounded"
    )

    local artifact_score = average({
        reusable and 1 or 0,
        original_terms_preserved and 1 or 0,
        uncertainty_disclosed and 1 or 0,
        evidence_source_declared and 1 or 0,
        privacy_minimized and 1 or 0,
        accessible_format_available and 1 or 0,
        next_step_bounded and 1 or 0,
    }, "artifact controls")

    local artifact_ready = reusable
        and original_terms_preserved
        and privacy_minimized
        and accessible_format_available
        and next_step_bounded

    return immutable_copy({
        artifact_ready = artifact_ready,
        artifact_score = artifact_score,
        reusable = reusable,
        original_terms_preserved = original_terms_preserved,
        uncertainty_disclosed = uncertainty_disclosed,
        evidence_source_declared = evidence_source_declared,
        privacy_minimized = privacy_minimized,
        accessible_format_available = accessible_format_available,
        next_step_bounded = next_step_bounded,
        decision = artifact_ready
            and "release the artifact with one bounded next-step request"
            or "do not finalize; correct terminology, privacy, accessibility, reuse, or next-step deficiencies",
    })
end

function identity_defense_dataflow_validator.assessment_metrics(input)
    assert(type(input) == "table", "input must be a table")

    local knowledge_factor = average({
        probability(input.source_quality, "source_quality"),
        probability(input.meaning_confirmation_quality, "meaning_confirmation_quality"),
        probability(input.evidence_traceability, "evidence_traceability"),
        probability(input.method_transparency, "method_transparency"),
    }, "knowledge inputs")

    local eco_impact_value = average({
        probability(input.service_continuity_benefit, "service_continuity_benefit"),
        probability(input.access_equity_benefit, "access_equity_benefit"),
        probability(input.resource_efficiency_benefit, "resource_efficiency_benefit"),
    }, "eco-impact inputs")

    local harm_risk = average({
        probability(input.terminology_displacement_risk, "terminology_displacement_risk"),
        probability(input.unnecessary_disclosure_risk, "unnecessary_disclosure_risk"),
        probability(input.unexplained_refusal_risk, "unexplained_refusal_risk"),
        probability(input.inaccessible_format_risk, "inaccessible_format_risk"),
        probability(input.overclaiming_legal_status_risk, "overclaiming_legal_status_risk"),
    }, "harm-risk inputs")

    return immutable_copy({
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
    })
end

return identity_defense_dataflow_validator
