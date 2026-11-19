-- Lua 5.4.
-- Local synthetic-pilot integration runner (CLI boundary).
--
-- Responsibilities:
--   * Establish the module search path relative to the supplied checkout.
--   * Load only the target cybermind modules.
--   * Distinguish load failure from test failure.
--   * Execute available self_test() suites under protected calls.
--   * Record runtime version and execution evidence.
--   * Execute the four added CyberCongress branch checks.
--   * Execute the baseline harness when present.
--   * Run one wired synthetic feedback/report fixture.
--   * Emit a minimized JSON validation report.
--   * Return an explicit process exit status.
--
-- No network access, no account access, no hardware control, no background
-- service, no repository discovery beyond the given checkout root.
-- Library modules stay free of process-exit behavior; only this runner exits.
--
-- Usage:
--   lua5.4 cybermind/run_synthetic_validation.lua
-- Optional overrides:
--   CYBERMIND_CHECKOUT_ROOT  checkout root (default: inferred from arg[0])
--   CYBERMIND_REPORT_PATH    report file  (default: <root>/cybermind/validation/
--                                          synthetic-validation-report.json)

local RUNNER_VERSION = "1.0.0"
local REPORT_SCHEMA_VERSION = "cybermind.synthetic-validation-report/1"
local ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local ATTRIBUTION_SCOPE =
    "Credit and workstream metadata only; not identity, consent, " ..
    "authorization, execution evidence, or authority."
local MIN_LUA_MINOR, MIN_LUA_RELEASE = 4, 7
local MAX_NESTING = 12
local MAX_STRING = 2048

local REQUIRED_MINIMUMS = {
    ["cybermind.research_manifest"] = {"manifest", "plan", "self_test"},
    ["cybermind.feedback_outcomes"] = {"dashboard", "retaliation_review",
                                        "self_test"},
    ["cybermind.synthetic_pilot_report"] = {"compile", "self_test"},
    ["cybermind.cybercongress_records"] = {"validate", "inspect", "example",
                                           "self_test"}
}
local OPTIONAL_MODULES = {"cybermind.synthetic_baseline_harness"}

-- ---------------------------------------------------------------- environment

local function shell_single_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function detect_root()
    local override = os.getenv("CYBERMIND_CHECKOUT_ROOT")
    if type(override) == "string" and #override > 0 then return override end
    local script = arg and arg[0]
    if type(script) == "string" then
        local dir = script:match("^(.*)/cybermind/[^/]*$")
        if dir then return dir end
    end
    return nil
end

local function path_join(a, b)
    if a:sub(-1) == "/" then return a .. b end
    return a .. "/" .. b
end

local function file_exists(path)
    local handle = io.open(path, "rb")
    if not handle then return false end
    handle:close()
    return true
end

local function deb_version_of(package_name)
    local pipe = io.popen("dpkg-query -W -f '${Version}' "
        .. shell_single_quote(package_name) .. " 2>/dev/null")
    if not pipe then return nil end
    local text = pipe:read("a") or ""
    pipe:close()
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if #text == 0 then return nil end
    return text
end

local function run_command_capture(command)
    local pipe = io.popen(command .. " 2>&1")
    if not pipe then return nil end
    local text = pipe:read("a")
    pipe:close()
    if type(text) ~= "string" then return nil end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Establish the patch level of the interpreter that is actually executing this
-- runner. _VERSION only identifies Lua 5.4, so re-invoke the discovered
-- interpreter binary and parse its banner; fall back to installation metadata.
local function detect_runtime()
    local info = {
        version_string = _VERSION,
        meets_minimum_requirement = false,
        patch_level_established = false,
        release = nil,
        patch_level_source = nil,
        interpreter_path = nil,
        script_path = arg and arg[0],
        candidate_executables = {},
        installation_metadata = {}
    }

    local major, minor = _VERSION:match("(%d+)%.(%d+)")
    info.major = tonumber(major)
    info.minor = tonumber(minor)

    local self_banner = nil
    local system_lua = run_command_capture("lua -v")
    if system_lua then info.system_banner_observed = system_lua end

    -- Establish the patch level from an interpreter banner of the same minor
    -- line, preferring the binary that is actually executing this script.
    local probe_order = {"/usr/local/bin/lua5.4", "/usr/bin/lua5.4",
                         "/usr/local/bin/lua", "/usr/bin/lua"}
    for _, candidate in ipairs(probe_order) do
        local output = run_command_capture(candidate .. " -v")
        if output then
            local banner_major, banner_minor, banner_release =
                output:match("Lua (%d+)%.(%d+)%.(%d+)")
            info.candidate_executables[#info.candidate_executables + 1] = {
                path = candidate,
                banner = output,
                version = banner_major and (banner_major .. "." .. banner_minor
                    .. "." .. banner_release) or "unparsed"
            }
            if banner_major and banner_minor == info.minor and self_banner == nil
                and info.release == nil then
                self_banner = output
                info.release = tonumber(banner_release)
                info.patch_level_source = "interpreter_banner"
                info.interpreter_path = candidate
            end
        end
    end

    if info.release == nil then
        local meta = deb_version_of("lua5.4")
        if meta then
            info.installation_metadata.dpkg_version_lua5_4 = meta
            local release = meta:match("^(%d+)%.(%d+)%.(%d+)")
            if release then
                info.release = tonumber(release)
                info.patch_level_source = "package_metadata"
            end
        end
    end

    info.banner_observed = self_banner

    if info.major == 5 and info.minor == MIN_LUA_MINOR then
        if info.release then
            info.patch_level_established = true
            info.meets_minimum_requirement = info.release >= MIN_LUA_RELEASE
        else
            info.meets_minimum_requirement = false
            info.minimum_status = "unknown_patch_level"
        end
    elseif info.major == 5 and info.minor and info.minor > MIN_LUA_MINOR then
        info.patch_level_established = true
        info.meets_minimum_requirement = true
    end
    return info
end

-- ------------------------------------------------------------------- JSON out

local json_escape_cache = {}
for i = 0, 31 do
    json_escape_cache[i] = string.format("\\u%04x", i)
end
json_escape_cache[34] = '\\"'
json_escape_cache[92] = "\\\\"

local function json_encode(value, indent, depth)
    depth = depth or 0
    if depth > MAX_NESTING then error("json nesting limit", 0) end
    local kind = type(value)

    if value == nil then return "null" end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("non-finite number in report", 0)
        end
        if math.type(value) == "integer" then return tostring(value) end
        return string.format("%.6g", value)
    end
    if kind == "string" then
        if #value > MAX_STRING then error("report string too long", 0) end
        local escaped = value:gsub("[%z\1-\31\34\92]", function(byte)
            return json_escape_cache[string.byte(byte)]
        end)
        return '"' .. escaped .. '"'
    end
    if kind == "table" then
        local pad = string.rep("  ", indent + 1)
        local closing_pad = string.rep("  ", indent)
        local is_array = true
        local count = 0
        for key in next, value do
            count = count + 1
            if type(key) ~= "number" or math.type(key) ~= "integer" or key < 1
                or key ~= count then
                is_array = false
            end
        end
        if count == 0 then
            if rawget(value, 1) ~= nil or next(value) == nil then return "{}" end
        end
        local parts = {}
        if is_array and count > 0 then
            for index = 1, count do
                parts[#parts + 1] = pad .. json_encode(value[index], indent + 1,
                    depth + 1)
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. closing_pad .. "]"
        end
        if not is_array then
            local names = {}
            for key in next, value do
                if type(key) ~= "string" then error("non-string object key", 0) end
                names[#names + 1] = key
            end
            table.sort(names)
            for _, name in ipairs(names) do
                parts[#parts + 1] = pad .. json_encode(name, indent + 1, depth + 1)
                    .. ": " .. json_encode(value[name], indent + 1, depth + 1)
            end
            if #parts == 0 then return "{}" end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. closing_pad .. "}"
        end
        return "{}"
    end
    error("unsupported type in report: " .. kind, 0)
end

-- --------------------------------------------------------------- module state

local loaded_modules = {}
local missing_paths = {}
local load_failures = {}
local interface_discrepancies = {}

local MODULE_FILES = {
    ["cybermind.research_manifest"] = "cybermind/research_manifest.lua",
    ["cybermind.feedback_outcomes"] = "cybermind/feedback_outcomes.lua",
    ["cybermind.synthetic_pilot_report"] = "cybermind/synthetic_pilot_report.lua",
    ["cybermind.cybercongress_records"] = "cybermind/cybercongress_records.lua",
    ["cybermind.synthetic_baseline_harness"] =
        "cybermind/synthetic_baseline_harness.lua"
}

local function normalize_error(err)
    if type(err) == "table" and type(err.code) == "string" then
        return {code = err.code, path = err.path, message = err.message}
    end
    if type(err) == "string" then
        return {code = "UNSTRUCTURED_ERROR", message = err}
    end
    return {code = "UNSTRUCTURED_ERROR", message = "Non-descript failure"}
end

local function describe_value(value)
    if type(value) == "number" then
        if value ~= value then return "nan" end
        if value == math.huge then return "inf" end
        if value == -math.huge then return "-inf" end
        return tostring(value)
    end
    if type(value) == "string" then return "string" end
    return type(value)
end

local function load_targets(root)
    package.path = path_join(root, "?.lua")
        .. ";" .. path_join(root, "cybermind/?.lua")
        .. ";" .. package.path

    for _, name in ipairs({"cybermind.research_manifest",
                           "cybermind.feedback_outcomes",
                           "cybermind.cybercongress_records",
                           "cybermind.synthetic_pilot_report",
                           "cybermind.synthetic_baseline_harness"}) do
        local relative = MODULE_FILES[name]
        if not file_exists(path_join(root, relative)) then
            missing_paths[#missing_paths + 1] = relative
        else
            local ok, result = pcall(require, name)
            if ok and type(result) == "table" then
                loaded_modules[name] = result
            else
                load_failures[#load_failures + 1] = {
                    module = name, file = relative,
                    error = normalize_error(result)
                }
            end
        end
    end

    for name, minimums in pairs(REQUIRED_MINIMUMS) do
        local module = loaded_modules[name]
        if module then
            for _, function_name in ipairs(minimums) do
                if type(module[function_name]) ~= "function" then
                    interface_discrepancies[#interface_discrepancies + 1] = {
                        module = name, export = function_name,
                        observed_type = type(module[function_name]),
                        disposition = "no_adapter_applicable"
                    }
                end
            end
        end
    end

    local harness = loaded_modules["cybermind.synthetic_baseline_harness"]
    if harness and type(harness.run) ~= "function" then
        interface_discrepancies[#interface_discrepancies + 1] = {
            module = "cybermind.synthetic_baseline_harness", export = "run",
            observed_type = type(harness.run),
            disposition = "no_adapter_applicable"
        }
    end
end

-- ------------------------------------------------------------------- tracking

local tracker = {records = {}}

local function add_record(entry)
    tracker.records[#tracker.records + 1] = entry
    return entry
end

local function suite(kind, name, subject, operation)
    local entry = {
        kind = kind,
        name = name,
        subject = subject,
        expected_result = "returned_true_without_error",
        executed = false,
        classification = "not_executed"
    }
    if type(operation) ~= "function" then
        entry.observed_result = "dependency_unavailable"
        entry.limitation = "Required module or export absent; dependent check "
            .. "marked not_executed rather than passed."
        return add_record(entry)
    end
    local ok, result, err = pcall(operation)
    entry.executed = true
    if ok and result == true then
        entry.observed_result = "returned_true"
        entry.classification = "matched_expectation"
    elseif ok then
        entry.observed_result = "returned_" .. describe_value(result)
        entry.classification = "differed_from_expectation"
    else
        entry.observed_result = "raised_error"
        entry.error = normalize_error(err)
        entry.classification = "differed_from_expectation"
    end
    return add_record(entry)
end

local function expect_rejection(name, subject, expected_code, call)
    local entry = {
        kind = "branch_check",
        name = name,
        subject = subject,
        expected_result = {outcome = "nil_with_structured_error",
                           code = expected_code},
        executed = false,
        classification = "not_executed"
    }
    if call == nil then
        entry.observed_result = "dependency_unavailable"
        entry.limitation = "Required module or export absent; check not "
            .. "executed and not counted as a passed resilience test."
        return add_record(entry)
    end
    local ok, result, err = pcall(call)
    entry.executed = true
    if not ok then
        entry.observed_result = "unexpected_runner_failure"
        entry.error = normalize_error(result)
        entry.classification = "inconclusive"
        return add_record(entry)
    end
    if result == nil and type(err) == "table" and err.code == expected_code then
        entry.observed_result = {outcome = "nil_with_structured_error",
                                 code = expected_code, path = err.path}
        entry.classification = "matched_expectation"
    elseif result == nil then
        entry.observed_result = {outcome = "nil_with_structured_error",
                                 code = type(err) == "table" and err.code
                                     or describe_value(err)}
        entry.classification = "differed_from_expectation"
    else
        entry.observed_result = {outcome = "record_accepted",
                                 code = "NO_REJECTION"}
        entry.classification = "differed_from_expectation"
    end
    return add_record(entry)
end

local function expect_value(name, subject, expected, actual, note)
    local entry = {
        kind = "fixture_assertion",
        name = name,
        subject = subject,
        expected_result = expected,
        executed = actual ~= nil,
        observed_result = actual,
        classification = "not_executed"
    }
    if entry.executed then
        entry.classification =
            (type(expected) == type(actual) and expected == actual)
            and "matched_expectation" or "differed_from_expectation"
    end
    entry.note = note
    return add_record(entry)
end

local function expect_acceptance(name, subject, call)
    local entry = {
        kind = "branch_check",
        name = name,
        subject = subject,
        expected_result = {outcome = "record_accepted"},
        executed = false,
        classification = "not_executed"
    }
    if call == nil then
        entry.observed_result = "dependency_unavailable"
        entry.limitation = "Required module or export absent; check not "
            .. "executed and not counted as a passed resilience test."
        return add_record(entry)
    end
    local ok, result, err = pcall(call)
    entry.executed = true
    if not ok then
        entry.observed_result = "unexpected_runner_failure"
        entry.error = normalize_error(result)
        entry.classification = "inconclusive"
        return add_record(entry)
    end
    if result ~= nil and type(result) == "table" then
        entry.observed_result = {outcome = "record_accepted",
                                 code = "NO_REJECTION"}
        entry.classification = "matched_expectation"
    else
        entry.observed_result = {outcome = "nil_with_structured_error",
                                 code = type(err) == "table" and err.code
                                     or describe_value(err)}
        entry.classification = "differed_from_expectation"
    end
    return add_record(entry)
end

-- -------------------------------------------------------- CyberCongress checks

local records_module = nil

local function fresh(record_type)
    local example = records_module and records_module.example
    if type(example) ~= "function" then return nil end
    local ok, result = pcall(example, record_type)
    if ok and type(result) == "table" then return result end
    return nil
end

local function guarded_validate(record)
    if records_module == nil or type(records_module.validate) ~= "function" then
        return nil
    end
    return function() return records_module.validate(record) end
end

local function run_congress_branch_checks()
    if records_module == nil then
        -- Record each dependent check as not executed rather than skipping it.
        local subjects = {
            {"Synthetic environment with participant-report origin",
             "ENVIRONMENT_CONFLICT"},
            {"Public-summary eligibility without recorded permission",
             "PUBLIC_SUMMARY_PERMISSION_REQUIRED"},
            {"Decision timestamp before complaint receipt",
             "DECISION_TIME_ORDER"},
            {"Revoked mandate with recommendation disposition",
             "REVIEW_ASSERTIONS_REQUIRED"}
        }
        for _, pair in ipairs(subjects) do
            expect_rejection(pair[1],
                "cybermind.cybercongress_records.validate(record)",
                pair[2], nil)
        end
        expect_acceptance(
            "Untouched review-decision example remains valid (control)",
            "cybermind.cybercongress_records.validate(review_decision)", nil)
        return
    end

    -- 1. Synthetic origin mismatch.
    local complaint = fresh("complaint")
    if complaint then
        complaint.environment = "synthetic"
        complaint.origin = "participant_report"
    end
    expect_rejection(
        "Synthetic environment with participant-report origin",
        "cybermind.cybercongress_records.validate(complaint)",
        "ENVIRONMENT_CONFLICT",
        complaint and guarded_validate(complaint))

    -- 2. Public-summary eligibility without recorded permission.
    local decision = fresh("review_decision")
    if decision then
        decision.independence = "cleared"
        decision.mandate = "verified_assertion"
        decision.publication_status = "eligible_for_separate_approval"
        decision.disposition = "nonbinding_recommendation"
        decision.complaint.privacy.allow_public_summary = false
    end
    expect_rejection(
        "Public-summary eligibility without recorded permission",
        "cybermind.cybercongress_records.validate(review_decision)",
        "PUBLIC_SUMMARY_PERMISSION_REQUIRED",
        decision and guarded_validate(decision))

    -- 3. Decision recorded before complaint receipt.
    decision = fresh("review_decision")
    if decision then
        decision.recorded_at_unix_s = decision.complaint.received_at_unix_s - 1
    end
    expect_rejection(
        "Decision timestamp before complaint receipt",
        "cybermind.cybercongress_records.validate(review_decision)",
        "DECISION_TIME_ORDER",
        decision and guarded_validate(decision))

    -- 4. Revoked mandate with recommendation disposition.
    decision = fresh("review_decision")
    if decision then
        decision.independence = "cleared"
        decision.mandate = "revoked"
        decision.disposition = "nonbinding_recommendation"
    end
    expect_rejection(
        "Revoked mandate with recommendation disposition",
        "cybermind.cybercongress_records.validate(review_decision)",
        "REVIEW_ASSERTIONS_REQUIRED",
        decision and guarded_validate(decision))

    -- Positive control: an untouched fresh example must validate. This guards
    -- against the added fixtures failing for unintended reasons.
    local control = fresh("review_decision")
    expect_acceptance(
        "Untouched review-decision example remains valid (control)",
        "cybermind.cybercongress_records.validate(review_decision)",
        guarded_validate(control))
end

-- ------------------------------------------------------- synthetic pilot fixture

local fixture_state = {}

-- Returns value, error with the same shape as the protected module functions,
-- or nil plus a structured runner error when the call itself breaks.
local function invoke(protected_call, ...)
    if type(protected_call) ~= "function" then return nil end
    local ok, first, second = pcall(protected_call, ...)
    if not ok then
        return nil, {code = "RUNNER_CALL_FAILURE", path = "runner",
                     message = tostring(first)}
    end
    return first, second
end

local function run_synthetic_fixture()
    local feedback = loaded_modules["cybermind.feedback_outcomes"]
    local report = loaded_modules["cybermind.synthetic_pilot_report"]

    local feedback_records = {{
        received_at = 100,
        acknowledgement_due_at = 110,
        acknowledged_at = 105,
        disclosure_review = "not_reviewed"
    }}
    local actions = {{
        accepted_at = 106,
        original_due_at = 120,
        completed_at = 115,
        verification = "unknown",
        benefit = "not_assessed"
    }}
    local cutoff = 130
    -- Empty readiness input: no research check is claimed established merely
    -- because this runner exists.
    local readiness_records = {}

    fixture_state.input = {
        timestamp_unit = "caller-defined integer unit, single scale",
        feedback_records = feedback_records,
        actions = actions,
        cutoff = cutoff,
        readiness_records = readiness_records
    }

    local dashboard_fn = nil
    if feedback and type(feedback.dashboard) == "function" then
        dashboard_fn = feedback.dashboard
    end
    local dashboard, dashboard_err = invoke(dashboard_fn,
        feedback_records, actions, cutoff)
    if dashboard_err then
        fixture_state.dashboard_error = normalize_error(dashboard_err)
    end

    if type(dashboard) ~= "table" then
        expect_value("Synthetic dashboard produced a result",
            "cybermind.feedback_outcomes.dashboard", "table",
            dashboard == nil and "absent" or describe_value(dashboard),
            "Dashboard unavailable; dependent fixture assertions carry no "
            .. "execution evidence.")
        fixture_state.dashboard_values = nil
        return
    end

    local function metric(name)
        local entry = dashboard[name]
        if type(entry) ~= "table" then return nil end
        return {numerator = entry.numerator, denominator = entry.denominator,
                status = entry.status, value = entry.value}
    end

    local ack = metric("acknowledgement_on_time")
    local verified = metric("verified_completion_of_due_actions")
    local disclosure = metric("disclosure_review_coverage")
    local unnecessary = metric("unnecessary_disclosure_incidence_among_reviewed")
    local benefit_coverage = metric("benefit_assessment_coverage")
    local benefit_support = metric("benefit_support_among_assessed")

    fixture_state.dashboard_values = {
        acknowledgement_on_time = ack,
        verified_completion_of_due_actions = verified,
        disclosure_review_coverage = disclosure,
        unnecessary_disclosure_incidence_among_reviewed = unnecessary,
        benefit_assessment_coverage = benefit_coverage,
        benefit_support_among_assessed = benefit_support
    }

    local subject = "cybermind.feedback_outcomes.dashboard(synthetic cohort)"
    expect_value("One acknowledgement due",
        subject .. ".acknowledgement_on_time.denominator", 1,
        ack and ack.denominator)
    expect_value("One acknowledgement on time",
        subject .. ".acknowledgement_on_time.numerator", 1,
        ack and ack.numerator)
    expect_value("One action due",
        subject .. ".verified_completion_of_due_actions.denominator", 1,
        verified and verified.denominator)
    expect_value("Zero actions counted as verified completion",
        subject .. ".verified_completion_of_due_actions.numerator", 0,
        verified and verified.numerator)
    expect_value("Disclosure-review coverage numerator zero for cohort",
        subject .. ".disclosure_review_coverage.numerator", 0,
        disclosure and disclosure.numerator)
    expect_value("Benefit among assessed not estimable",
        subject .. ".benefit_support_among_assessed.status",
        "not_estimable", benefit_support and benefit_support.status)
    expect_value("Benefit-assessment coverage numerator zero",
        subject .. ".benefit_assessment_coverage.numerator", 0,
        benefit_coverage and benefit_coverage.numerator)
    expect_value("Metric fields are records, not booleans",
        subject .. ".metric_shape", "table",
        type(dashboard.acknowledgement_on_time))

    -- Aggregate report over the same raw arrays (raw records, not precomputed).
    local compile_fn = nil
    if report and type(report.compile) == "function" then
        compile_fn = report.compile
    end
    local compiled, compile_err = invoke(compile_fn, {
        readiness_records = readiness_records,
        feedback_records = feedback_records,
        actions = actions,
        cutoff = cutoff,
        adversarial_results = {}
    })
    if compile_err then
        fixture_state.report_error = normalize_error(compile_err)
    end
    if type(compiled) == "table" then
        fixture_state.aggregate_report = compiled
    end

    local report_subject =
        "cybermind.synthetic_pilot_report.compile(raw synthetic arrays)"
    expect_value("Aggregate report compiled", report_subject, "table",
        type(compiled) == "table" and "table"
            or (compiled == nil and "absent" or describe_value(compiled)))
    expect_value("Publication authority remains none",
        report_subject .. ".publication_authority", "none",
        compiled and compiled.publication_authority)
    expect_value("Execution authority remains none",
        report_subject .. ".execution_authority", "none",
        compiled and compiled.execution_authority)
    expect_value("All fifty topics retain recorded readiness gaps",
        report_subject .. ".readiness.topics_with_gaps", 50,
        compiled and compiled.readiness
        and compiled.readiness.topics_with_gaps)
    expect_value("Recorded readiness gaps remain visible",
        report_subject .. ".readiness.recorded_gaps", 400,
        compiled and compiled.readiness
        and compiled.readiness.recorded_gaps)
    expect_value("No declared exemptions from empty readiness input",
        report_subject .. ".readiness.declared_exemptions", 0,
        compiled and compiled.readiness
        and compiled.readiness.declared_exemptions)
    expect_value("Verified completion stays zero of one in the report",
        report_subject .. ".feedback_metrics.verified_completion.numerator", 0,
        compiled and compiled.feedback_metrics
        and compiled.feedback_metrics.verified_completion
        and compiled.feedback_metrics.verified_completion.numerator)
    expect_value("Verified completion denominator stays one in the report",
        report_subject .. ".feedback_metrics.verified_completion.denominator", 1,
        compiled and compiled.feedback_metrics
        and compiled.feedback_metrics.verified_completion
        and compiled.feedback_metrics.verified_completion.denominator)
    expect_value("Acknowledgement metric carried into the report",
        report_subject .. ".feedback_metrics.acknowledgement_on_time.numerator",
        1, compiled and compiled.feedback_metrics
        and compiled.feedback_metrics.acknowledgement_on_time
        and compiled.feedback_metrics.acknowledgement_on_time.numerator)
    expect_value("No participant narrative field introduced",
        report_subject .. ".summary", "absent",
        compiled and (compiled.summary == nil and "absent" or "present") or nil)
    expect_value("No private payload field introduced",
        report_subject .. ".private_content", "absent",
        compiled and (compiled.private_content == nil
            and "absent" or "present") or nil)
    expect_value("No neural data field introduced",
        report_subject .. ".neural_recording", "absent",
        compiled and (compiled.neural_recording == nil
            and "absent" or "present") or nil)
    expect_value("Supplied-results counter reports none supplied",
        report_subject .. ".test_summary", "no_adversarial_results_supplied",
        compiled and compiled.test_summary)
end

-- ------------------------------------------------------------ source binding

local function sha256_hex(text)
    -- FIPS 180-4 SHA-256 over an in-memory byte string, using native Lua 5.4
    -- integer arithmetic. Used only as a local integrity aid; no external
    -- service, no new dependency, and not an authenticated attestation.
    local H = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
               0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19}
    local K = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
        0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
        0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
        0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
        0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
        0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    }
    local MASK = 0xFFFFFFFF

    local function mask32(x) return x % 4294967296 end
    local function rotr(x, n)
        x = mask32(x)
        return (x >> n) | ((x << (32 - n)) & MASK)
    end

    local length_bits = #text * 8
    local padded = text .. "\1"
    while #padded % 64 ~= 56 do padded = padded .. "\0" end
    local high = mask32(length_bits // 2 ^ 32)
    local low = mask32(length_bits)
    local function word_bytes(word)
        return string.char(
            (word >> 24) & 0xff, (word >> 16) & 0xff,
            (word >> 8) & 0xff, word & 0xff)
    end
    padded = padded .. word_bytes(high) .. word_bytes(low)

    for start = 1, #padded, 64 do
        local w = {}
        for i = 0, 15 do
            local p = start + i * 4
            w[i] = ((string.byte(padded, p) << 24)
                | (string.byte(padded, p + 1) << 16)
                | (string.byte(padded, p + 2) << 8)
                | string.byte(padded, p + 3)) & MASK
        end
        for i = 16, 63 do
            local s0 = rotr(w[i - 15], 7) ~ rotr(w[i - 15], 18)
                ~ (w[i - 15] >> 3)
            local s1 = rotr(w[i - 2], 17) ~ rotr(w[i - 2], 19)
                ~ (w[i - 2] >> 10)
            w[i] = mask32(w[i - 16] + s0 + w[i - 7] + s1)
        end

        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4],
                                       H[5], H[6], H[7], H[8]
        for i = 0, 63 do
            local S1 = rotr(e, 6) ~ rotr(e, 11) ~ rotr(e, 25)
            local ch = (e & f) ~ ((~e & MASK) & g)
            local t1 = mask32(h + S1 + ch + K[i + 1] + w[i])
            local S0 = rotr(a, 2) ~ rotr(a, 13) ~ rotr(a, 22)
            local maj = (a & b) ~ (a & c) ~ (b & c)
            local t2 = mask32(S0 + maj)
            h, g, f, e = g, f, e, mask32(d + t1)
            d, c, b, a = d, c, b, mask32(a + t1 + t2)
        end
        H[1] = mask32(H[1] + a); H[2] = mask32(H[2] + b)
        H[3] = mask32(H[3] + c); H[4] = mask32(H[4] + d)
        H[5] = mask32(H[5] + e); H[6] = mask32(H[6] + f)
        H[7] = mask32(H[7] + g); H[8] = mask32(H[8] + h)
    end

    local out = {}
    for i = 1, 8 do out[#out + 1] = string.format("%08x", H[i]) end
    return table.concat(out)
end

local function read_file_bytes(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local content = handle:read("a")
    handle:close()
    return content
end

local TARGET_SOURCE_FILES = {
    "cybermind/research_manifest.lua",
    "cybermind/feedback_outcomes.lua",
    "cybermind/cybercongress_records.lua",
    "cybermind/synthetic_pilot_report.lua",
    "cybermind/synthetic_baseline_harness.lua",
    "cybermind/run_synthetic_validation.lua"
}

local function compute_source_binding(root)
    local entries = {}
    local any_missing = false
    for _, relative in ipairs(TARGET_SOURCE_FILES) do
        local content = read_file_bytes(path_join(root, relative))
        if content == nil then
            any_missing = true
        else
            entries[#entries + 1] = {file = relative,
                                     sha256 = sha256_hex(content),
                                     bytes = #content}
        end
    end
    if #entries == 0 then return nil end
    local concatenated = {}
    for _, entry in ipairs(entries) do
        concatenated[#concatenated + 1] = entry.file .. "=" .. entry.sha256
    end
    return {
        status = "computed_locally",
        method = "pure-Lua FIPS 180-4 SHA-256 implemented inside this runner; "
            .. "no project-approved digest toolchain was available to invoke",
        files = entries,
        aggregate_digest_sha256 = sha256_hex(table.concat(concatenated, "\n")),
        incomplete = any_missing,
        limitation = "Local integrity aid computed over the bytes loaded in "
            .. "this session; not an authenticated or project-approved "
            .. "source attestation."
    }
end

-- ------------------------------------------------------------------- reporting

local function classify_counts()
    local counts = {executed = 0, matched_expectation = 0,
                    differed_from_expectation = 0, not_executed = 0,
                    inconclusive = 0, total_records = #tracker.records}
    for _, record in ipairs(tracker.records) do
        if record.executed then counts.executed = counts.executed + 1 end
        counts[record.classification] = counts[record.classification] + 1
    end
    return counts
end

local function build_harness_section()
    local harness = loaded_modules["cybermind.synthetic_baseline_harness"]
    if not harness or type(harness.run) ~= "function" then
        add_record({
            kind = "harness_suite",
            name = "Baseline harness contract suite",
            subject = "cybermind.synthetic_baseline_harness.run",
            expected_result = "all_internal_tests_passed",
            executed = false,
            observed_result = "dependency_unavailable",
            classification = "not_executed",
            limitation = "Harness module absent or failed to load; not treated "
                .. "as a passed resilience test."
        })
        return nil
    end
    local entry = add_record({
        kind = "harness_suite",
        name = "Baseline harness contract suite",
        subject = "cybermind.synthetic_baseline_harness.run",
        expected_result = "all_internal_tests_passed",
        executed = false,
        classification = "not_executed"
    })
    local ok, result = pcall(harness.run, {
        research = loaded_modules["cybermind.research_manifest"],
        feedback = loaded_modules["cybermind.feedback_outcomes"],
        report = loaded_modules["cybermind.synthetic_pilot_report"]
    })
    entry.executed = true
    if not ok then
        entry.observed_result = "runner_failure"
        entry.error = normalize_error(result)
        entry.classification = "inconclusive"
        return nil
    end
    if type(result) ~= "table" then
        entry.observed_result = "malformed_harness_result"
        entry.classification = "differed_from_expectation"
        return nil
    end
    entry.internal_count = result.executed_count
    entry.internal_passed = result.passed_count
    entry.internal_failed = result.failed_count
    local failures = {}
    for _, test in ipairs(result.tests or {}) do
        if test.result ~= "passed" then
            failures[#failures + 1] = {name = test.name,
                                      error_code = test.error_code}
        end
    end
    entry.internal_failures = failures
    entry.observed_result = {
        executed_count = result.executed_count,
        passed_count = result.passed_count,
        failed_count = result.failed_count
    }
    entry.classification = (result.executed_count or 0) > 0
        and (result.failed_count == 0) and "matched_expectation"
        or "differed_from_expectation"
    return result
end

local function summarize_aggregate()
    local report = fixture_state.aggregate_report
    if type(report) ~= "table" then return nil end
    local metrics = report.feedback_metrics or {}
    local verified = metrics.verified_completion or {}
    return {
        publication_authority = report.publication_authority,
        execution_authority = report.execution_authority,
        test_summary = report.test_summary,
        readiness = report.readiness,
        verified_completion = {numerator = verified.numerator,
                               denominator = verified.denominator,
                               status = verified.status},
        scope = report.scope
    }
end

-- -------------------------------------------------------------------- main

local function main()
    local root = detect_root()
    if type(root) ~= "string" or #root == 0 then
        io.stderr:write("runner-input-error: checkout root undetermined\n")
        return 3
    end
    if not file_exists(path_join(root, "cybermind/research_manifest.lua")) then
        io.stderr:write("runner-input-error: cybermind modules not found at "
            .. root .. "\n")
        return 3
    end

    local runtime = detect_runtime()
    load_targets(root)
    records_module = loaded_modules["cybermind.cybercongress_records"]

    -- Suite invocations (one record per self_test() call, not per internal
    -- assertion).
    local suite_order = {
        {"cybermind.research_manifest", "Research manifest self-test suite"},
        {"cybermind.feedback_outcomes", "Feedback outcomes self-test suite"},
        {"cybermind.cybercongress_records",
         "CyberCongress records self-test suite"},
        {"cybermind.synthetic_pilot_report",
         "Synthetic pilot report self-test suite"}
    }
    for _, pair in ipairs(suite_order) do
        local module = loaded_modules[pair[1]]
        local operation = nil
        if module and type(module.self_test) == "function" then
            operation = function() return module.self_test() end
        end
        suite("suite", pair[2], pair[1] .. ".self_test()", operation)
    end

    run_congress_branch_checks()

    local harness_result = build_harness_section()

    run_synthetic_fixture()

    local counts = classify_counts()
    local source_binding = compute_source_binding(root)

    local residual_limitations = {
        "Fixture uses synthetic numeric timestamps in one caller-defined unit; "
            .. "no calendar-time semantics tested.",
        "The synthetic fixture does not test expression approval, retaliation, "
            .. "anonymization, or end-to-end accessibility.",
        "Readiness plan output describes supplied assertions and gaps only; it "
            .. "does not authorize launch.",
        "Metrics are descriptive supplied-cohort counts; no causal, trust, or "
            .. "legal-compliance finding.",
        "Self-test suites are recorded as single suite results; internal "
            .. "assertion counts are not exposed by the modules.",
        "Source binding is computed by a pure-Lua SHA-256 inside the runner; "
            .. "it is a local integrity aid, not an authenticated or "
            .. "project-approved attestation."
    }
    if not runtime.patch_level_established then
        residual_limitations[#residual_limitations + 1] =
            "Lua patch level could not be established from the running "
            .. "interpreter; the 5.4.7-or-later requirement is unverified."
    end
    if #missing_paths > 0 then
        residual_limitations[#residual_limitations + 1] =
            "Missing target modules prevented dependent checks: "
            .. table.concat(missing_paths, ", ")
    end
    if harness_result then
        residual_limitations[#residual_limitations + 1] =
            "Baseline harness covers only local supplied-module contracts; its "
            .. "own broader_safeguards_not_established list remains open."
    end

    local required_present = true
    for name in pairs(REQUIRED_MINIMUMS) do
        if not loaded_modules[name] then required_present = false end
    end
    local interfaces_complete = #interface_discrepancies == 0

    local status, exit_code
    if not runtime.meets_minimum_requirement then
        status = "blocked_runtime"
        exit_code = 2
    elseif counts.differed_from_expectation > 0 then
        status = "failed"
        exit_code = 1
    elseif #load_failures > 0 or #missing_paths > 0 or not required_present then
        status = "blocked"
        exit_code = 2
    elseif not interfaces_complete or counts.not_executed > 0
        or counts.inconclusive > 0 then
        status = "blocked_interface"
        exit_code = 2
    else
        status = "passed"
        exit_code = 0
    end

    local report_table = {
        report_schema_version = REPORT_SCHEMA_VERSION,
        runner_version = RUNNER_VERSION,
        attribution = ATTRIBUTION,
        attribution_scope = ATTRIBUTION_SCOPE,
        scope = "synthetic_local_only",
        scope_detail = "Local wiring and verification of supplied synthetic "
            .. "fixtures only; no institution deployment, no launch approval, "
            .. "no claim that the wider CyberCongress system is validated.",
        verification_basis = "executed_and_recorded",
        verification_basis_detail = "Applies to the recorded results below; "
            .. "records marked not_executed carry no execution evidence.",
        runtime = {
            version_string = runtime.version_string,
            major = runtime.major,
            minor = runtime.minor,
            release = runtime.release,
            patch_level_established = runtime.patch_level_established,
            patch_level_source = runtime.patch_level_source,
            required_minimum = "5.4.7",
            meets_required_minimum = runtime.meets_minimum_requirement,
            interpreter_path = runtime.interpreter_path,
            script_path = runtime.script_path,
            banner_observed = runtime.banner_observed,
            installation_metadata = runtime.installation_metadata,
            candidate_executables = runtime.candidate_executables
        },
        modules = {
            loaded = (function()
                local names = {}
                for name in next, loaded_modules do names[#names + 1] = name end
                table.sort(names)
                return names
            end)(),
            missing = missing_paths,
            load_failures = load_failures,
            interface_discrepancies = interface_discrepancies
        },
        results = (function()
            local cleaned = {}
            for index, record in ipairs(tracker.records) do
                cleaned[index] = {
                    kind = record.kind,
                    name = record.name,
                    subject = record.subject,
                    expected_result = record.expected_result,
                    executed = record.executed,
                    observed_result = record.observed_result,
                    classification = record.classification,
                    error = record.error,
                    note = record.note,
                    limitation = record.limitation,
                    internal_count = record.internal_count,
                    internal_passed = record.internal_passed,
                    internal_failed = record.internal_failed,
                    internal_failures = record.internal_failures
                }
            end
            return cleaned
        end)(),
        counts = counts,
        synthetic_dashboard = fixture_state.dashboard_values,
        aggregate_report = summarize_aggregate(),
        harness_result_available = harness_result ~= nil,
        source_binding = source_binding or {
            status = "not_computed",
            reason = "Target module bytes were unreadable in this session; "
                .. "no digest is claimed."
        },
        residual_limitations = residual_limitations,
        status = status,
        exit_code = exit_code,
        publication_authority = "none"
    }

    local encoded, encode_error = pcall(json_encode, report_table, 0, 0)
    if not encoded then
        io.stderr:write("serialization-error: "
            .. tostring(encode_error) .. "\n")
        return 3
    end

    local report_path = os.getenv("CYBERMIND_REPORT_PATH")
    if type(report_path) ~= "string" or #report_path == 0 then
        report_path = path_join(root,
            "cybermind/validation/synthetic-validation-report.json")
    end
    local directory = report_path:match("^(.*)/[^/]+$")
    if directory then
        os.execute("mkdir -p " .. shell_single_quote(directory)
            .. " >/dev/null 2>&1")
    end
    local handle = io.open(report_path, "wb")
    if not handle then
        io.stderr:write("serialization-error: cannot write report at "
            .. report_path .. "\n")
        return 3
    end
    handle:write(encode_error)
    handle:write("\n")
    handle:close()

    io.write("cybermind synthetic validation: ", status,
        " (exit ", tostring(exit_code), ")",
        " executed=", tostring(counts.executed),
        " matched=", tostring(counts.matched_expectation),
        " differed=", tostring(counts.differed_from_expectation),
        " not_executed=", tostring(counts.not_executed),
        " inconclusive=", tostring(counts.inconclusive), "\n")
    io.write("report: ", report_path, "\n")
    return exit_code
end

local ok, status_or_error = pcall(main)
if not ok then
    io.stderr:write("runner-infrastructure-error: "
        .. tostring(status_or_error) .. "\n")
    os.exit(3)
end
os.exit(status_or_error)
