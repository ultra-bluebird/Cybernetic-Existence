package augmentedhub.accessibility

import java.time.Instant

/**
 * Local contract validation only.
 *
 * Accepts field metadata, never field values.
 * No network, identity checks, diagnosis, private-system inspection,
 * logging, service denial, notifications, or external actions.
 */
class DisclosurePathway {
    enum class ServiceScope {
        ORDINARY_ACCESS,
        TRANSACTION_SPECIFIC
    }

    enum class DataClass {
        PUBLIC_TASK_PARAMETER,
        TRANSACTION_PERSONAL_DATA,
        MEDICAL_OR_PHYSIOLOGICAL,
        NEURAL_OR_BIOMETRIC,
        COMPANION_SYSTEM_DETAILS,
        CYBERNETIC_STATUS_OR_INVENTORY,
        UNRELATED_CREDENTIAL,
        UNKNOWN
    }

    enum class PathKind {
        SELF_SERVICE,
        HUMAN_ASSISTED,
        NON_DIGITAL
    }

    enum class EvidenceState {
        DECLARED_PASS,
        DECLARED_FAIL,
        NOT_ESTABLISHED
    }

    enum class Status {
        DECLARED_REQUIREMENTS_MET,
        NEEDS_REDESIGN,
        NOT_ESTABLISHED,
        INVALID_CONTRACT
    }

    data class FieldDeclaration(
        val fieldLabel: String,
        val dataClass: DataClass,
        val required: Boolean,
        val taskPurpose: String,
        val necessityReviewReference: String?,
        val retentionReviewReference: String?
    )

    data class OutcomeEvidence(
        val outcome: String,
        val deploymentContext: String,
        val state: EvidenceState,
        val evidenceReference: String
    )

    data class PathContract(
        val pathwayLabel: String,
        val kind: PathKind,
        val scope: ServiceScope,
        val declaredOutcomes: Set<String>,
        val requestedFields: List<FieldDeclaration>,
        val outcomeEvidence: List<OutcomeEvidence>,
        val deploymentContext: String,
        val validFrom: Instant,
        val validUntil: Instant,
        val ordinaryAccessPreserved: Boolean?,
        val communicationWithoutPrivateProofDeclared: Boolean?,
        val connectionInstructions: String,
        val correctionInstructions: String
    ) {
        override fun toString(): String =
            "PathContract(kind=$kind,scope=$scope,content=redacted)"
    }

    class PathReview(
        val status: Status,
        privateRequested: Set<DataClass>,
        privateRequired: Set<DataClass>,
        transactionRequiredLabels: Set<String>,
        findings: List<String>
    ) {
        val schemaVersion = "1"
        val privateRequested = privateRequested.toSet()
        val privateRequired = privateRequired.toSet()
        val transactionRequiredLabels = transactionRequiredLabels.toSet()
        val findings = findings.toList()
        val externalActionAuthorized: Boolean get() = false
        val legalComplianceCertified: Boolean get() = false
        val fieldValuesProcessed: Boolean get() = false

        override fun toString(): String =
            "PathReview(status=$status,details=redacted)"
    }

    class ServiceReview(
        val status: Status,
        usablePathways: List<String>,
        findings: List<String>,
        val plainText: String
    ) {
        val schemaVersion = "1"
        val declaredUsablePathways = usablePathways.toList()
        val findings = findings.toList()
        val actualServiceAvailabilityVerified: Boolean get() = false
        val serviceDenialAuthorized: Boolean get() = false
        val automaticReferralAuthorized: Boolean get() = false
        val externalActionAuthorized: Boolean get() = false

        override fun toString(): String =
            "ServiceReview(status=$status,details=redacted)"
    }

    private val privateClasses = setOf(
        DataClass.MEDICAL_OR_PHYSIOLOGICAL,
        DataClass.NEURAL_OR_BIOMETRIC,
        DataClass.COMPANION_SYSTEM_DETAILS,
        DataClass.CYBERNETIC_STATUS_OR_INVENTORY,
        DataClass.UNRELATED_CREDENTIAL
    )

    private fun validText(value: String, maximum: Int): Boolean =
        value.isNotBlank() &&
            value.length <= maximum &&
            value.none { Character.isISOControl(it) }

    fun reviewPath(
        contract: PathContract,
        essentialOutcomes: Set<String>,
        expectedDeploymentContext: String,
        now: Instant
    ): PathReview {
        fun invalid() = PathReview(
            Status.INVALID_CONTRACT,
            emptySet(), emptySet(), emptySet(),
            listOf("invalid_or_excessive_contract")
        )

        if (essentialOutcomes.isEmpty() ||
            essentialOutcomes.size > 128 ||
            essentialOutcomes.any { !validText(it, 256) } ||
            !validText(expectedDeploymentContext, 256) ||
            !validText(contract.pathwayLabel, 256) ||
            !validText(contract.deploymentContext, 256) ||
            !validText(contract.connectionInstructions, 2048) ||
            !validText(contract.correctionInstructions, 2048) ||
            contract.validUntil <= contract.validFrom ||
            contract.declaredOutcomes.size > 128 ||
            contract.declaredOutcomes.any { !validText(it, 256) } ||
            contract.requestedFields.size > 128 ||
            contract.outcomeEvidence.size > 256
        ) return invalid()

        val fields = contract.requestedFields.toList()
        val evidence = contract.outcomeEvidence.toList()

        if (fields.map { it.fieldLabel }.toSet().size != fields.size ||
            fields.any {
                !validText(it.fieldLabel, 256) ||
                    !validText(it.taskPurpose, 1024)
            } ||
            evidence.any {
                !validText(it.outcome, 256) ||
                    !validText(it.deploymentContext, 256) ||
                    it.outcome !in contract.declaredOutcomes
            }
        ) return invalid()

        val privateRequested = fields
            .filter { it.dataClass in privateClasses }
            .map { it.dataClass }.toSet()

        val privateRequired = fields
            .filter { it.required && it.dataClass in privateClasses }
            .map { it.dataClass }.toSet()

        val transactionRequired = fields
            .filter {
                it.required &&
                    it.dataClass == DataClass.TRANSACTION_PERSONAL_DATA
            }.map { it.fieldLabel }.toSet()

        val violations = mutableListOf<String>()
        val unknowns = mutableListOf<String>()

        if (privateRequested.isNotEmpty()) {
            violations += "private_disclosure_prompt_present"
        }

        if (contract.scope == ServiceScope.ORDINARY_ACCESS &&
            fields.any { it.dataClass == DataClass.TRANSACTION_PERSONAL_DATA }
        ) {
            violations += "personal_transaction_fields_in_ordinary_access"
        }

        if (fields.any { it.dataClass == DataClass.UNKNOWN }) {
            unknowns += "field_classification_not_established"
        }

        for (field in fields) {
            if (field.dataClass == DataClass.TRANSACTION_PERSONAL_DATA ||
                field.dataClass == DataClass.PUBLIC_TASK_PARAMETER
            ) {
                if (field.necessityReviewReference.isNullOrBlank() ||
                    field.retentionReviewReference.isNullOrBlank()
                ) {
                    unknowns += "task_data_review_not_established"
                }
            }
        }

        when (contract.ordinaryAccessPreserved) {
            false -> violations += "ordinary_access_not_preserved"
            null -> unknowns += "ordinary_access_preservation_unknown"
            true -> Unit
        }

        when (contract.communicationWithoutPrivateProofDeclared) {
            false -> violations += "private_proof_required_for_communication"
            null -> unknowns += "communication_boundary_not_established"
            true -> Unit
        }

        if (contract.deploymentContext != expectedDeploymentContext ||
            now < contract.validFrom || now >= contract.validUntil
        ) {
            unknowns += "deployment_or_currency_not_established"
        }

        if (!contract.declaredOutcomes.containsAll(essentialOutcomes)) {
            violations += "essential_outcome_missing"
        }

        for (outcome in essentialOutcomes) {
            val records = evidence.filter {
                it.outcome == outcome &&
                    it.deploymentContext == expectedDeploymentContext
            }

            // Failure is retained even when other records conflict.
            if (records.any { it.state == EvidenceState.DECLARED_FAIL }) {
                violations += "outcome_failure_declared"
            }

            if (records.size != 1 ||
                records.singleOrNull()?.state != EvidenceState.DECLARED_PASS ||
                records.singleOrNull()?.evidenceReference.isNullOrBlank()
            ) {
                unknowns += "outcome_evidence_missing_or_conflicting"
            }
        }

        val status = when {
            violations.isNotEmpty() -> Status.NEEDS_REDESIGN
            unknowns.isNotEmpty() -> Status.NOT_ESTABLISHED
            else -> Status.DECLARED_REQUIREMENTS_MET
        }

        return PathReview(
            status,
            privateRequested,
            privateRequired,
            transactionRequired,
            (violations + unknowns).distinct()
        )
    }

    /**
     * Evaluates a declared service bundle.
     *
     * Only ordinary-access pathways can satisfy this bundle's zero-private-
     * disclosure requirement. A transaction-specific pathway remains separate.
     */
    fun reviewOrdinaryService(
        pathways: List<PathContract>,
        essentialOutcomes: Set<String>,
        deploymentContext: String,
        now: Instant
    ): ServiceReview {
        if (pathways.isEmpty() || pathways.size > 32 ||
            pathways.map { it.pathwayLabel }.toSet().size != pathways.size
        ) {
            return ServiceReview(
                Status.INVALID_CONTRACT,
                emptyList(),
                listOf("invalid_service_bundle"),
                "The service contract needs correction. " +
                    "Do not deny assistance because this audit is incomplete."
            )
        }

        val reviewed = pathways.map {
            it to reviewPath(it, essentialOutcomes, deploymentContext, now)
        }

        val ordinary = reviewed.filter {
            it.first.scope == ServiceScope.ORDINARY_ACCESS
        }

        val usable = ordinary.filter {
            it.second.status == Status.DECLARED_REQUIREMENTS_MET
        }

        val humanFallback = usable.any {
            it.first.kind == PathKind.HUMAN_ASSISTED ||
                it.first.kind == PathKind.NON_DIGITAL
        }

        val findings = mutableListOf<String>()

        if (usable.isEmpty()) {
            findings += "zero_private_disclosure_pathway_not_established"
        }
        if (!humanFallback) {
            findings += "equivalent_human_or_non_digital_fallback_not_established"
        }
        if (ordinary.any { it.second.status == Status.NEEDS_REDESIGN }) {
            findings += "existing_ordinary_pathway_requires_redesign"
        }
        if (reviewed.any { it.second.status == Status.INVALID_CONTRACT }) {
            findings += "invalid_pathway_contract"
        }
        if (ordinary.any { it.second.status == Status.NOT_ESTABLISHED }) {
            findings += "ordinary_pathway_evidence_incomplete"
        }

        val status = when {
            reviewed.any { it.second.status == Status.INVALID_CONTRACT } ->
                Status.INVALID_CONTRACT
            ordinary.any { it.second.status == Status.NEEDS_REDESIGN } ->
                Status.NEEDS_REDESIGN
            usable.isEmpty() || !humanFallback ||
                ordinary.any { it.second.status == Status.NOT_ESTABLISHED } ->
                Status.NOT_ESTABLISHED
            else -> Status.DECLARED_REQUIREMENTS_MET
        }

        return ServiceReview(
            status,
            usable.map { it.first.pathwayLabel },
            findings.distinct(),
            if (status == Status.DECLARED_REQUIREMENTS_MET)
                "The supplied contracts declare equivalent ordinary access " +
                    "without private disclosure, including human or non-digital " +
                    "fallback. Real availability and task success require testing."
            else
                "The service's disclosure or fallback contract needs review. " +
                    "Preserve assistance and ordinary access. This finding " +
                    "does not authorize refusal of service."
        )
    }
}
