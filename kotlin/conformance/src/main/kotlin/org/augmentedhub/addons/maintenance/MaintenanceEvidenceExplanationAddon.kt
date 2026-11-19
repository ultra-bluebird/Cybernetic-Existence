package org.augmentedhub.addons.maintenance

import org.augmentedhub.addons.AddonCapability
import org.augmentedhub.addons.AddonContext
import org.augmentedhub.addons.AddonManifest
import org.augmentedhub.addons.AddonRequest
import org.augmentedhub.addons.AddonResult
import org.augmentedhub.addons.AugmentedHubAddon
import org.augmentedhub.conformance.OutputClass
import org.augmentedhub.conformance.ReleaseClass

class MaintenanceEvidenceExplanationAddon : AugmentedHubAddon {
    override val manifest = AddonManifest(
        addonId = "maintenance-evidence-explanation",
        addonVersion = "v1.0.0",
        semanticVersion = "v1.0.0",
        policyVersion = "v1.0.0",
        displayName = "Maintenance Evidence Explanation",
        declaredPurpose = "maintenance_review",
        supportedMetricNames = setOf("maintenance_condition_decay_model"),
        requestedCapabilities = setOf(
            AddonCapability.CANONICAL_METRIC_LOOKUP,
            AddonCapability.LOCAL_NON_SENSITIVE_ANALYSIS,
            AddonCapability.ACCESSIBLE_EXPLANATION,
            AddonCapability.MAINTENANCE_REVIEW,
            AddonCapability.EVIDENCE_QUALITY_REVIEW
        ),
        supportedOutputClasses = setOf(
            OutputClass.ADVISORY_ONLY,
            OutputClass.NEEDS_REVIEW,
            OutputClass.INSUFFICIENT_EVIDENCE,
            OutputClass.LOCAL_ONLY,
            OutputClass.BLOCKED_BY_POLICY
        ),
        accessibleExplanationProvided = true,
        nonDigitalEscalationProvided = true,
        advisoryOnly = true,
        externalActionPermitted = false,
        automatedActuationPermitted = false,
        automatedServiceDenialPermitted = false,
        identityResolutionPermitted = false,
        biometricIdentificationPermitted = false,
        cyberneticStatusAssessmentPermitted = false,
        individualProfilingPermitted = false
    )

    override fun evaluate(request: AddonRequest, context: AddonContext): AddonResult {
        val metric = context.getCanonicalMetric("maintenance_condition_decay_model")
        if (metric == null) {
            return blocked(
                context = context,
                reasons = setOf("canonical_metric_not_found")
            )
        }

        val inspectionState = request.inputSummary["inspection_state"] ?: "unknown"
        val explanation = when (inspectionState) {
            "current" -> {
                "The maintenance evidence is current for the declared planning purpose. " +
                    "This result remains advisory and does not authorize service changes or physical action."
            }
            "expired" -> {
                "The latest maintenance inspection is outside its declared validity interval. " +
                    "A review is required before this information supports planning use."
            }
            else -> {
                "The maintenance evidence state is incomplete or unknown. " +
                    "A current inspection or accessible review is required."
            }
        }

        val outputClass = when (inspectionState) {
            "current" -> OutputClass.ADVISORY_ONLY
            "expired" -> OutputClass.NEEDS_REVIEW
            else -> OutputClass.INSUFFICIENT_EVIDENCE
        }

        return AddonResult(
            outputClass = outputClass,
            releaseClass = ReleaseClass.LOCAL_ONLY,
            reasonCodes = setOf(
                "maintenance_evidence_explanation",
                "advisory_only",
                "no_automated_action_authorized"
            ),
            accessibleExplanation = context.localOnlyExplanation(
                outputClass = outputClass,
                reasonCodes = setOf("maintenance_evidence_explanation"),
                summary = explanation
            ),
            requiresHumanReview = outputClass != OutputClass.ADVISORY_ONLY,
            externalActionAuthorized = false,
            personAssessmentPerformed = false,
            identityResolutionPerformed = false,
            biometricIdentificationPerformed = false,
            cyberneticStatusAssessmentPerformed = false
        )
    }

    private fun blocked(
        context: AddonContext,
        reasons: Set<String>
    ): AddonResult {
        return AddonResult(
            outputClass = OutputClass.BLOCKED_BY_POLICY,
            releaseClass = ReleaseClass.LOCAL_ONLY,
            reasonCodes = reasons,
            accessibleExplanation = context.localOnlyExplanation(
                outputClass = OutputClass.BLOCKED_BY_POLICY,
                reasonCodes = reasons,
                summary = "The requested maintenance explanation cannot be prepared because the canonical metric definition is unavailable."
            ),
            requiresHumanReview = true,
            externalActionAuthorized = false,
            personAssessmentPerformed = false,
            identityResolutionPerformed = false,
            biometricIdentificationPerformed = false,
            cyberneticStatusAssessmentPerformed = false
        )
    }
}
