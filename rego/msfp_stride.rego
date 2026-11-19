package augmentedhub.msfp_stride

default allow_protected_release := false

deny_reason["SPOOFING_OR_REPLAY"] if {
    not input.peer.authenticated
}

deny_reason["SPOOFING_OR_REPLAY"] if {
    not input.frame.nonce_fresh
}

deny_reason["SPOOFING_OR_REPLAY"] if {
    not input.frame.transcript_bound
}

deny_reason["TAMPERING_OR_INVALID_FRAME"] if {
    not input.frame.canonical
}

deny_reason["TAMPERING_OR_INVALID_FRAME"] if {
    not input.frame.integrity_verified
}

deny_reason["TAMPERING_OR_INVALID_FRAME"] if {
    not input.policy.integrity_verified
}

deny_reason["INFORMATION_DISCLOSURE_RISK"] if {
    not input.release.categories_subset_of_requested
}

deny_reason["INFORMATION_DISCLOSURE_RISK"] if {
    not input.release.categories_subset_of_policy
}

deny_reason["INFORMATION_DISCLOSURE_RISK"] if {
    not input.release.categories_subset_of_consent
}

deny_reason["DENIAL_OF_SERVICE_PROTECTION"] if {
    input.frame.exceeds_size_limit
}

deny_reason["DENIAL_OF_SERVICE_PROTECTION"] if {
    input.frame.exceeds_nesting_limit
}

deny_reason["DENIAL_OF_SERVICE_PROTECTION"] if {
    input.rate_limit.exceeded
}

deny_reason["ELEVATION_OF_PRIVILEGE"] if {
    not input.capability.is_attenuation_of_parent
}

deny_reason["ELEVATION_OF_PRIVILEGE"] if {
    input.request.operation == "firmware.update"
    input.session.mode != "maintenance"
}

deny_reason["LEASE_TERMINATED"] if {
    input.lease.expired
}

deny_reason["LEASE_TERMINATED"] if {
    input.lease.revoked
}

deny_reason["LEASE_TERMINATED"] if {
    not input.lease.integrity_ok
}

deny_reason["LEASE_TERMINATED"] if {
    input.lease.remaining_budget <= 0
}

allow_protected_release if {
    count(deny_reason) == 0
}
