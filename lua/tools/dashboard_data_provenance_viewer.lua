local ProvenanceViewer = {}
ProvenanceViewer.__index = ProvenanceViewer

local FORBIDDEN_KEY_FRAGMENTS = {
    "address",
    "biometric",
    "device_id",
    "email",
    "fingerprint",
    "health",
    "identity",
    "ip",
    "location",
    "name",
    "neural",
    "phone",
    "precise",
    "telemetry",
    "user_id",
}

local EVIDENCE_TAG_PATTERN = "^0x[%x]+$"

local function html_escape(value)
    value = tostring(value)
    value = value:gsub("&", "&amp;")
    value = value:gsub("<", "&lt;")
    value = value:gsub(">", "&gt;")
    value = value:gsub('"', "&quot;")
    value = value:gsub("'", "&#39;")
    return value
end

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function normalize_text(value, fallback)
    if type(value) ~= "string" then
        return fallback
    end

    local result = trim(value)
    if result == "" then
        return fallback
    end

    return result
end

local function contains_forbidden_key(key)
    local normalized = string.lower(key)

    for _, fragment in ipairs(FORBIDDEN_KEY_FRAGMENTS) do
        if normalized:find(fragment, 1, true) then
            return true
        end
    end

    return false
end

local function assert_aggregate_only(value, path, visited)
    if type(value) ~= "table" then
        return
    end

    visited = visited or {}
    if visited[value] then
        error("Cyclic table detected at " .. path .. ".")
    end
    visited[value] = true

    for key, child in pairs(value) do
        local child_path = path .. "." .. tostring(key)

        if type(key) == "string" and contains_forbidden_key(key) then
            error("Provenance contains prohibited identifying field: " .. child_path)
        end

        local child_type = type(child)
        if child_type == "function" or child_type == "thread" or child_type == "userdata" then
            error("Provenance contains unsupported value at " .. child_path .. ".")
        end

        assert_aggregate_only(child, child_path, visited)
    end

    visited[value] = nil
end

local function is_array(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    local largest = 0

    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end

        count = count + 1
        if key > largest then
            largest = key
        end
    end

    return count == largest
end

local function sorted_string_keys(value)
    local keys = {}

    for key, _ in pairs(value) do
        if type(key) == "string" then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)
    return keys
end

local function normalize_evidence_tag(tag)
    if type(tag) ~= "string" then
        return nil
    end

    local normalized = string.upper(trim(tag))
    if not normalized:match(EVIDENCE_TAG_PATTERN) then
        return nil
    end

    return normalized
end

local function normalize_evidence_tags(tags)
    local unique = {}
    local normalized_tags = {}

    if type(tags) ~= "table" then
        return normalized_tags
    end

    for _, tag in ipairs(tags) do
        local normalized = normalize_evidence_tag(tag)
        if normalized and not unique[normalized] then
            unique[normalized] = true
            normalized_tags[#normalized_tags + 1] = normalized
        end
    end

    table.sort(normalized_tags)
    return normalized_tags
end

local function list_items_html(items)
    if #items == 0 then
        return "<p>None declared.</p>"
    end

    local rows = {}
    for index, item in ipairs(items) do
        rows[index] = "<li>" .. html_escape(item) .. "</li>"
    end

    return "<ul>" .. table.concat(rows) .. "</ul>"
end

local function list_items_text(items)
    if #items == 0 then
        return "- None declared."
    end

    local rows = {}
    for index, item in ipairs(items) do
        rows[index] = "- " .. item
    end

    return table.concat(rows, "\n")
end

local function snapshot_timestamp(snapshot)
    if type(snapshot) ~= "table" then
        return "Not declared"
    end

    return normalize_text(
        snapshot.timestamp or snapshot.observed_at or snapshot.created_at,
        "Not declared"
    )
end

local function metric_entries(snapshot)
    local metrics = snapshot.metrics or snapshot.metric_provenance or {}
    local entries = {}

    if type(metrics) ~= "table" then
        return entries
    end

    if is_array(metrics) then
        for _, metric in ipairs(metrics) do
            if type(metric) == "table" and type(metric.name) == "string" then
                entries[#entries + 1] = {
                    name = metric.name,
                    definition = metric.definition,
                    source_categories = metric.source_categories,
                    limitations = metric.limitations,
                    evidence_tags = metric.evidence_tags,
                    computation_trace = metric.computation_trace,
                    advisory_notice = metric.advisory_notice,
                }
            end
        end
    else
        for _, name in ipairs(sorted_string_keys(metrics)) do
            local metric = metrics[name]
            if type(metric) == "table" then
                entries[#entries + 1] = {
                    name = name,
                    definition = metric.definition,
                    source_categories = metric.source_categories,
                    limitations = metric.limitations,
                    evidence_tags = metric.evidence_tags,
                    computation_trace = metric.computation_trace,
                    advisory_notice = metric.advisory_notice,
                }
            end
        end
    end

    table.sort(entries, function(left, right)
        return left.name < right.name
    end)

    return entries
end

function ProvenanceViewer.new(options)
    options = options or {}

    if type(options.snapshot_store) ~= "table" then
        error("snapshot_store must be a table keyed by snapshot ID.")
    end

    return setmetatable({
        snapshot_store = options.snapshot_store,
        default_advisory_notice = normalize_text(
            options.default_advisory_notice,
            "Dashboard metrics are aggregate, advisory indicators. They must not be used to determine an individual's eligibility, access, identity, worth, risk, or treatment."
        ),
    }, ProvenanceViewer)
end

function ProvenanceViewer:_get_snapshot(snapshot_id)
    if type(snapshot_id) ~= "string" or trim(snapshot_id) == "" then
        return nil, "snapshot_id must be a non-empty string."
    end

    local snapshot = self.snapshot_store[snapshot_id]
    if type(snapshot) ~= "table" then
        return nil, "Snapshot not found."
    end

    local safe, privacy_error = pcall(assert_aggregate_only, snapshot, "snapshot")
    if not safe then
        return nil, tostring(privacy_error)
    end

    return snapshot
end

function ProvenanceViewer:list_evidence_tags()
    local unique = {}

    for _, snapshot in pairs(self.snapshot_store) do
        if type(snapshot) == "table" then
            local safe = pcall(assert_aggregate_only, snapshot, "snapshot")
            if safe then
                for _, metric in ipairs(metric_entries(snapshot)) do
                    for _, tag in ipairs(normalize_evidence_tags(metric.evidence_tags)) do
                        unique[tag] = true
                    end
                end
            end
        end
    end

    local tags = {}
    for tag, _ in pairs(unique) do
        tags[#tags + 1] = tag
    end

    table.sort(tags)
    return tags
end

function ProvenanceViewer:audit_computation_trace(snapshot_id, metric_name)
    local snapshot, snapshot_error = self:_get_snapshot(snapshot_id)
    if not snapshot then
        return nil, snapshot_error
    end

    if type(metric_name) ~= "string" or trim(metric_name) == "" then
        return nil, "metric_name must be a non-empty string."
    end

    for _, metric in ipairs(metric_entries(snapshot)) do
        if metric.name == metric_name then
            local trace = metric.computation_trace
            if type(trace) ~= "table" or #trace == 0 then
                return nil, "No computation trace is available for this metric."
            end

            local normalized_steps = {}
            for index, step in ipairs(trace) do
                if type(step) == "table" then
                    normalized_steps[#normalized_steps + 1] = {
                        step = index,
                        operation = normalize_text(step.operation, "Not declared"),
                        input_category = normalize_text(
                            step.input_category,
                            "Aggregate input"
                        ),
                        description = normalize_text(
                            step.description,
                            "No description provided."
                        ),
                        output = normalize_text(step.output, "Aggregate intermediate"),
                    }
                end
            end

            if #normalized_steps == 0 then
                return nil, "No valid computation trace steps are available."
            end

            return {
                snapshot_id = snapshot_id,
                metric_name = metric.name,
                definition = normalize_text(metric.definition, "No definition provided."),
                evidence_tags = normalize_evidence_tags(metric.evidence_tags),
                advisory_notice = normalize_text(
                    metric.advisory_notice,
                    self.default_advisory_notice
                ),
                steps = normalized_steps,
            }
        end
    end

    return nil, "Metric not found."
end

function ProvenanceViewer:render_provenance(snapshot_id, format)
    local snapshot, snapshot_error = self:_get_snapshot(snapshot_id)
    if not snapshot then
        return nil, snapshot_error
    end

    format = format or "html"
    if format ~= "html" and format ~= "text" then
        return nil, "format must be 'html' or 'text'."
    end

    local metrics = metric_entries(snapshot)
    local timestamp = snapshot_timestamp(snapshot)

    if format == "text" then
        local sections = {
            "DATA PROVENANCE",
            "Snapshot: " .. snapshot_id,
            "Timestamp: " .. timestamp,
            "",
            "Purpose",
            self.default_advisory_notice,
        }

        for _, metric in ipairs(metrics) do
            local sources = metric.source_categories or {}
            local limitations = metric.limitations or {}
            local tags = normalize_evidence_tags(metric.evidence_tags)

            sections[#sections + 1] = ""
            sections[#sections + 1] = "Metric: " .. metric.name
            sections[#sections + 1] = "Definition: "
                .. normalize_text(metric.definition, "No definition provided.")
            sections[#sections + 1] = "Source categories:"
            sections[#sections + 1] = list_items_text(sources)
            sections[#sections + 1] = "Evidence tags:"
            sections[#sections + 1] = list_items_text(tags)
            sections[#sections + 1] = "Limitations:"
            sections[#sections + 1] = list_items_text(limitations)
            sections[#sections + 1] = "Use limitation: "
                .. normalize_text(metric.advisory_notice, self.default_advisory_notice)
        end

        return table.concat(sections, "\n")
    end

    local sections = {
        '<section class="sad-provenance" aria-labelledby="sad-provenance-title">',
        '<h2 id="sad-provenance-title">Data provenance</h2>',
        "<p>This panel explains aggregate dashboard metrics, their declared source categories, evidence references, computation steps, and limitations.</p>",
        '<dl class="sad-provenance__metadata">',
        "<dt>Snapshot</dt><dd>" .. html_escape(snapshot_id) .. "</dd>",
        "<dt>Timestamp</dt><dd>" .. html_escape(timestamp) .. "</dd>",
        "</dl>",
        '<aside class="sad-provenance__advisory" aria-label="Advisory use notice">',
        "<strong>Advisory use only.</strong> " .. html_escape(self.default_advisory_notice),
        "</aside>",
    }

    if #metrics == 0 then
        sections[#sections + 1] = "<p>No metric provenance was declared for this snapshot.</p>"
    end

    for _, metric in ipairs(metrics) do
        local sources = metric.source_categories
        if type(sources) ~= "table" then
            sources = {}
        end

        local limitations = metric.limitations
        if type(limitations) ~= "table" then
            limitations = {}
        end

        local tags = normalize_evidence_tags(metric.evidence_tags)

        sections[#sections + 1] = '<article class="sad-provenance__metric">'
        sections[#sections + 1] = "<h3>" .. html_escape(metric.name) .. "</h3>"
        sections[#sections + 1] = "<p>"
            .. html_escape(normalize_text(metric.definition, "No definition provided."))
            .. "</p>"
        sections[#sections + 1] = "<h4>Source categories</h4>"
        sections[#sections + 1] = list_items_html(sources)
        sections[#sections + 1] = "<h4>Cryptographic evidence tags</h4>"
        sections[#sections + 1] = list_items_html(tags)
        sections[#sections + 1] = "<h4>Limitations</h4>"
        sections[#sections + 1] = list_items_html(limitations)
        sections[#sections + 1] = "<p><strong>Use limitation:</strong> "
            .. html_escape(
                normalize_text(metric.advisory_notice, self.default_advisory_notice)
            )
            .. "</p>"
        sections[#sections + 1] = "</article>"
    end

    sections[#sections + 1] = "</section>"
    return table.concat(sections, "\n")
end

return ProvenanceViewer
