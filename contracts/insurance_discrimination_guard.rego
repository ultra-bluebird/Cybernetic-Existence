# Repository: mk-bluebird/Prometheus-Praxis
# Filename: contracts/insurance_discrimination_guard.rego
# Destination: contracts/

package augmented_hub.insurance_discrimination

default allow := false

# Protected characteristics under Article XXI
protected_characteristics := {
    "augmentation_status",
    "identity_verifiability",
    "assistive_technology_use",
    "neural_interface_use",
    "bci_use",
    "augmentation_history"
}

# Section 21.1: No discrimination on protected characteristics
discrimination_detected if {
    some characteristic in protected_characteristics
    input.policy[characteristic] == true
    input.policy.denies_coverage == true
}

discrimination_detected if {
    some characteristic in protected_characteristics
    input.policy[characteristic] == true
    input.policy.limits_coverage == true
}

discrimination_detected if {
    some characteristic in protected_characteristics
    input.policy[characteristic] == true
    input.policy.differential_pricing == true
}

# Section 21.2: Coverage shall not be denied, limited, or priced differently
coverage_denied_based_on_status if {
    input.request.coverage_decision == "denied"
    input.request.augmentation_status != "not_applicable"
    not input.request.actuarial_justification
}

coverage_limited_based_on_status if {
    input.request.coverage_decision == "limited"
    input.request.augmentation_status != "not_applicable"
    input.request.limitation_scope != "standard_limitation"
}

priced_differentially_based_on_status if {
    input.request.premium_adjustment > 0
    input.request.augmentation_status != "not_applicable"
    not input.request.actuarial_justification
}

# Section 21.3: Healthcare services shall be accessible
accessibility_failure if {
    input.service.procedure_type == "diagnostic"
    not input.service.compatible_with_augmentations
}

accessibility_failure if {
    input.service.procedure_type == "surgical"
    not input.service.respects_augmentations
}

accessibility_failure if {
    input.service.procedure_type == "rehabilitation"
    not input.service.addresses_augmentation_related_needs
}

accessibility_failure if {
    input.service.procedure_type == "emergency_care"
    not input.service.accommodates_assistive_technology
}

# Section 21.4: No forced deactivation or removal
forced_deactivation_detected if {
    input.request.requires_deactivation == true
    not input.request.emergency_justification
}

forced_removal_detected if {
    input.request.requires_removal == true
    not input.request.emergency_justification
}

# Composite violation detection
violation_count := count({
    rule |
    discrimination_detected
    coverage_denied_based_on_status
    coverage_limited_based_on_status
    priced_differentially_based_on_status
    accessibility_failure
    forced_deactivation_detected
    forced_removal_detected
})

# Allow only if no violations and proper justification
allow if {
    not discrimination_detected
    not coverage_denied_based_on_status
    not coverage_limited_based_on_status
    not priced_differentially_based_on_status
    not accessibility_failure
    not forced_deactivation_detected
    not forced_removal_detected
}

# Decision output
decision := {
    "allow": allow,
    "violation_count": violation_count,
    "discrimination_detected": discrimination_detected,
    "coverage_denied_based_on_status": coverage_denied_based_on_status,
    "coverage_limited_based_on_status": coverage_limited_based_on_status,
    "priced_differentially_based_on_status": priced_differentially_based_on_status,
    "accessibility_failure": accessibility_failure,
    "forced_deactivation_detected": forced_deactivation_detected,
    "forced_removal_detected": forced_removal_detected,
    "reasons": reasons,
    "required_remedies": required_remedies,
    "knowledge_factor": knowledge_factor,
    "eco_impact_value": eco_impact_value,
    "harm_risk": harm_risk,
    "advisory_only": true,
}

reasons contains "discrimination based on augmentation status, identity verifiability, or assistive technology use" if {
    discrimination_detected
}

reasons contains "coverage denied based on augmentation status without actuarial justification" if {
    coverage_denied_based_on_status
}

reasons contains "coverage limited based on augmentation status without actuarial justification" if {
    coverage_limited_based_on_status
}

reasons contains "differential pricing based on augmentation status without actuarial justification" if {
    priced_differentially_based_on_status
}

reasons contains "diagnostic procedures must be compatible with augmentations" if {
    accessibility_failure
    input.service.procedure_type == "diagnostic"
}

reasons contains "surgical care must respect augmentations" if {
    accessibility_failure
    input.service.procedure_type == "surgical"
}

reasons contains "rehabilitation must address augmentation-related needs" if {
    accessibility_failure
    input.service.procedure_type == "rehabilitation"
}

reasons contains "emergency care must accommodate assistive technology" if {
    accessibility_failure
    input.service.procedure_type == "emergency_care"
}

reasons contains "forced deactivation or removal of augmentations prohibited without emergency justification" if {
    forced_deactivation_detected or forced_removal_detected
}

required_remedies contains "Remove discrimination based on augmentation status, identity verifiability, or assistive technology use" if {
    discrimination_detected
}

required_remedies contains "Provide coverage based on actuarial risk, not augmentation status" if {
    coverage_denied_based_on_status or coverage_limited_based_on_status or priced_differentially_based_on_status
}

required_remedies contains "Ensure healthcare services are compatible with augmentations" if {
    accessibility_failure
}

required_remedies contains "Provide emergency care that accommodates assistive technology" if {
    accessibility_failure
    input.service.procedure_type == "emergency_care"
}

required_remedies contains "Do not require deactivation or removal of augmentations as a condition of coverage" if {
    forced_deactivation_detected or forced_removal_detected
}

knowledge_factor := 0.90 if {
    input.request.evidence_complete == true
    input.policy.evidence_complete == true
    input.service.evidence_complete == true
}

knowledge_factor := 0.70 if {
    input.request.evidence_complete == true
    not (input.policy.evidence_complete == true)
}

knowledge_factor := 0.50 if {
    not (input.request.evidence_complete == true)
}

eco_impact_value := value if {
    value := input.request.eco_impact_value
    value >= 0
    value <= 1
}

eco_impact_value := 0.50 if {
    value := input.request.eco_impact_value
    not value >= 0
    or not value <= 1
}

harm_risk := 0.05 if {
    allow
}

harm_risk := value if {
    not allow
    value := min(1.0, 0.15 + (0.12 * violation_count))
}
