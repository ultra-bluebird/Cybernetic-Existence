-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/assistive_clarification_router.lua
-- Purpose: Assistive clarification and routing utility for eco-restoration workflows

local PolicyMessageNormalizer = require("lua.tools.policy_message_normalizer")

local AssistiveClarificationRouter = {}

-- Topic labels
local TOPICS = {
    environmental_monitoring = "environmental_monitoring",
    restoration_materials = "restoration_materials",
    waste_reduction = "waste_reduction",
    mobility_access = "mobility_access",
    privacy_request = "privacy_request",
    governance_review = "governance_review",
    unclassified = "unclassified"
}

-- Keyword groups for topic detection (local Lua tables)
local KEYWORD_GROUPS = {
    environmental_monitoring = {
        "temperature", "humidity", "air quality", "pm2.5", "sensor", 
        "monitoring", "measurement", "reading", "data", "environment"
    },
    restoration_materials = {
        "material", "recycled", "compost", "soil", "plant", "tree", 
        "vegetation", "green", "restoration", "rehabilitation"
    },
    waste_reduction = {
        "waste", "recycle", "reduce", "reuse", "diversion", "trash", 
        "garbage", "landfill", "composting", "disposal"
    },
    mobility_access = {
        "mobility", "access", "corridor", "width", "accessible", "ramp", 
        "path", "wheelchair", "barrier", "navigation", "passage"
    },
    privacy_request = {
        "privacy", "redact", "anonymize", "identity", "personal", 
        "data protection", "confidential", "consent", "tracking"
    },
    governance_review = {
        "governance", "policy", "review", "audit", "compliance", 
        "oversight", "accountability", "transparency", "decision"
    }
}

-- Generic policy tags
local POLICY_TAGS = {
    privacy = "privacy",
    accessibility = "accessibility",
    environment = "environment",
    governance = "governance",
    non_discrimination = "non_discrimination"
}

--- Detect if clarification is needed
-- Returns true, reason_code when message needs clarification
-- Reason codes: message_too_short, vague_reference_without_context, no_topic_evidence, sufficiently_specified
function AssistiveClarificationRouter.detect_clarification_need(message_shape, prior_topic)
    if type(message_shape) ~= "table" then
        return true, "message_too_short"
    end
    
    -- Check word count (too short if less than 4 words)
    if message_shape.word_count and message_shape.word_count < 4 then
        return true, "message_too_short"
    end
    
    -- Check for vague reference without prior context
    if message_shape.has_vague_reference and not prior_topic then
        return true, "vague_reference_without_context"
    end
    
    -- Check for topic evidence (if shape indicates no clear topic indicators)
    -- This is a simplified check; real implementation would analyze content
    if not message_shape.has_question and message_shape.word_count and message_shape.word_count < 6 then
        return true, "no_topic_evidence"
    end
    
    return false, "sufficiently_specified"
end

--- Build a clarification prompt
-- Returns one short, neutral question with at most three topic choices
-- Never asks for identity verification, diagnosis, biometric data, location history, certification, or proof
function AssistiveClarificationRouter.build_clarification_prompt(candidate_topics)
    if type(candidate_topics) ~= "table" or #candidate_topics == 0 then
        return "Could you provide more details about your request?"
    end
    
    -- Limit to at most three topics
    local limited_topics = {}
    for i = 1, math.min(3, #candidate_topics) do
        table.insert(limited_topics, candidate_topics[i])
    end
    
    if #limited_topics == 1 then
        return string.format("Are you asking about %s?", limited_topics[1]:gsub("_", " "))
    elseif #limited_topics == 2 then
        return string.format("Are you asking about %s or %s?", 
            limited_topics[1]:gsub("_", " "), 
            limited_topics[2]:gsub("_", " "))
    else
        return string.format("Are you asking about %s, %s, or %s?", 
            limited_topics[1]:gsub("_", " "), 
            limited_topics[2]:gsub("_", " "),
            limited_topics[3]:gsub("_", " "))
    end
end

--- Route a message to a topic
-- Returns topic, confidence (0-1), matched_terms, policy_tags
function AssistiveClarificationRouter.route_topic(message)
    if type(message) ~= "string" or #message == 0 then
        return TOPICS.unclassified, 0.0, {}, {}
    end
    
    local normalized = PolicyMessageNormalizer.normalize_message(message)
    if not normalized then
        return TOPICS.unclassified, 0.0, {}, {}
    end
    
    local lower_message = normalized:lower()
    
    local best_topic = TOPICS.unclassified
    local best_confidence = 0.0
    local best_matched_terms = {}
    
    for topic, keywords in pairs(KEYWORD_GROUPS) do
        local matched_terms = {}
        local match_count = 0
        
        for _, keyword in ipairs(keywords) do
            if lower_message:match(keyword) then
                table.insert(matched_terms, keyword)
                match_count = match_count + 1
            end
        end
        
        if match_count > 0 then
            -- Calculate confidence based on match count relative to total keywords
            local confidence = match_count / #keywords
            -- Boost confidence if multiple terms match
            if match_count >= 2 then
                confidence = math.min(1.0, confidence * 1.5)
            end
            
            if confidence > best_confidence then
                best_topic = TOPICS[topic]
                best_confidence = confidence
                best_matched_terms = matched_terms
            end
        end
    end
    
    -- Determine policy tags based on topic
    local policy_tags = {}
    if best_topic == TOPICS.privacy_request then
        table.insert(policy_tags, POLICY_TAGS.privacy)
    elseif best_topic == TOPICS.mobility_access then
        table.insert(policy_tags, POLICY_TAGS.accessibility)
    elseif best_topic == TOPICS.environmental_monitoring or 
           best_topic == TOPICS.restoration_materials or 
           best_topic == TOPICS.waste_reduction then
        table.insert(policy_tags, POLICY_TAGS.environment)
    elseif best_topic == TOPICS.governance_review then
        table.insert(policy_tags, POLICY_TAGS.governance)
        table.insert(policy_tags, POLICY_TAGS.non_discrimination)
    end
    
    -- Always include non_discrimination as a baseline tag
    local has_non_discrimination = false
    for _, tag in ipairs(policy_tags) do
        if tag == POLICY_TAGS.non_discrimination then
            has_non_discrimination = true
            break
        end
    end
    if not has_non_discrimination then
        table.insert(policy_tags, POLICY_TAGS.non_discrimination)
    end
    
    return best_topic, best_confidence, best_matched_terms, policy_tags
end

--- Make an assistive decision
-- Normalizes and summarizes the message, decides if clarification is needed
-- Returns result table with needs_clarification or routed status
-- Includes reasoning trace from reason codes and topic labels only
-- No raw unredacted input in trace
function AssistiveClarificationRouter.make_assistive_decision(message, prior_topic)
    -- Normalize message
    local normalized, norm_err = PolicyMessageNormalizer.normalize_message(message)
    if not normalized then
        return {
            status = "error",
            reason = norm_err,
            reasoning_trace = {"normalization_failed"}
        }
    end
    
    -- Summarize message shape
    local message_shape = PolicyMessageNormalizer.summarize_message_shape(message)
    
    -- Get redacted preview for trace (never raw input)
    local redacted, _ = PolicyMessageNormalizer.redact_direct_identifiers(normalized)
    
    -- Detect clarification need
    local needs_clarification, reason_code = AssistiveClarificationRouter.detect_clarification_need(message_shape, prior_topic)
    
    if needs_clarification then
        -- Get potential topics for clarification prompt
        local candidate_topics = {}
        for topic, _ in pairs(KEYWORD_GROUPS) do
            table.insert(candidate_topics, topic)
        end
        
        local clarification_prompt = AssistiveClarificationRouter.build_clarification_prompt(candidate_topics)
        
        return {
            status = "needs_clarification",
            reason_code = reason_code,
            clarification_prompt = clarification_prompt,
            message_shape = message_shape,
            redacted_preview = redacted:sub(1, 50),
            reasoning_trace = {
                "message_normalized",
                "shape_analyzed",
                reason_code,
                "clarification_requested"
            }
        }
    else
        -- Route to topic
        local topic, confidence, matched_terms, policy_tags = AssistiveClarificationRouter.route_topic(message)
        
        return {
            status = "routed",
            topic = topic,
            confidence = confidence,
            matched_terms = matched_terms,
            policy_tags = policy_tags,
            message_shape = message_shape,
            redacted_preview = redacted:sub(1, 50),
            reasoning_trace = {
                "message_normalized",
                "shape_analyzed",
                "sufficiently_specified",
                "routed_to_" .. topic
            }
        }
    end
end

return AssistiveClarificationRouter
