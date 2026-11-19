package augmentedhub.data_governance

default permit := false
default deny_reason := "authorization_not_evaluated"

data_classes := {
  "direct_identifier",
  "sensitive_interface_data",
  "derived_feature",
  "research_outcome",
  "governance_record",
  "security_event",
}

restricted_classes := {
  "direct_identifier",
  "sensitive_interface_data",
  "governance_record",
  "security_event",
}

permitted_purposes := {
  "accessibility_support",
  "authorized_local_analysis",
  "aggregate_research",
  "method_validation",
  "security_investigation",
  "governance_review",
}

allowed_output_modes := {
  "no_export",
  "aggregate_only",
  "de_identified_summary",
  "restricted_governance_record",
  "restricted_security_record",
}

permit if {
  valid_request
  valid_actor
  valid_purpose
  valid_data_class
  scope_is_minimal
  authorization_basis_valid
  authorization_is_current
  output_mode_allowed
  audit_required_and_present
  direct_identifier_protected
  sensitive_interface_protected
}

valid_request if {
  input.actor_id != ""
  input.purpose != ""
  input.dataset_id != ""
  input.audit_id != ""
  input.now_utc != ""
  input.authorization.expiry_utc != ""
}

valid_actor if {
  input.actor.authorized == true
  input.actor.role != ""
  input.actor_id != ""
}

valid_purpose if {
  permitted_purposes[input.purpose]
  input.authorization.permitted_purposes[_] == input.purpose
}

valid_data_class if {
  data_classes[input.dataset.data_class]
}

scope_is_minimal if {
  input.scope.field_count > 0
  input.scope.field_count <= input.dataset.maximum_permitted_field_count
  input.scope.time_window_seconds > 0
  input.scope.time_window_seconds <= input.dataset.maximum_permitted_time_window_seconds
  input.scope.rows_requested > 0
  input.scope.rows_requested <= input.dataset.maximum_permitted_rows
}

authorization_basis_valid if {
  input.authorization.basis != ""
  input.authorization.status == "active"
}

authorization_is_current if {
  time.parse_rfc3339_ns(input.now_utc) < time.parse_rfc3339_ns(input.authorization.expiry_utc)
}

output_mode_allowed if {
  allowed_output_modes[input.output.mode]
  input.output.mode == input.authorization.output_mode
}

audit_required_and_present if {
  input.audit_id != ""
  input.audit.sink_available == true
  input.audit.event_kind == "data_access_decision"
}

direct_identifier_protected if {
  input.dataset.data_class != "direct_identifier"
}

direct_identifier_protected if {
  input.dataset.data_class == "direct_identifier"
  input.output.mode == "no_export"
  input.scope.local_only == true
  input.authorization.direct_identifier_exception == true
}

sensitive_interface_protected if {
  input.dataset.data_class != "sensitive_interface_data"
}

sensitive_interface_protected if {
  input.dataset.data_class == "sensitive_interface_data"
  input.scope.local_only == true
  input.output.mode == "no_export"
  input.authorization.sensitive_interface_exception == true
  input.authorization.inference_prohibited == true
}

deny_reason := "actor_not_authorized" if {
  not valid_actor
}

deny_reason := "purpose_not_permitted" if {
  valid_actor
  not valid_purpose
}

deny_reason := "scope_not_minimal" if {
  valid_actor
  valid_purpose
  not scope_is_minimal
}

deny_reason := "authorization_expired_or_invalid" if {
  valid_actor
  valid_purpose
  scope_is_minimal
  not authorization_basis_valid
}

deny_reason := "authorization_expired_or_invalid" if {
  valid_actor
  valid_purpose
  scope_is_minimal
  authorization_basis_valid
  not authorization_is_current
}

deny_reason := "output_mode_not_allowed" if {
  valid_actor
  valid_purpose
  scope_is_minimal
  authorization_basis_valid
  authorization_is_current
  not output_mode_allowed
}

deny_reason := "audit_sink_unavailable" if {
  valid_actor
  valid_purpose
  scope_is_minimal
  authorization_basis_valid
  authorization_is_current
  output_mode_allowed
  not audit_required_and_present
}

deny_reason := "sensitive_data_protection_required" if {
  valid_actor
  valid_purpose
  scope_is_minimal
  authorization_basis_valid
  authorization_is_current
  output_mode_allowed
  audit_required_and_present
  not sensitive_interface_protected
}
