local allowed_review_destinations = {
  METHOD_QUALITY_REVIEW = true,
  HYDRAULIC_EVIDENCE_REVIEW = true,
  BIOFILM_EVIDENCE_REVIEW = true,
  PFAS_ANALYTICAL_REVIEW = true,
  INDEPENDENT_REPLICATION_REVIEW = true,
  GOVERNANCE_BOUNDARY_REVIEW = true,
  DESIGN_REVIEW = true,
  COMMUNITY_CONTEXT_REVIEW = true,
  CONTEST_SYNTHESIS_REVIEW = true
}

local function require_text(value, field)
  if type(value) ~= "string" or value == "" then
    error(field .. " must be a non-empty string")
  end
end

local function route(packet) {
  require_text(packet.recommendation_id, "recommendation_id")
  require_text(packet.recommendation_version, "recommendation_version")
  require_text(packet.recommendation_status, "recommendation_status")
  require_text(packet.destination, "destination")

  if not allowed_review_destinations[packet.destination] then
    error("unsupported review destination")
  end

  if packet.external_action_authorized == true then
    error("recommendation packet may not authorize external action")
  end

  return {
    recommendation_id = packet.recommendation_id,
    recommendation_version = packet.recommendation_version,
    recommendation_status = packet.recommendation_status,
    destination = packet.destination,
    distribution_status = "ROUTED_FOR_ROLE_BASED_REVIEW",
    external_actuation_permitted = false
  }
end

return {
  route = route
}
