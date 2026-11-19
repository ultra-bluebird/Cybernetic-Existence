-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/policy_message_normalizer.lua
-- Purpose: Offline policy-message normalization utility for assistive, privacy-preserving workflows

local PolicyMessageNormalizer = {}

--- Normalize a message string
-- Accepts a non-empty string, trims whitespace, collapses internal whitespace
-- Returns normalized text or nil, error_message on invalid input
function PolicyMessageNormalizer.normalize_message(message)
    if type(message) ~= "string" then
        return nil, "input must be a string"
    end
    
    if #message == 0 then
        return nil, "input must not be empty"
    end
    
    -- Trim leading/trailing whitespace
    local trimmed = message:match("^%s*(.-)%s*$")
    
    -- Collapse repeated internal whitespace to single space
    local normalized = trimmed:gsub("%s+", " ")
    
    return normalized
end

--- Redact direct identifiers from a message
-- Replaces email-like substrings with [redacted-email]
-- Replaces phone-like digit sequences with [redacted-number]
-- Returns redacted_string, replacement_count
function PolicyMessageNormalizer.redact_direct_identifiers(message)
    if type(message) ~= "string" then
        return message, 0
    end
    
    local count = 0
    local result = message
    
    -- Email pattern: simple word@word.word format
    local email_pattern = "[A-Za-z0-9._%%+-]+@[A-Za-z0-9.-]+%.[A-Za-z]{2,}"
    result, email_count = result:gsub(email_pattern, "[redacted-email]")
    count = count + email_count
    
    -- Phone pattern: sequences of 7+ digits, possibly with dashes, spaces, or parentheses
    -- Match patterns like: 1234567890, 123-456-7890, (123) 456-7890, 123 456 7890
    local phone_pattern = "%(?[0-9][0-9]?[0-9]?%?[%s.-]?[0-9][0-9]?[0-9]?[%s.-]?[0-9][0-9][0-9][0-9]"
    result, phone_count = result:gsub(phone_pattern, "[redacted-number]")
    count = count + phone_count
    
    -- Also match simple long digit sequences (10+ digits)
    result, digit_count = result:gsub("%d%d%d%d%d%d%d%d%d%d+", "[redacted-number]")
    count = count + digit_count
    
    return result, count
end

--- Summarize message shape
-- Returns a table with word_count, has_question, has_first_person_identity_phrase,
-- has_vague_reference, redacted_preview
function PolicyMessageNormalizer.summarize_message_shape(message)
    local normalized, err = PolicyMessageNormalizer.normalize_message(message)
    if not normalized then
        return {
            word_count = 0,
            has_question = false,
            has_first_person_identity_phrase = false,
            has_vague_reference = false,
            redacted_preview = ""
        }
    end
    
    -- Word count
    local word_count = 0
    for _ in normalized:gmatch("%S+") do
        word_count = word_count + 1
    end
    
    -- Check for question
    local has_question = normalized:match("?") ~= nil
    
    -- Check for first-person identity phrases (treat as communication cue only)
    local identity_patterns = {
        "^I am ",
        "^I'm ",
        " I am ",
        " I'm ",
        "^My name is ",
        " my name is "
    }
    local has_first_person_identity_phrase = false
    for _, pattern in ipairs(identity_patterns) do
        if normalized:match(pattern) then
            has_first_person_identity_phrase = true
            break
        end
    end
    
    -- Check for vague references
    local vague_patterns = {
        "that thing",
        "this thing",
        "those things",
        "these things",
        "it",
        "something",
        "anything",
        "somehow",
        "somewhere",
        "someone",
        "anyone"
    }
    local has_vague_reference = false
    local lower_normalized = normalized:lower()
    for _, pattern in ipairs(vague_patterns) do
        if lower_normalized:match(pattern) then
            has_vague_reference = true
            break
        end
    end
    
    -- Get redacted preview (first 100 chars of redacted version)
    local redacted, _ = PolicyMessageNormalizer.redact_direct_identifiers(normalized)
    local redacted_preview = redacted:sub(1, 100)
    
    return {
        word_count = word_count,
        has_question = has_question,
        has_first_person_identity_phrase = has_first_person_identity_phrase,
        has_vague_reference = has_vague_reference,
        redacted_preview = redacted_preview
    }
end

return PolicyMessageNormalizer
