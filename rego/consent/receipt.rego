package augmentedhub.consent

default permit := false
default deny_reason := "consent_not_evaluated"

permit if {
  input.receipt.receipt_version == "ConsentReceipt.v1"
  input.receipt.status == "active"
  current_time_before_expiry
  requested_purpose_permitted
  requested_category_permitted
  recipient_class_permitted
  requested_fields_permitted
  requested_output_permitted
  revocation_available
  audit_present
}

current_time_before_expiry if {
  time.parse_rfc3339_ns(input.now_utc) < time.parse_rfc3339_ns(input.receipt.validity.expires_at_utc)
  time.parse_rfc3339_ns(input.now_utc) < time.parse_rfc3339_ns(input.receipt.retention.expires_at_utc)
}

requested_purpose_permitted if {
  input.receipt.scope.permitted_purposes[_] == input.request.purpose
}

requested_category_permitted if {
  input.receipt.scope.data_categories[_] == input.request.data_category
}

recipient_class_permitted if {
  input.receipt.scope.recipient_classes[_] == input.request.recipient_class
}

requested_fields_permitted if {
  every field in input.request.fields {
    input.receipt.scope.field_scope[_] == field
  }
}

requested_output_permitted if {
  input.receipt.scope.output_modes[_] == input.request.output_mode
}

revocation_available if {
  input.receipt.revocation.revocation_available == true
  input.receipt.revocation.prospective_effect == "immediate_block_on_new_processing"
}

audit_present if {
  input.request.audit_id != ""
  input.request.audit_sink_available == true
}

deny_reason := "receipt_not_active" if {
  input.receipt.status != "active"
}

deny_reason := "consent_expired" if {
  input.receipt.status == "active"
  not current_time_before_expiry
}

deny_reason := "purpose_not_in_receipt" if {
  input.receipt.status == "active"
  current_time_before_expiry
  not requested_purpose_permitted
}

deny_reason := "data_category_not_in_receipt" if {
  input.receipt.status == "active"
  current_time_before_expiry
  requested_purpose_permitted
  not requested_category_permitted
}

deny_reason := "recipient_not_in_receipt" if {
  input.receipt.status == "active"
  current_time_before_expiry
  requested_purpose_permitted
  requested_category_permitted
  not recipient_class_permitted
}

deny_reason := "requested_field_outside_scope" if {
  input.receipt.status == "active"
  current_time_before_expiry
  requested_purpose_permitted
  requested_category_permitted
  recipient_class_permitted
  not requested_fields_permitted
}

deny_reason := "audit_sink_unavailable" if {
  input.receipt.status == "active"
  current_time_before_expiry
  requested_purpose_permitted
  requested_category_permitted
  recipient_class_permitted
  requested_fields_permitted
  requested_output_permitted
  not audit_present
}
