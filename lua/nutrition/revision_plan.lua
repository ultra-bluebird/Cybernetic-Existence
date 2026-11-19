-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Compares declared fields only. Numeric subtype is not nutrient provenance.
-- Release labels are compared for equality, not chronological ordering.

local C = require("lua.nutrition.portion_constants").get()
local V = require("lua.nutrition.composition_record")
local M = {}

function M.plan_update(old_record, new_record)
    local findings = {}
    local old = V.validate(old_record, findings, "old_record")
    local new = V.validate(new_record, findings, "new_record")

    if #findings > 0 then
        return V.unavailable("update_plan", findings)
    end

    local differing = {}
    local compatibility_changed = false

    for _, field in ipairs({
        "source", "food_reference", "preparation_state",
        "nutrient_name", "nutrient_unit",
        "release", "record_revision", "nutrient_per_100g"
    }) do
        if old[field] ~= new[field] then
            differing[#differing + 1] = field
            if field ~= "release" and field ~= "record_revision"
                and field ~= "nutrient_per_100g" then
                compatibility_changed = true
            end
        end
    end

    local status
    if compatibility_changed then
        status = "match_review_required"
    elseif old.record_revision == new.record_revision
        and old.nutrient_per_100g ~= new.nutrient_per_100g then
        status = "revision_content_discrepancy"
    elseif old.record_revision == new.record_revision
        and old.release ~= new.release then
        status = "release_changed_record_unchanged"
    elseif old.record_revision == new.record_revision then
        status = "no_nutrient_update_detected"
    else
        status = "new_record_snapshot_available"
    end

    return {
        kind = "update_plan",
        schema_version = C.SCHEMA_VERSIONS.update_output,
        status = status,
        findings = {},
        differing_fields = differing,
        old_snapshot = old,
        new_snapshot = new,
        historical_estimate_action = "preserve",
        recomputation_authorized = false,
        evidence_verification = "not_performed"
    }
end

return M
