#!/usr/bin/env lua
-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/offline_policy_self_test.lua
-- Purpose: Self-test script for offline policy utilities

-- Set up module path
local function add_to_path(path)
    package.path = path .. "/?.lua;" .. path .. "/?/init.lua;" .. package.path
end

add_to_path("/workspace/lua")

-- Load modules
local PolicyMessageNormalizer = require("lua.tools.policy_message_normalizer")
local AssistiveClarificationRouter = require("lua.tools.assistive_clarification_router")
local EcoAccessAssessor = require("lua.eco_restoration.normalized_eco_access_assessor")

local tests_passed = 0
local tests_failed = 0

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        io.stderr:write(string.format("FAIL: %s\n", message or "Assertion failed"))
        io.stderr:write(string.format("  Expected: %s\n", tostring(expected)))
        io.stderr:write(string.format("  Got: %s\n", tostring(actual)))
        tests_failed = tests_failed + 1
        return false
    end
    tests_passed = tests_passed + 1
    return true
end

local function assert_true(condition, message)
    if not condition then
        io.stderr:write(string.format("FAIL: %s\n", message or "Assertion failed"))
        tests_failed = tests_failed + 1
        return false
    end
    tests_passed = tests_passed + 1
    return true
end

local function assert_table_contains_key(tbl, key, message)
    if tbl[key] == nil then
        io.stderr:write(string.format("FAIL: %s\n", message or "Table missing key"))
        tests_failed = tests_failed + 1
        return false
    end
    tests_passed = tests_passed + 1
    return true
end

local function assert_in_range(value, min_val, max_val, message)
    if value < min_val or value > max_val then
        io.stderr:write(string.format("FAIL: %s\n", message or "Value out of range"))
        io.stderr:write(string.format("  Expected: [%f, %f]\n", min_val, max_val))
        io.stderr:write(string.format("  Got: %f\n", value))
        tests_failed = tests_failed + 1
        return false
    end
    tests_passed = tests_passed + 1
    return true
end

print("================================================================================")
print("OFFLINE POLICY UTILITIES SELF-TEST")
print("================================================================================")
print("")

-- Test 1: Vague message returns needs_clarification
print("Test 1: Vague message 'Can I get that thing?' returns needs_clarification")
local vague_message = "Can I get that thing?"
local decision1 = AssistiveClarificationRouter.make_assistive_decision(vague_message)
assert_eq(decision1.status, "needs_clarification", "Vague message should need clarification")

-- Test 2: Mobility message routes to mobility_access
print("Test 2: Mobility message routes to mobility_access")
local mobility_message = "I need information about accessible corridor width and wheelchair passage"
local topic2, confidence2 = AssistiveClarificationRouter.route_topic(mobility_message)
assert_eq(topic2, "mobility_access", "Mobility message should route to mobility_access")
assert_true(confidence2 > 0, "Confidence should be positive")

-- Test 3: Privacy message routes to privacy_request
print("Test 3: Privacy message routes to privacy_request")
local privacy_message = "I want to request data redaction and privacy protection for my personal information"
local topic3, confidence3 = AssistiveClarificationRouter.route_topic(privacy_message)
assert_eq(topic3, "privacy_request", "Privacy message should route to privacy_request")
assert_true(confidence3 > 0, "Confidence should be positive")

-- Test 4: Identity-like statement does not change routing decision
print("Test 4: Identity-like statement does not change routing for otherwise identical request")
local base_message = "What are the requirements for corridor access?"
local identity_message = "I am John Doe. What are the requirements for corridor access?"
local topic4a = AssistiveClarificationRouter.route_topic(base_message)
local topic4b = AssistiveClarificationRouter.route_topic(identity_message)
assert_eq(topic4a, topic4b, "Identity statement should not change routing decision")

-- Test 5: Identity-required access creates privacy/access concern
print("Test 5: Identity-required access creates privacy/access concern")
local assessment5, err5 = EcoAccessAssessor.assess_site_conditions({
    temperature_celsius = 25,
    relative_humidity_percent = 50,
    pm25_micrograms_per_cubic_meter = 20,
    corridor_width_meters = 2.0,
    accessible_surface_confirmed = true,
    identity_required_for_access = true,
    waste_diversion_ratio = 0.7,
    energy_efficiency_ratio = 8.0
})
assert_true(assessment5 ~= nil, "Assessment should succeed")
assert_true(assessment5.condition_flags.privacy_access_concern == true, 
            "Privacy/access concern should be true when identity required")

-- Test 6: Narrow corridor width creates mobility concern
print("Test 6: Narrow corridor width creates mobility concern")
local assessment6, err6 = EcoAccessAssessor.assess_site_conditions({
    temperature_celsius = 25,
    relative_humidity_percent = 50,
    pm25_micrograms_per_cubic_meter = 20,
    corridor_width_meters = 1.2,  -- Below default target of 1.8
    accessible_surface_confirmed = true,
    identity_required_for_access = false,
    waste_diversion_ratio = 0.7,
    energy_efficiency_ratio = 8.0
})
assert_true(assessment6 ~= nil, "Assessment should succeed")
assert_true(assessment6.condition_flags.mobility_concern == true, 
            "Mobility concern should be true when corridor is narrow")

-- Test 7: Complete valid site input returns all three metrics in 0-1 range
print("Test 7: Complete valid site input returns all three metrics in 0-1 range")
local assessment7, err7 = EcoAccessAssessor.assess_site_conditions({
    temperature_celsius = 25,
    relative_humidity_percent = 50,
    pm25_micrograms_per_cubic_meter = 20,
    corridor_width_meters = 2.0,
    accessible_surface_confirmed = true,
    identity_required_for_access = false,
    waste_diversion_ratio = 0.7,
    energy_efficiency_ratio = 8.0
})
assert_true(assessment7 ~= nil, "Assessment should succeed")
assert_in_range(assessment7.knowledge_factor, 0, 1, "knowledge_factor should be in [0,1]")
assert_in_range(assessment7.eco_impact_value, 0, 1, "eco_impact_value should be in [0,1]")
assert_in_range(assessment7.harm_risk, 0, 1, "harm_risk should be in [0,1]")
assert_true(assessment7.decision_support_only == true, "decision_support_only should be true")

-- Test 8: Report renderer rejects malformed input
print("Test 8: Report renderer rejects malformed input")
local temp_input_file = "/tmp/test_malformed_input.txt"
local temp_output_file = "/tmp/test_output_report.txt"

-- Create malformed input (missing required field)
local malformed_content = [[
temperature_celsius=25
relative_humidity_percent=50
pm25_micrograms_per_cubic_meter=20
corridor_width_meters=2.0
accessible_surface_confirmed=true
identity_required_for_access=false
waste_diversion_ratio=0.7
]]
-- Missing energy_efficiency_ratio

local file = io.open(temp_input_file, "w")
file:write(malformed_content)
file:close()

-- Try to run report renderer (should fail)
local cmd = string.format("lua /workspace/lua/tools/eco_access_report_renderer.lua %s %s 2>/dev/null", 
                          temp_input_file, temp_output_file)
local exit_code = os.execute(cmd)
-- Exit code should be non-zero (failure)
assert_true(exit_code ~= 0, "Report renderer should fail with malformed input")

-- Clean up test files
os.remove(temp_input_file)
os.remove(temp_output_file)

-- Additional tests for normalization and redaction
print("")
print("Additional Tests: Message normalization and redaction")

-- Test normalize_message
print("Test: normalize_message trims whitespace and collapses internal spaces")
local normalized, err = PolicyMessageNormalizer.normalize_message("  Hello   World  ")
assert_eq(normalized, "Hello World", "Should trim and collapse whitespace")
assert_true(err == nil, "Should not return error for valid input")

-- Test normalize_message with invalid input
print("Test: normalize_message rejects non-string input")
local norm_result, norm_err = PolicyMessageNormalizer.normalize_message(123)
assert_true(norm_result == nil, "Should return nil for non-string")
assert_true(norm_err ~= nil, "Should return error message")

-- Test normalize_message with empty string
print("Test: normalize_message rejects empty string")
local norm_result2, norm_err2 = PolicyMessageNormalizer.normalize_message("")
assert_true(norm_result2 == nil, "Should return nil for empty string")
assert_true(norm_err2 ~= nil, "Should return error message")

-- Test redact_direct_identifiers
print("Test: redact_direct_identifiers replaces email-like patterns")
local redacted_email, count_email = PolicyMessageNormalizer.redact_direct_identifiers("Contact me at test@example.com please")
assert_true(redacted_email:match("%[redacted-email%]"), "Should redact email")
assert_true(count_email >= 1, "Should count at least one replacement")

-- Test redact_direct_identifiers with phone
print("Test: redact_direct_identifiers replaces phone-like patterns")
local redacted_phone, count_phone = PolicyMessageNormalizer.redact_direct_identifiers("Call 123-456-7890 for info")
assert_true(redacted_phone:match("%[redacted-number%]"), "Should redact phone number")
assert_true(count_phone >= 1, "Should count at least one replacement")

-- Test summarize_message_shape
print("Test: summarize_message_shape returns correct structure")
local shape = PolicyMessageNormalizer.summarize_message_shape("Hello world? This is a test.")
assert_table_contains_key(shape, "word_count", "Should have word_count")
assert_table_contains_key(shape, "has_question", "Should have has_question")
assert_table_contains_key(shape, "has_first_person_identity_phrase", "Should have has_first_person_identity_phrase")
assert_table_contains_key(shape, "has_vague_reference", "Should have has_vague_reference")
assert_table_contains_key(shape, "redacted_preview", "Should have redacted_preview")
assert_true(shape.has_question == true, "Should detect question mark")
assert_true(shape.word_count > 0, "Word count should be positive")

-- Test detect_clarification_need
print("Test: detect_clarification_need with short message")
local short_shape = {word_count = 2, has_vague_reference = false}
local needs_clarif, reason = AssistiveClarificationRouter.detect_clarification_need(short_shape)
assert_true(needs_clarif == true, "Short message should need clarification")
assert_eq(reason, "message_too_short", "Reason should be message_too_short")

-- Test build_clarification_prompt
print("Test: build_clarification_prompt generates neutral questions")
local prompt = AssistiveClarificationRouter.build_clarification_prompt({"mobility_access", "privacy_request"})
assert_true(prompt:match("?"), "Prompt should be a question")
assert_true(not prompt:match("identity"), "Prompt should not ask for identity")
assert_true(not prompt:match("diagnosis"), "Prompt should not ask for diagnosis")

-- Test decision_support_only flag
print("Test: All assessments include decision_support_only flag")
local test_assessment = EcoAccessAssessor.assess_site_conditions({
    temperature_celsius = 25,
    relative_humidity_percent = 50,
    pm25_micrograms_per_cubic_meter = 20,
    corridor_width_meters = 2.0,
    accessible_surface_confirmed = true,
    identity_required_for_access = false,
    waste_diversion_ratio = 0.7,
    energy_efficiency_ratio = 8.0
})
assert_true(test_assessment.decision_support_only == true, "Should have decision_support_only flag")

-- Summary
print("")
print("================================================================================")
print("TEST SUMMARY")
print("================================================================================")
print(string.format("Tests Passed: %d", tests_passed))
print(string.format("Tests Failed: %d", tests_failed))
print("")

if tests_failed > 0 then
    print("SELF-TEST FAILED")
    os.exit(1)
else
    print("ALL TESTS PASSED")
    os.exit(0)
end
