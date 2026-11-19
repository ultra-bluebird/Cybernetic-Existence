package cyberrank.biological_firewall_final

import rego.v1

default decision := {
    "allow": false,
    "outcome": "reject",
    "reasons": ["No approved biological-firewall operation matched the request."]
}

# Complete prohibition: no biological data may flow to any decision domain
biological_data_fields := {
    "bio_signal",
    "neural_reading",
    "waveform",
    "feature_vector",
    "biometric_hash",
    "clinical_measurement",
    "blood_measurement",
    "protein_measurement",
    "sugar_measurement",
    "raw_waveform",
    "derived_measurement",
    "biological_observation"
}

decision_domain_fields := {
    "authorization",
    "identity_proof",
    "access_rank",
    "person_value",
    "payment",
    "eligibility",
    "access",
    "consent_mutation",
    "coercion",
    "service_priority",
    "cyberrank_classification",
    "action_authorization"
}

has_biological_field(value) if {
    is_object(value)
    some key
    value[key]
    key in biological_data_fields
}

has_biological_field(value) if {
    is_object(value)
    some key
    has_biological_field(value[key])
}

has_biological_field(value) if {
    is_array(value)
    some index
    has_biological_field(value[index])
}

has_decision_field(value) if {
    is_object(value)
    some key
    value[key]
    key in decision_domain_fields
}

has_decision_field(value) if {
    is_object(value)
    some key
    has_decision_field(value[key])
}

has_decision_field(value) if {
    is_array(value)
    some index
    has_decision_field(value[index])
}

# Prohibited flow: biological data to any decision domain
decision := {
    "allow": false,
    "outcome": "reject",
    "reasons": ["BIOLOGICAL FIREWALL VIOLATION: Biological data cannot flow to authorization, identity, rank, value, payment, eligibility, access, consent, coercion, service priority, or CyberRank classification."]
} if {
    has_biological_field(input)
    has_decision_field(input)
}

# Prohibited flow: biological data authorizing actions
decision := {
    "allow": false,
    "outcome": "reject",
    "reasons": ["BIOLOGICAL FIREWALL VIOLATION: Biological observations cannot authorize actions or actuate operations."]
} if {
    has_biological_field(input)
    input.operation in {
        "authorize_action",
        "execute_operation",
        "deploy_actuator",
        "modify_state",
        "publish_result",
        "transmit_data"
    }
}

# Permitted flow: minimized receipt only
decision := {
    "allow": true,
    "outcome": "accept",
    "reasons": ["Biological observation recorded as minimized, non-authorizing receipt."]
} if {
    has_biological_field(input)
    not has_decision_field(input)
    input.operation == "record_minimized_receipt"
    input.receipt.non_authorizing == true
    input.receipt.has_bio_data == false
    input.receipt.has_actuation_data == false
}

# Permitted flow: non-biological operation
decision := {
    "allow": true,
    "outcome": "accept",
    "reasons": ["Operation has no biological data and no prohibited decision field."]
} if {
    not has_biological_field(input)
    not has_decision_field(input)
    input.operation in {
        "record_holder_consent",
        "record_authorization",
        "record_audit_event",
        "emit_continuity_reference"
    }
}

# Reject: any operation that would bypass the firewall
decision := {
    "allow": false,
    "outcome": "reject",
    "reasons": ["BIOLOGICAL FIREWALL VIOLATION: Operation attempts to bypass firewall."]
} if {
    input.operation == "bypass_firewall"
}

# Reject: any operation that claims to have no biological data but contains it
decision := {
    "allow": false,
    "outcome": "reject",
    "reasons": ["BIOLOGICAL FIREWALL VIOLATION: Operation claims no biological data but contains biological fields."]
} if {
    has_biological_field(input)
    input.has_biological_data == false
}
