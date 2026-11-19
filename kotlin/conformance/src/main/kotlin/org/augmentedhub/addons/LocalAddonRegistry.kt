package org.augmentedhub.addons

import java.util.ServiceLoader

class LocalAddonRegistry(
    private val admissionGateway: LocalAddonAdmissionGateway
) {
    fun discoverAdmittedAddons(): List<AugmentedHubAddon> {
        return ServiceLoader.load(AugmentedHubAddon::class.java)
            .toList()
            .filter { addon ->
                val admission = admissionGateway.evaluate(
                    manifest = addon.manifest,
                    request = AddonRequest(
                        purpose = addon.manifest.declaredPurpose,
                        metricName = addon.manifest.supportedMetricNames.singleOrNull(),
                        requestedOutputClass = org.augmentedhub.conformance.OutputClass.ADVISORY_ONLY,
                        requestedReleaseClass = org.augmentedhub.conformance.ReleaseClass.LOCAL_ONLY,
                        requiresSensitiveData = AddonCapability.LOCAL_SENSITIVE_SUMMARY_ANALYSIS in
                            addon.manifest.requestedCapabilities,
                        requiresPersonAssessment = false,
                        requiresServiceEligibilityDecision = false,
                        requiresIdentityResolution = false,
                        requiresBiometricIdentification = false,
                        requiresCyberneticStatusAssessment = false,
                        requiresExternalAction = false,
                        inputSummary = emptyMap()
                    )
                )
                admission.admitted
            }
    }

    fun evaluate(
        addon: AugmentedHubAddon,
        request: AddonRequest,
        context: AddonContext
    ): AddonResult {
        val admission = context.evaluateAdmission(addon.manifest, request)
        if (!admission.admitted) {
            return AddonResult(
                outputClass = admission.outputClass,
                releaseClass = ReleaseClass.LOCAL_ONLY,
                reasonCodes = admission.reasonCodes,
                accessibleExplanation = context.localOnlyExplanation(
                    outputClass = admission.outputClass,
                    reasonCodes = admission.reasonCodes,
                    summary = "The addon request is outside the local advisory policy boundary."
                ),
                requiresHumanReview = true,
                externalActionAuthorized = false,
                personAssessmentPerformed = false,
                identityResolutionPerformed = false,
                biometricIdentificationPerformed = false,
                cyberneticStatusAssessmentPerformed = false
            )
        }

        val result = addon.evaluate(request, context)

        return result.copy(
            releaseClass = if (request.requiresSensitiveData) {
                ReleaseClass.LOCAL_ONLY
            } else {
                result.releaseClass
            },
            externalActionAuthorized = false,
            personAssessmentPerformed = false,
            identityResolutionPerformed = false,
            biometricIdentificationPerformed = false,
            cyberneticStatusAssessmentPerformed = false
        )
    }
}
