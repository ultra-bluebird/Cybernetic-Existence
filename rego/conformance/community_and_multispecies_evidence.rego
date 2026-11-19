package augmentedhub.conformance.community_and_multispecies_evidence

default community_observation_decision := {
  "evidence_class": "community_reported",
  "output_class": "local_only",
  "review_state": "needs_review",
  "reason_codes": ["community_observation_requires_structured_provenance_review"],
}

default multispecies_release_decision := {
  "release_class": "local_only",
  "reason_codes": ["species_sensitivity_review_required"],
  "priority_review": false,
}

community_observation_complete {
  input.community_observation.community_observation_id != ""
  input.community_observation.evidence_class == "community_reported"
  input.community_observation.observer_pseudonym != ""
  input.community_observation.location_accuracy_class != ""
  input.community_observation.time_accuracy_class != ""
  input.community_observation.observation_category != ""
  input.community_observation.observation_severity != ""
  count(input.community_observation.provenance_chain) > 0
}

community_observation_has_prohibited_identity_data {
  input.community_observation.contains_identity_data
}

community_observation_decision := {
  "evidence_class": "community_reported",
  "output_class": "local_only",
  "review_state": "blocked_by_policy",
  "reason_codes": ["identity_or_sensitive_personal_data_requires_local_protection"],
} if {
  community_observation_has_prohibited_identity_data
}

community_observation_decision := {
  "evidence_class": "community_reported",
  "output_class": "insufficient_evidence",
  "review_state": "needs_review",
  "reason_codes": ["required_community_observation_fields_missing"],
} if {
  not community_observation_has_prohibited_identity_data
  not community_observation_complete
}

community_observation_decision := {
  "evidence_class": "community_reported",
  "output_class": "advisory_only",
  "review_state": "priority_review",
  "reason_codes": ["high_severity_community_observation_requires_priority_review"],
} if {
  community_observation_complete
  input.community_observation.observation_severity == "high"
}

community_observation_decision := {
  "evidence_class": "community_reported",
  "output_class": "advisory_only",
  "review_state": "needs_review",
  "reason_codes": ["community_observation_is_valid_distinct_evidence"],
} if {
  community_observation_complete
  input.community_observation.observation_severity != "high"
}

sensitive_species_record {
  input.species_record.sensitivity_class == "extreme_sensitive"
}

sensitive_species_record {
  input.species_record.sensitivity_class == "high_sensitive"
}

welfare_priority_record {
  input.species_record.welfare_relevant
  input.species_record.observable_harm_condition
}

multispecies_release_decision := {
  "release_class": "local_only",
  "reason_codes": ["sensitive_species_location_requires_restricted_handling"],
  "priority_review": priority,
} if {
  sensitive_species_record
  priority := welfare_priority_record
}

multispecies_release_decision := {
  "release_class": "aggregate_with_differential_privacy",
  "reason_codes": ["non_public_species_information_requires_aggregate_release_review"],
  "priority_review": priority,
} if {
  not sensitive_species_record
  not input.species_record.is_public_non_sensitive
  priority := welfare_priority_record
}

multispecies_release_decision := {
  "release_class": "public",
  "reason_codes": ["public_non_sensitive_ecological_information_requires_provenance_and_license_review"],
  "priority_review": priority,
} if {
  not sensitive_species_record
  input.species_record.is_public_non_sensitive
  priority := welfare_priority_record
}
