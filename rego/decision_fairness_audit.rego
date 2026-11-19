package hearthline.audit.decision_fairness

default allow_audit_field := false

allowed_audit_fields := {
  "eventId",
  "eventType",
  "occurredAt",
  "decisionId",
  "decisionCategory",
  "opaqueSubjectRef",
  "outcome",
  "reasonCodes",
  "policyVersion",
  "ruleSetVersion",
  "allowedFieldManifestVersion",
  "forbiddenFieldBoundaryResult",
  "featureFlagSnapshotRef",
  "humanReviewStatus",
  "appealRef",
  "retentionClass"
}

prohibited_audit_fields := {
  "protectedClass",
  "protectedClassProxy",
  "race",
  "ethnicity",
  "nationality",
  "religion",
  "genderIdentity",
  "sexualOrientation",
  "disability",
  "health",
  "recovery",
  "financialStatus",
  "housingStatus",
  "employmentStatus",
  "immigrationStatus",
  "riskScore",
  "safetyScore",
  "trustScore",
  "compatibilityScore",
  "desirabilityScore",
  "popularityScore",
  "confidenceScore",
  "messageContent",
  "media",
  "exactLocation",
  "route",
  "venueHistory",
  "deviceProximity",
  "contactGraph",
  "profileViews",
  "responseSpeed",
  "onlineStatus"
}

allow_audit_field if {
  input.field in allowed_audit_fields
}

deny_audit_field if {
  input.field in prohibited_audit_fields
}

audit_payload_valid if {
  every key in object.keys(input.payload) {
    allow_audit_field with input.field as key
  }
}
