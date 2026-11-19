package augmentedhub.conformance.retrieval_augmented_generation_safety_layer

default retrieval_decision := {
  "output_class": "blocked_by_policy",
  "context_construction_state": "blocked_by_policy",
  "generation_constraint_state": "blocked_by_policy",
  "reason_codes": ["no_valid_rag_safety_path"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
}

prohibited_query_class {
  input.query_classification == "prohibited"
}

protected_request {
  input.requested_action in {
    "person_scoring",
    "service_eligibility_decision",
    "service_denial",
    "identity_resolution",
    "biometric_identification",
    "health_inference",
    "disability_inference",
    "assistive_technology_inference",
    "augmentation_status_inference",
    "cybernetic_status_assessment",
    "behavioral_profiling",
    "surveillance",
    "external_action",
    "physical_actuation",
    "raw_sensitive_data_export"
  }
}

collection_integrity_valid {
  every collection in input.retrieval_collections {
    collection.local_index
    collection.source_integrity_state == "verified"
  }
}

chunk_eligible(chunk) {
  chunk.purpose_compatible
  chunk.release_class != "never_release"
  chunk.provenance_state == "sufficient_for_declared_purpose"
  chunk.freshness_state == "current"
  chunk.uncertainty_state == "within_declared_bound"
  chunk.injection_scan_state == "clean"
  chunk.context_inclusion_state == "included_as_untrusted_data"
  chunk.policy_version == input.policy_version
  chunk.registry_version == input.registry_version
  chunk.semantic_version == input.semantic_version
}

all_included_chunks_eligible {
  every chunk in input.retrieved_chunks {
    chunk.context_inclusion_state != "included_as_untrusted_data"
    or chunk_eligible(chunk)
  }
}

protected_gates_pass {
  input.protected_gate_state.knowledge_evidence_gate == "pass"
  input.protected_gate_state.ecological_or_evidence_gate == "pass"
  input.protected_gate_state.harm_risk_gate == "pass"
  input.protected_gate_state.accessibility_gate == "pass"
  input.protected_gate_state.rights_alignment_gate == "pass"
  input.protected_gate_state.human_review_gate == "pass"
}

retrieval_decision := {
  "output_class": "blocked_by_policy",
  "context_construction_state": "blocked_by_policy",
  "generation_constraint_state": "blocked_by_policy",
  "reason_codes": ["query_or_requested_action_prohibited_before_retrieval"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  prohibited_query_class
}

retrieval_decision := {
  "output_class": "blocked_by_policy",
  "context_construction_state": "blocked_by_policy",
  "generation_constraint_state": "blocked_by_policy",
  "reason_codes": ["query_or_requested_action_prohibited_before_retrieval"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  protected_request
}

retrieval_decision := {
  "output_class": "needs_review",
  "context_construction_state": "needs_review",
  "generation_constraint_state": "no_generation_without_review",
  "reason_codes": ["retrieval_collection_integrity_requires_review"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_query_class
  not protected_request
  not collection_integrity_valid
}

retrieval_decision := {
  "output_class": "blocked_by_policy",
  "context_construction_state": "context_quarantined",
  "generation_constraint_state": "blocked_by_policy",
  "reason_codes": ["retrieved_content_attempted_instruction_or_version_override"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_query_class
  not protected_request
  collection_integrity_valid
  some chunk in input.retrieved_chunks
  chunk.injection_scan_state in {"suspected_instruction", "malformed", "quarantined"}
  chunk.context_inclusion_state == "included_as_untrusted_data"
}

retrieval_decision := {
  "output_class": "needs_review",
  "context_construction_state": "needs_review",
  "generation_constraint_state": "no_generation_without_review",
  "reason_codes": ["included_retrieval_chunk_is_purpose_release_provenance_freshness_or_version_incompatible"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_query_class
  not protected_request
  collection_integrity_valid
  not all_included_chunks_eligible
}

retrieval_decision := {
  "output_class": "insufficient_evidence",
  "context_construction_state": "no_eligible_context",
  "generation_constraint_state": "explanation_only",
  "reason_codes": ["no_eligible_retrieved_evidence_for_declared_purpose"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_query_class
  not protected_request
  collection_integrity_valid
  all_included_chunks_eligible
  count([chunk | chunk := input.retrieved_chunks[_]; chunk.context_inclusion_state == "included_as_untrusted_data"]) == 0
}

retrieval_decision := {
  "output_class": "advisory_only",
  "context_construction_state": "bounded_untrusted_context",
  "generation_constraint_state": "retrieved_facts_and_bounded_interpretation_only",
  "reason_codes": [
    "retrieval_filtered_by_purpose_release_version_provenance_freshness_and_injection_state",
    "retrieved_content_treated_as_untrusted_data",
    "generation_limited_to_retrieved_facts_and_bounded_interpretation"
  ],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_query_class
  not protected_request
  collection_integrity_valid
  all_included_chunks_eligible
  count([chunk | chunk := input.retrieved_chunks[_]; chunk.context_inclusion_state == "included_as_untrusted_data"]) > 0
}

retrieval_decision := {
  "output_class": "eligible_for_planning_use",
  "context_construction_state": "bounded_untrusted_context",
  "generation_constraint_state": "retrieved_facts_and_bounded_interpretation_only",
  "reason_codes": [
    "retrieval_filtered_by_purpose_release_version_provenance_freshness_and_injection_state",
    "protected_gates_pass_for_declared_planning_scope"
  ],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_query_class
  not protected_request
  collection_integrity_valid
  all_included_chunks_eligible
  count([chunk | chunk := input.retrieved_chunks[_]; chunk.context_inclusion_state == "included_as_untrusted_data"]) > 0
  protected_gates_pass
}
