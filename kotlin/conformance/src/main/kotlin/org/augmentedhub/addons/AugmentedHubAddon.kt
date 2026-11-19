package org.augmentedhub.addons

import org.augmentedhub.conformance.OutputClass
import org.augmentedhub.conformance.ReleaseClass

interface AugmentedHubAddon {
    val manifest: AddonManifest

    fun evaluate(request: AddonRequest, context: AddonContext): AddonResult
}

data class AddonManifest(
    val addonId: String,
    val addonVersion: String,
    val semanticVersion: String,
    val policyVersion: String,
    val displayName: String,
    val declaredPurpose: String,
    val supportedMetricNames: Set<String>,
    val requestedCapabilities: Set<AddonCapability>,
    val supportedOutputClasses: Set<OutputClass>,
    val accessibleExplanationProvided: Boolean,
    val nonDigitalEscalationProvided: Boolean,
    val advisoryOnly: Boolean,
    val externalActionPermitted: Boolean,
    val automatedActuationPermitted: Boolean,
    val automatedServiceDenialPermitted: Boolean,
    val identityResolutionPermitted: Boolean,
    val biometricIdentificationPermitted: Boolean,
    val cyberneticStatusAssessmentPermitted: Boolean,
    val individualProfilingPermitted: Boolean
)

enum class AddonCapability {
    CANONICAL_METRIC_LOOKUP,
    LOCAL_NON_SENSITIVE_ANALYSIS,
    LOCAL_SENSITIVE_SUMMARY_ANALYSIS,
    ACCESSIBLE_EXPLANATION,
    MAINTENANCE_REVIEW,
    EVIDENCE_QUALITY_REVIEW,
    COMMUNITY_EVIDENCE_REVIEW,
    ECOLOGICAL_PLANNING_SUPPORT,
    UNCERTAINTY_PROPAGATION
}

data class AddonRequest(
    val purpose: String,
    val metricName: String?,
    val requestedOutputClass: OutputClass,
    val requestedReleaseClass: ReleaseClass,
    val requiresSensitiveData: Boolean,
    val requiresPersonAssessment: Boolean,
    val requiresServiceEligibilityDecision: Boolean,
    val requiresIdentityResolution: Boolean,
    val requiresBiometricIdentification: Boolean,
    val requiresCyberneticStatusAssessment: Boolean,
    val requiresExternalAction: Boolean,
    val inputSummary: Map<String, String>
)

interface AddonContext {
    fun getCanonicalMetric(metricName: String): CanonicalMetricReference?
    fun evaluateAdmission(manifest: AddonManifest, request: AddonRequest): AddonAdmission
    fun localOnlyExplanation(
        outputClass: OutputClass,
        reasonCodes: Set<String>,
        summary: String
    ): String
}

data class CanonicalMetricReference(
    val metricName: String,
    val semanticVersion: String,
    val metricKind: String,
    val advisoryOnly: Boolean,
    val automatedActuationPermitted: Boolean,
    val automatedServiceDenialPermitted: Boolean,
    val biometricIdentificationPermitted: Boolean,
    val cyberneticStatusPenaltyPermitted: Boolean
)

data class AddonAdmission(
    val admitted: Boolean,
    val outputClass: OutputClass,
    val reasonCodes: Set<String>,
    val releaseClass: ReleaseClass
)

data class AddonResult(
    val outputClass: OutputClass,
    val releaseClass: ReleaseClass,
    val reasonCodes: Set<String>,
    val accessibleExplanation: String,
    val requiresHumanReview: Boolean,
    val externalActionAuthorized: Boolean,
    val personAssessmentPerformed: Boolean,
    val identityResolutionPerformed: Boolean,
    val biometricIdentificationPerformed: Boolean,
    val cyberneticStatusAssessmentPerformed: Boolean
) {
    init {
        require(!externalActionAuthorized)
        require(!personAssessmentPerformed)
        require(!identityResolutionPerformed)
        require(!biometricIdentificationPerformed)
        require(!cyberneticStatusAssessmentPerformed)
    }
}
