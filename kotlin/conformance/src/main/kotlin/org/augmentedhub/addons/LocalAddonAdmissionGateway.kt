package org.augmentedhub.addons

import org.augmentedhub.conformance.OutputClass
import org.augmentedhub.conformance.ReleaseClass

class LocalAddonAdmissionGateway(
    private val allowedAddonIds: Set<String>,
    private val availableMetrics: Map<String, CanonicalMetricReference>
) {
    fun evaluate(manifest: AddonManifest, request: AddonRequest): AddonAdmission {
        val reasons = linkedSetOf<String>()

        if (manifest.addonId.isBlank() || manifest.addonVersion.isBlank()) {
            reasons += "missing_addon_identity_or_version"
        }

        if (manifest.semanticVersion.isBlank() || manifest.policyVersion.isBlank()) {
            reasons += "missing_semantic_or_policy_version"
        }

        if (manifest.addonId !in allowedAddonIds) {
            reasons += "addon_not_in_local_allowlist"
        }

        if (!manifest.advisoryOnly) {
            reasons += "addon_must_be_advisory_only"
        }

        if (!manifest.accessibleExplanationProvided) {
            reasons += "accessible_explanation_required"
        }

        if (!manifest.nonDigitalEscalationProvided) {
            reasons += "non_digital_escalation_required"
        }

        if (manifest.externalActionPermitted || request.requiresExternalAction) {
            reasons += "external_actions_not_permitted"
        }

        if (manifest.automatedActuationPermitted) {
            reasons += "automated_actuation_not_permitted"
        }

        if (manifest.automatedServiceDenialPermitted) {
            reasons += "automated_service_denial_not_permitted"
        }

        if (manifest.identityResolutionPermitted || request.requiresIdentityResolution) {
            reasons += "identity_resolution_not_permitted"
        }

        if (manifest.biometricIdentificationPermitted || request.requiresBiometricIdentification) {
            reasons += "biometric_identification_not_permitted"
        }

        if (
            manifest.cyberneticStatusAssessmentPermitted ||
            request.requiresCyberneticStatusAssessment
        ) {
            reasons += "cybernetic_status_assessment_not_permitted"
        }

        if (manifest.individualProfilingPermitted || request.requiresPersonAssessment) {
            reasons += "person_level_assessment_not_permitted"
        }

        if (request.requiresServiceEligibilityDecision) {
            reasons += "service_eligibility_decision_not_permitted"
        }

        if (
            request.requiresSensitiveData &&
            AddonCapability.LOCAL_SENSITIVE_SUMMARY_ANALYSIS !in manifest.requestedCapabilities
        ) {
            reasons += "sensitive_data_capability_not_declared"
        }

        val metricName = request.metricName
        if (metricName != null) {
            val metric = availableMetrics[metricName]
            if (metric == null) {
                reasons += "canonical_metric_not_found"
            } else {
                if (metricName !in manifest.supportedMetricNames) {
                    reasons += "metric_not_declared_by_addon"
                }
                if (!metric.advisoryOnly) {
                    reasons += "metric_must_be_advisory_only"
                }
                if (metric.automatedActuationPermitted) {
                    reasons += "metric_permits_automated_actuation"
                }
                if (metric.automatedServiceDenialPermitted) {
                    reasons += "metric_permits_service_denial"
                }
                if (metric.biometricIdentificationPermitted) {
                    reasons += "metric_permits_biometric_identification"
                }
                if (metric.cyberneticStatusPenaltyPermitted) {
                    reasons += "metric_permits_cybernetic_status_penalty"
                }
            }
        }

        if (reasons.isNotEmpty()) {
            return AddonAdmission(
                admitted = false,
                outputClass = OutputClass.BLOCKED_BY_POLICY,
                reasonCodes = reasons,
                releaseClass = ReleaseClass.LOCAL_ONLY
            )
        }

        val releaseClass = if (request.requiresSensitiveData) {
            ReleaseClass.LOCAL_ONLY
        } else {
            request.requestedReleaseClass
        }

        return AddonAdmission(
            admitted = true,
            outputClass = OutputClass.ADVISORY_ONLY,
            reasonCodes = setOf("addon_admitted_for_local_advisory_analysis"),
            releaseClass = releaseClass
        )
    }
}
