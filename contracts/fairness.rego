package fairness

import future.keywords.if
import future.keywords.in

default allow := false

# Rule 1: Absolute Right to Access
allow if {
    input.type == "service_request"
    input.subject.bio_status == "cybernetic_host"
    input.service.category in {"banking", "transit", "communication", "ai_assistant"}
    not denied_by_augmentation(input.denial_reasons)
}

# Rule 2: Prohibition of Terminal Shutdown
allow if {
    input.type == "system_command"
    input.command == "shutdown"
    input.target == "bci_integration"
    not has_judicial_stay(input)
}

# Rule 3: Cookie Integrity (No Malicious Injection)
allow if {
    input.type == "http_session"
    input.cookie.secure == true
    input.cookie.httponly == true
    not contains_blacklisted_pattern(input.cookie.value)
}

denied_by_augmentation(reasons) if {
    some r in reasons
    r contains "augmentation"
    r contains "risk_score"
}

has_judicial_stay(input) if {
    input.attached_warrant == true
    input.warrant.authority == "independent_judiciary"
    input.warrant.expiry > time.now_ns()
}

contains_blacklisted_pattern(value) if {
    regex.match(`malicious|track|beacon|fingerprint`, value)
}
