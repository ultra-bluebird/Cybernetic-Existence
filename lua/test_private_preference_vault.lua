-- Synthetic local tests only.
-- Attribution:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local vault = require("private_preference_vault")

local consumer, owner = vault.new({
    communication_method = "text",
    correction_preference = "show the proposed correction",
    privacy_boundary = "local access only"
})

local capability = owner.issue_local_read(
    "private_person_view", 100, 0
)

local value, reason = consumer.read(
    capability, "accessibility_preferences", "private_person_view", 10
)
assert(value.communication_method == "text")
assert(reason == "permitted_local_read")

-- A returned copy cannot modify stored preferences.
value.communication_method = "changed externally"
local again = consumer.read(
    capability, "accessibility_preferences", "private_person_view", 11
)
assert(again.communication_method == "text")

-- Possessing one capability does not authorize another purpose.
local denied = consumer.read(
    capability, "eligibility", "private_person_view", 12
)
assert(denied == nil)

denied = consumer.read(
    capability, "accessibility_preferences", "public_export", 12
)
assert(denied == nil)

-- A table with similar-looking fields is not a registered capability.
denied = consumer.read(
    { destination = "private_person_view" },
    "accessibility_preferences", "private_person_view", 12
)
assert(denied == nil)

owner.revoke(capability)
denied = consumer.read(
    capability, "accessibility_preferences", "private_person_view", 13
)
assert(denied == nil)

local second = owner.issue_local_read(
    "local_accessibility_runtime", 20, 13
)
denied = consumer.read(
    second, "accessibility_preferences", "local_accessibility_runtime", 20
)
assert(denied == nil)

local third = owner.issue_local_read("private_person_view", 100, 20)
owner.replace_preferences({ communication_method = "text and captions" })
denied = consumer.read(
    third, "accessibility_preferences", "private_person_view", 21
)
assert(denied == nil)

local ok = pcall(function()
    owner.replace_preferences({ public_rank = "high" })
end)
assert(not ok)

local diagnostics = owner.diagnostics()
assert(diagnostics.payloads_logged == false)
assert(diagnostics.public_export_api_available == false)
