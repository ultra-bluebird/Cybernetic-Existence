package org.augmentedhub.governance

data class CharterKerInput(
    val knowledgeFactor: Double,
    val ecoImpactValue: Double,
    val harmRisk: Double,
    val accessibilityImpact: Double,
    val rightsAlignment: Double
) {
    init {
        require(
            listOf(
                knowledgeFactor,
                ecoImpactValue,
                harmRisk,
                accessibilityImpact,
                rightsAlignment
            ).all { it.isFinite() && it in 0.0..1.0 }
        ) {
            "All KER values must be finite and within [0, 1]"
        }
    }
}

data class CharterEvidenceInput(
    val qualityScores: List<Double>,
    val weights: List<Double>
) {
    init {
        require(qualityScores.isNotEmpty()) {
            "qualityScores must not be empty"
        }

        require(qualityScores.size == weights.size) {
            "qualityScores and weights must have the same size"
        }

        require(qualityScores.all { it.isFinite() && it in 0.0..1.0 }) {
            "All quality scores must be finite and within [0, 1]"
        }

        require(weights.all { it.isFinite() && it >= 0.0 }) {
            "All weights must be finite and non-negative"
        }

        require(weights.sum() > 0.0) {
            "At least one weight must be positive"
        }

        require(kotlin.math.abs(weights.sum() - 1.0) <= 0.000001) {
            "Weights must sum to 1.0 within tolerance"
        }
    }
}

data class CharterUncertaintyInput(
    val uncertaintyScore: Double,
    val method: String,
    val basis: String
) {
    init {
        require(uncertaintyScore.isFinite() && uncertaintyScore in 0.0..1.0) {
            "uncertaintyScore must be finite and within [0, 1]"
        }

        require(method.isNotBlank()) {
            "method must not be blank"
        }

        require(basis.isNotBlank()) {
            "basis must not be blank"
        }
    }
}

data class CharterGovernanceInput(
    val advisoryOnly: Boolean,
    val automatedActuation: Boolean,
    val automatedServiceDenial: Boolean,
    val requiresContinuousConnectivity: Boolean,
    val requiresOptionalTelemetry: Boolean,
    val usesBiometricIdentification: Boolean,
    val usesCyberneticStatusAsPenalty: Boolean,
    val usesAssistiveTechnologyAsPenalty: Boolean,
    val humanReviewAvailable: Boolean,
    val accessibleNoticeAvailable: Boolean,
    val accessibleExplanationAvailable: Boolean,
    val appealPathAvailable: Boolean,
    val nonDigitalEscalationAvailable: Boolean,
    val dataMinimizationConfirmed: Boolean,
    val purposeLimitationConfirmed: Boolean,
    val retentionAndDeletionPathAvailable: Boolean
) {
    init {
        require(advisoryOnly) {
            "advisoryOnly must be true"
        }

        require(!automatedActuation) {
            "automatedActuation must be false"
        }

        require(!automatedServiceDenial) {
            "automatedServiceDenial must be false"
        }

        require(!requiresContinuousConnectivity) {
            "requiresContinuousConnectivity must be false"
        }

        require(!requiresOptionalTelemetry) {
            "requiresOptionalTelemetry must be false"
        }

        require(!usesBiometricIdentification) {
            "usesBiometricIdentification must be false"
        }

        require(!usesCyberneticStatusAsPenalty) {
            "usesCyberneticStatusAsPenalty must be false"
        }

        require(!usesAssistiveTechnologyAsPenalty) {
            "usesAssistiveTechnologyAsPenalty must be false"
        }

        require(humanReviewAvailable) {
            "humanReviewAvailable must be true"
        }

        require(accessibleNoticeAvailable) {
            "accessibleNoticeAvailable must be true"
        }

        require(accessibleExplanationAvailable) {
            "accessibleExplanationAvailable must be true"
        }

        require(appealPathAvailable) {
            "appealPathAvailable must be true"
        }

        require(nonDigitalEscalationAvailable) {
            "nonDigitalEscalationAvailable must be true"
        }

        require(dataMinimizationConfirmed) {
            "dataMinimizationConfirmed must be true"
        }

        require(purposeLimitationConfirmed) {
            "purposeLimitationConfirmed must be true"
        }

        require(retentionAndDeletionPathAvailable) {
            "retentionAndDeletionPathAvailable must be true"
        }
    }
}

data class CharterRuntimeInput(
    val networkAvailable: Boolean,
    val localPolicyEvaluationAvailable: Boolean,
    val hasValidLocalPolicy: Boolean
) {
    init {
        require(localPolicyEvaluationAvailable || !networkAvailable) {
            "localPolicyEvaluationAvailable should be true when network is unavailable unless offline mode is intended"
        }
    }
}

data class CharterPolicyBundleInput(
    val policyId: String,
    val policyVersion: String,
    val signatureValid: Boolean,
    val versionKnown: Boolean,
    val notExpired: Boolean
) {
    init {
        require(policyId.isNotBlank()) {
            "policyId must not be blank"
        }

        require(policyVersion.isNotBlank()) {
            "policyVersion must not be blank"
        }
    }
}

data class CharterSyncInput(
    val recordIsProtected: Boolean,
    val concurrentUpdateDetected: Boolean,
    val lastWriterWinsRequested: Boolean,
    val preserveAllVersions: Boolean,
    val humanReviewRequired: Boolean
) {
    init {
        if (recordIsProtected && concurrentUpdateDetected) {
            require(!lastWriterWinsRequested) {
                "lastWriterWinsRequested must be false for protected records with concurrent updates"
            }
            require(preserveAllVersions) {
                "preserveAllVersions must be true for protected records with concurrent updates"
            }
            require(humanReviewRequired) {
                "humanReviewRequired must be true for protected records with concurrent updates"
            }
        }
    }
}

data class CharterPolicyInput(
    val ker: CharterKerInput,
    val evidence: CharterEvidenceInput,
    val uncertainty: CharterUncertaintyInput,
    val governance: CharterGovernanceInput,
    val runtime: CharterRuntimeInput,
    val policyBundle: CharterPolicyBundleInput,
    val sync: CharterSyncInput
) {
    init {
        require(evidence.qualityScores.isNotEmpty()) {
            "evidence qualityScores must not be empty"
        }
    }

    fun hasInsufficientEvidence(): Boolean {
        return evidence.qualityScores.any { it == 0.0 }
    }
}
