package org.augmentedhub.accessibilitymaintenance

import java.time.Instant

enum class FindingState {
    REPORTED,
    EVIDENCE_CAPTURED,
    REVIEW_REQUIRED,
    VERIFIED_FOR_WORK_ORDER,
    RESOLVED,
    RETIRED
}

data class PathMaintenanceReport(
    val reportRef: String,
    val segmentRef: String,
    val createdAt: Instant,
    val findingState: FindingState,
    val obstructionEvidencePresent: Boolean,
    val surfaceEvidencePresent: Boolean,
    val gradientMeasurementPresent: Boolean,
    val provenanceRef: String,
    val accessibleDetourVerified: Boolean?,
    val humanReviewRequired: Boolean,
    val legalComplianceClaimed: Boolean = false,
    val personIdentityIncluded: Boolean = false,
    val biometricDataIncluded: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

data class ReportValidationResult(
    val valid: Boolean,
    val violations: List<String>
)

fun validatePathMaintenanceReport(
    report: PathMaintenanceReport
): ReportValidationResult {
    val violations = mutableListOf<String>()

    if (report.reportRef.length !in 16..128) {
        violations += "INVALID_REPORT_REFERENCE"
    }

    if (report.segmentRef.length !in 16..128) {
        violations += "INVALID_SEGMENT_REFERENCE"
    }

    if (report.provenanceRef.length !in 16..128) {
        violations += "MISSING_PROVENANCE_REFERENCE"
    }

    if (report.legalComplianceClaimed) {
        violations += "LEGAL_COMPLIANCE_CLAIM_PROHIBITED"
    }

    if (report.personIdentityIncluded) {
        violations += "PERSON_IDENTITY_DATA_PROHIBITED"
    }

    if (report.biometricDataIncluded) {
        violations += "BIOMETRIC_DATA_PROHIBITED"
    }

    if (report.externalActionAuthorized) {
        violations += "EXTERNAL_ACTION_AUTHORIZATION_PROHIBITED"
    }

    return ReportValidationResult(
        valid = violations.isEmpty(),
        violations = violations
    )
}
