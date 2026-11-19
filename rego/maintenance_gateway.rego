package augmentedhub.maintenance

default allow := false

ordinary_session_capabilities := {
    "consent.read",
    "consent.revoke",
    "docs.read",
    "notes.write",
    "observation.create",
    "observation.export_review"
}

maintenance_capabilities := {
    "diagnostics.read",
    "logs.export_minimal",
    "firmware.stage",
    "firmware.update"
}

allow if {
    input.mode == "maintenance"
    input.request.operation == "firmware.update"

    input.maintenance.authorization.valid
    input.maintenance.authorization.expires_at_unix_s > input.now_unix_s
    input.maintenance.authorization.one_time_challenge_used == false

    input.local_presence.confirmed
    input.target_identity.verified
    input.artifact.signature_valid
    input.artifact.digest_matches_authorization
    input.artifact.compatibility_verified

    input.request.capability == "firmware.update"
    input.request.capability in maintenance_capabilities
    not input.request.capability in ordinary_session_capabilities

    input.independent_audit.available
    input.independent_audit.write_test_passed
}

deny_reason["ORDINARY_SESSION_CANNOT_UPDATE_FIRMWARE"] if {
    input.request.operation == "firmware.update"
    input.mode != "maintenance"
}

deny_reason["LOCAL_PRESENCE_REQUIRED"] if {
    input.request.operation == "firmware.update"
    not input.local_presence.confirmed
}

deny_reason["MAINTENANCE_AUTHORIZATION_REQUIRED"] if {
    input.request.operation == "firmware.update"
    not input.maintenance.authorization.valid
}

deny_reason["MAINTENANCE_AUTHORIZATION_EXPIRED"] if {
    input.request.operation == "firmware.update"
    input.maintenance.authorization.expires_at_unix_s <= input.now_unix_s
}

deny_reason["TARGET_IDENTITY_UNVERIFIED"] if {
    input.request.operation == "firmware.update"
    not input.target_identity.verified
}

deny_reason["ARTIFACT_VERIFICATION_FAILED"] if {
    input.request.operation == "firmware.update"
    not input.artifact.signature_valid
}

deny_reason["INDEPENDENT_AUDIT_UNAVAILABLE"] if {
    input.request.operation == "firmware.update"
    not input.independent_audit.available
}
