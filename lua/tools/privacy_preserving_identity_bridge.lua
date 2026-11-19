local IdentityBridge = {}
IdentityBridge.__index = IdentityBridge

local forbidden_fields = {
    "address",
    "biometric",
    "birthdate",
    "date_of_birth",
    "device_id",
    "email",
    "face_embedding",
    "fingerprint",
    "full_name",
    "government_id",
    "ip_address",
    "location",
    "medical_record",
    "phone",
    "raw_identifier",
    "retina",
    "social_security",
    "voiceprint",
}

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function finite_number(value, field)
    assert(type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge,
        (field or "value") .. " must be a finite number")
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

local function copy_value(value, seen)
    local kind = type(value)
    if kind ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic tables are not valid bridge inputs")
    seen[value] = true

    local result = {}
    for key, item in pairs(value) do
        result[copy_value(key, seen)] = copy_value(item, seen)
    end
    seen[value] = nil
    return result
end

local function sorted_keys(source)
    local keys = {}

    for key in pairs(source) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)

    return keys
end

local function canonicalize(value, depth)
    depth = depth or 0
    assert(depth <= 32, "identity representation exceeds maximum nesting depth")

    local kind = type(value)

    if kind == "nil" then
        return "null"
    end

    if kind == "boolean" then
        return value and "true" or "false"
    end

    if kind == "number" then
        finite_number(value, "canonical numeric value")
        return string.format("%.17g", value)
    end

    if kind == "string" then
        return string.format("%q", value)
    end

    assert(kind == "table", "identity representation contains an unsupported value")

    local fragments = {}
    for _, key in ipairs(sorted_keys(value)) do
        fragments[#fragments + 1] = canonicalize(tostring(key), depth + 1)
            .. ":"
            .. canonicalize(value[key], depth + 1)
    end

    return "{" .. table.concat(fragments, ",") .. "}"
end

local function stable_token(namespace, canonical_value)
    local state = 2166136261

    for index = 1, #namespace do
        state = (state * 16777619 + namespace:byte(index)) % 4294967296
    end

    for index = 1, #canonical_value do
        state = (state * 16777619 + canonical_value:byte(index)) % 4294967296
    end

    return string.format("ref:%08x", state)
end

local function sanitize(value, path, findings)
    local kind = type(value)

    if kind ~= "table" then
        return copy_value(value)
    end

    local result = {}

    for key, item in pairs(value) do
        local key_text = tostring(key)
        local normalized = key_text:lower()
        local next_path = path == "" and key_text or path .. "." .. key_text

        if forbidden_fields[normalized] then
            findings[#findings + 1] = {
                field = next_path,
                reason = "direct identifier or sensitive attribute redacted",
            }
        else
            result[key_text] = sanitize(item, next_path, findings)
        end
    end

    return result
end

local function assert_claim_shape(claim)
    assert(type(claim) == "table", "claim must be a table")

    return {
        claim_id = required_text(claim.claim_id, "claim_id"),
        subject_id = required_text(claim.subject_id, "subject_id"),
        claim_type = required_text(claim.claim_type, "claim_type"),
        value = claim.value,
        asserted_at_utc = required_text(claim.asserted_at_utc, "asserted_at_utc"),
        verifiability = claim.verifiability or "self_asserted",
    }
end

function IdentityBridge.new(config)
    config = config or {}

    return setmetatable({
        namespace = required_text(config.namespace or "sovereign-identity-bridge", "namespace"),
        service_profiles = {},
        issued_reference_count = 0,
    }, IdentityBridge)
end

function IdentityBridge:register_service(service)
    assert(type(service) == "table", "service must be a table")

    local service_id = required_text(service.service_id, "service_id")
    local allowed_claim_types = service.allowed_claim_types or {}

    assert(type(allowed_claim_types) == "table",
        "allowed_claim_types must be a table")

    local profile = {
        service_id = service_id,
        endpoint = required_text(service.endpoint, "endpoint"),
        allowed_claim_types = {},
        require_explicit_consent = service.require_explicit_consent ~= false,
        allow_stable_reference = service.allow_stable_reference == true,
    }

    for _, claim_type in ipairs(allowed_claim_types) do
        profile.allowed_claim_types[required_text(claim_type, "allowed claim type")] = true
    end

    self.service_profiles[service_id] = profile
    return copy_value(profile)
end

function IdentityBridge:translate(claim, request)
    local normalized_claim = assert_claim_shape(claim)
    assert(type(request) == "table", "request must be a table")

    local service_id = required_text(request.service_id, "service_id")
    local profile = self.service_profiles[service_id]
    assert(profile, "external service is not registered")

    local consent = request.consent == true
    if profile.require_explicit_consent then
        assert(consent, "explicit consent is required for external translation")
    end

    assert(profile.allowed_claim_types[normalized_claim.claim_type],
        "claim type is not authorized for this external service")

    local findings = {}
    local redacted_value = sanitize(normalized_claim.value, "value", findings)

    local request_nonce = required_text(request.request_nonce, "request_nonce")
    local reference_input = {
        service_id = service_id,
        request_nonce = request_nonce,
        claim_type = normalized_claim.claim_type,
        redacted_value = redacted_value,
    }

    if profile.allow_stable_reference then
        reference_input.subject_scope = normalized_claim.subject_id
    end

    local reference = stable_token(
        self.namespace,
        canonicalize(reference_input)
    )

    self.issued_reference_count = self.issued_reference_count + 1

    local disclosure = {
        reference = reference,
        service_id = service_id,
        endpoint = profile.endpoint,
        claim_type = normalized_claim.claim_type,
        claim_value = redacted_value,
        verifiability = normalized_claim.verifiability,
        asserted_at_utc = normalized_claim.asserted_at_utc,
        request_nonce = request_nonce,
        direct_identifier_disclosed = false,
        linkability_scope = profile.allow_stable_reference
            and "service_scoped"
            or "single_request",
        redactions = findings,
        knowledge_factor = clamp01(
            normalized_claim.verifiability == "verified" and 0.80 or 0.55
        ),
        eco_impact_value = 0.50,
        harm_risk = #findings == 0 and 0.08 or 0.15,
    }

    return disclosure
end

function IdentityBridge:translate_batch(claims, request)
    assert(type(claims) == "table", "claims must be a table")
    assert(type(request) == "table", "request must be a table")

    local disclosures = {}
    local highest_harm_risk = 0

    for _, claim in ipairs(claims) do
        local disclosure = self:translate(claim, request)
        disclosures[#disclosures + 1] = disclosure
        highest_harm_risk = math.max(highest_harm_risk, disclosure.harm_risk)
    end

    return {
        service_id = request.service_id,
        disclosure_count = #disclosures,
        disclosures = disclosures,
        knowledge_factor = #disclosures == 0 and 0
            or (function()
                local total = 0
                for _, item in ipairs(disclosures) do
                    total = total + item.knowledge_factor
                end
                return total / #disclosures
            end)(),
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
    }
end

return IdentityBridge
