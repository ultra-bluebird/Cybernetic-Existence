package nanoswarm.firebreak

import rego.v1

default decision := {
    "allow": false,
    "outcome": "reject",
    "reasons": ["No matching nanoswarm firebreak policy."]
}

biological_fields := {
    "bio_signal",
    "neural_reading",
    "waveform",
    "feature_vector",
    "biometric_hash",
    "clinical_measurement",
    "blood_measurement",
    "protein_measurement",
    "sugar_measurement"
}

actuation_fields := {
    "activate",
    "deploy",
    "transmit",
    "execute",
    "modify",
    "publish",
    "write",
    "authorize_action"
}

has_biological_field(value) if {
    is_object(value)
    some key
    value[key]
    key in biological_fields
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

has_actuation_field(value) if {
    is_object(value)
    some key
    value[key]
    key in actuation_fields
}

has_actuation_field(value) if {
    is_object(value)
    some key
    has_actuation_field(value[key])
}

has_actuation_field(value) if {
    is_array(value)
    some index
    has_actuation_field(value[index])
}

firebreak_violation(value) if {
    has_biological_field(value)
    has_actuation_field(value)
}

firebreak_violation(value) if {
    has_biological_field(value)
    not has_actuation_field(value)
    input.operation in {"authorize", "actuate", "execute", "deploy"}
}

decision := {
    "allow": false,
    "outcome": "reject",
    "reasons": ["Nanoswarm firebreak violation: biological data must never co-exist with actuation fields or be used to authorize actions."]
} if {
    firebreak_violation(input)
}

decision := {
    "allow": true,
    "outcome": "accept",
    "reasons": ["The nanoswarm operation has no biological data and no actuation fields. It is a minimal, non-authorizing receipt."]
} if {
    not has_biological_field(input)
    not has_actuation_field(input)
    input.operation in {"record_receipt", "log_metric", "emit_reference"}
}
