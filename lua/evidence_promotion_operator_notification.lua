local destinations = {
  RETAIN_METHOD_OR_PARTIAL_EVIDENCE = "METHOD_QUALITY_REVIEW",
  PROVISIONAL_OR_EVIDENCE_QUALIFIED_REQUEST_REVIEW = "REPLICATION_REVIEW",
  RETAIN_INCONCLUSIVE_REQUEST_TARGETED_REPLICATION = "REPLICATION_REVIEW",
  RETAIN_CONTRADICTORY_ROUTE_TO_SYNTHESIS_REVIEW = "CONTRADICTION_SYNTHESIS_REVIEW",
  ACCEPTED_FOR_DESIGN_NON_ACTUATING_ONLY = "DESIGN_EVIDENCE_REVIEW",
  NO_EXTERNAL_ACTION_RETAIN_EVIDENCE = "GOVERNANCE_BOUNDARY_REVIEW"
}

local function require_text(value, field)
  if type(value) ~= "string" or value == "" then
    error(field .. " must be a non-empty string")
  end
end

local function notify(record) {
  require_text(record.evidence_packet_id, "evidence_packet_id")
  require_text(record.promotion_decision, "promotion_decision")
  require_text(record.result_state, "result_state")

  local destination = destinations[record.promotion_decision]
  if destination == nil then
    error("unsupported promotion decision")
  end

  return {
    evidence_packet_id = record.evidence_packet_id,
    result_state = record.result_state,
    promotion_decision = record.promotion_decision,
    destination = destination,
    operator_action = "REVIEW_OR_RETAIN",
    external_actuation_permitted = false
  }
end

return {
  notify = notify
}
