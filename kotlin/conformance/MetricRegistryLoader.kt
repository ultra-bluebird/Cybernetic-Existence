package org.augmentedhub.conformance

import java.io.File
import org.json.JSONObject
import org.json.JSONArray

/**
 * Loader for metric registry JSON files.
 * Reads only from local filesystem, validates governance protections,
 * and rejects entries that violate non-compensatory safeguards.
 */
object MetricRegistryLoader {

    private const val REQUIRED_GOVERNANCE_PROTECTIONS = setOf(
        "advisory_only",
        "automated_actuation_permitted",
        "automated_service_denial_permitted",
        "biometric_identification_permitted",
        "cybernetic_status_penalty_permitted",
        "accessible_explanation_required"
    )

    private const val REQUIRED_FIELDS = setOf(
        "metric_name",
        "semantic_version",
        "metric_kind",
        "definition",
        "evidence_requirements",
        "uncertainty",
        "review",
        "prohibited_interpretations"
    )

    /**
     * Load all metric definitions from the registry directory.
     * Returns a map keyed by metric_name.
     * Throws on duplicate metric names or invalid entries.
     */
    @JvmStatic
    fun loadAll(registryDirectory: File): Map<String, MetricDefinition> {
        require(registryDirectory.exists() && registryDirectory.isDirectory) {
            "Registry directory must exist: ${registryDirectory.absolutePath}"
        }

        val jsonFiles = registryDirectory.listFiles { f -> f.name.endsWith(".json") }
            ?: emptyArray()

        val metrics = mutableMapOf<String, MetricDefinition>()
        val validationErrors = mutableListOf<String>()

        for (file in jsonFiles.sortedBy { it.name }) {
            try {
                val content = file.readText(Charsets.UTF_8)
                val json = JSONObject(content)
                val metric = parseMetricDefinition(json)
                
                val errors = validateLocalMetricContract(metric)
                if (errors.isNotEmpty()) {
                    validationErrors.addAll(errors.map { "${file.name}: $it" })
                    continue
                }

                if (metrics.containsKey(metric.metricName)) {
                    validationErrors.add("Duplicate metric_name '${metric.metricName}' in ${file.name}")
                    continue
                }

                metrics[metric.metricName] = metric
            } catch (e: Exception) {
                validationErrors.add("Failed to parse ${file.name}: ${e.message}")
            }
        }

        if (validationErrors.isNotEmpty()) {
            throw IllegalStateException(
                "Metric registry validation failed:\n" + validationErrors.joinToString("\n")
            )
        }

        return metrics
    }

    /**
     * Load a single metric by name from the registry directory.
     */
    @JvmStatic
    fun load(metricName: String, registryDirectory: File): MetricDefinition {
        val allMetrics = loadAll(registryDirectory)
        return allMetrics[metricName] 
            ?: throw NoSuchElementException("Metric '$metricName' not found in registry")
    }

    /**
     * Validate a metric definition against required governance protections.
     * Returns a list of validation error messages (empty if valid).
     */
    @JvmStatic
    fun validateLocalMetricContract(metric: MetricDefinition): List<String> {
        val errors = mutableListOf<String>()

        // Check governance protections
        val gov = metric.governance
        
        if (!gov.advisoryOnly) {
            errors.add("Governance violation: advisory_only must be true")
        }

        if (gov.automatedActuationPermitted) {
            errors.add("Governance violation: automated_actuation_permitted must be false")
        }

        if (gov.automatedServiceDenialPermitted) {
            errors.add("Governance violation: automated_service_denial_permitted must be false")
        }

        if (gov.biometricIdentificationPermitted) {
            errors.add("Governance violation: biometric_identification_permitted must be false")
        }

        if (gov.cyberneticStatusPenaltyPermitted) {
            errors.add("Governance violation: cybernetic_status_penalty_permitted must be false")
        }

        // Check review requirements
        if (!metric.review.accessibleExplanationRequired) {
            errors.add("Review violation: accessible_explanation_required must be true")
        }

        // Check prohibited interpretations exist
        if (metric.prohibitedInterpretations.isEmpty()) {
            errors.add("prohibited_interpretations must not be empty")
        }

        // Check non-permitted decision contexts
        val prohibitedContexts = setOf(
            "person_scoring",
            "public_service_eligibility", 
            "identity_resolution",
            "biometric_identification",
            "cybernetic_status_assessment",
            "automated_service_denial"
        )
        
        val missingProhibitions = prohibitedContexts - metric.nonPermittedDecisionContexts.toSet()
        if (missingProhibitions.isNotEmpty()) {
            errors.add("Missing required non-permitted contexts: $missingProhibitions")
        }

        return errors
    }

    private fun parseMetricDefinition(json: JSONObject): MetricDefinition {
        val outputJson = json.getJSONObject("output")
        val evidenceReqJson = json.getJSONObject("evidence_requirements")
        val uncertaintyJson = json.getJSONObject("uncertainty")
        val reviewJson = json.getJSONObject("review")
        val governanceJson = json.getJSONObject("governance")

        val output = MetricOutputDefinition(
            unit = outputJson.getString("unit"),
            minimum = outputJson.getDouble("minimum"),
            maximum = outputJson.getDouble("maximum"),
            classification = outputJson.getString("classification"),
            scenarioRequired = outputJson.optBoolean("scenario_required", false),
            intervalReported = outputJson.optBoolean("interval_reported", false),
            rawRatioReported = outputJson.optBoolean("raw_ratio_reported", false),
            conversionModelResidualReported = outputJson.optBoolean("conversion_model_residual_reported", false),
            routeProfileRequired = outputJson.optBoolean("route_profile_required", false),
            discontinuityLengthReported = outputJson.optBoolean("discontinuity_length_reported", false),
            estimatedConditionReported = outputJson.optBoolean("estimated_condition_reported", false),
            inspectionFreshnessReported = outputJson.optBoolean("inspection_freshness_reported", false),
            compositeQualityReported = outputJson.optBoolean("composite_quality_reported", false),
            inspectionAgeReported = outputJson.optBoolean("inspection_age_reported", false),
            uncertaintyIntervalReported = outputJson.optBoolean("uncertainty_interval_reported", false),
            maintenancePrioritySignalReported = outputJson.optBoolean("maintenance_priority_signal_reported", false),
            componentScoresReported = outputJson.optBoolean("component_scores_reported", false),
            weightProfileReported = outputJson.optBoolean("weight_profile_reported", false),
            criticalElementStatusReported = outputJson.optBoolean("critical_element_status_reported", false),
            purposeProfileReported = outputJson.optBoolean("purpose_profile_reported", false),
            provenanceGraphReferenceReported = outputJson.optBoolean("provenance_graph_reference_reported", false),
            individualComponentErrorsReported = outputJson.optBoolean("individual_component_errors_reported", false),
            directionalOffsetsReported = outputJson.optBoolean("directional_offsets_reported", false),
            modalityRequired = outputJson.optBoolean("modality_required", false),
            measurementPurposeRequired = outputJson.optBoolean("measurement_purpose_required", false),
            rawMarginReported = outputJson.optBoolean("raw_margin_reported", false),
            protectedMarginReported = outputJson.optBoolean("protected_margin_reported", false),
            perConditionMarginsReported = outputJson.optBoolean("per_condition_margins_reported", false),
            perConditionUncertaintyReported = outputJson.optBoolean("per_condition_uncertainty_reported", false),
            perConditionSeverityReported = outputJson.optBoolean("per_condition_severity_reported", false),
            humanProximityStateReported = outputJson.optBoolean("human_proximity_state_reported", false),
            protectiveActionReported = outputJson.optBoolean("protective_action_reported", false)
        )

        val evidenceRequirements = MetricEvidenceRequirements(
            requiredFields = toJsonStringList(evidenceReqJson.optJSONArray("required_fields")),
            missingDataBehavior = evidenceReqJson.getString("missing_data_behavior"),
            staleDataBehavior = evidenceReqJson.getString("stale_data_behavior"),
            zeroQualityBehavior = evidenceReqJson.getString("zero_quality_behavior"),
            refugeInventoryRequired = evidenceReqJson.optBoolean("refuge_inventory_required", false),
            capacityEvidenceRequired = evidenceReqJson.optBoolean("capacity_evidence_required", false),
            coolingIntensityEvidenceRequired = evidenceReqJson.optBoolean("cooling_intensity_evidence_required", false),
            accessibilityInspectionRequired = evidenceReqJson.optBoolean("accessibility_inspection_required", false),
            accessibleTravelNetworkRequired = evidenceReqJson.optBoolean("accessible_travel_network_required", false),
            routeProfileRequired = evidenceReqJson.optBoolean("route_profile_required", false),
            accessibleNetworkEvidenceRequired = evidenceReqJson.optBoolean("accessible_network_evidence_required", false),
            sharedMeasurementPeriodRequired = evidenceReqJson.optBoolean("shared_measurement_period_required", false),
            sharedSystemBoundaryRequired = evidenceReqJson.optBoolean("shared_system_boundary_required", false),
            meterCalibrationEvidenceRequired = evidenceReqJson.optBoolean("meter_calibration_evidence_required", false),
            maintenanceConditionEvidenceRequired = evidenceReqJson.optBoolean("maintenance_condition_evidence_required", false),
            lifecycleBoundaryRequiredForEcologicalClaims = evidenceReqJson.optBoolean("lifecycle_boundary_required_for_ecological_claims", false),
            calibrationChainRequired = evidenceReqJson.optBoolean("calibration_chain_required", false),
            referenceStandardRequired = evidenceReqJson.optBoolean("reference_standard_required", false),
            measurementUncertaintyRequired = evidenceReqJson.optBoolean("measurement_uncertainty_required", false),
            modalitySpecificTolerancesRequired = evidenceReqJson.optBoolean("modality_specific_tolerances_required", false),
            hazardAnalysisRequired = evidenceReqJson.optBoolean("hazard_analysis_required", false),
            safetyCaseRequired = evidenceReqJson.optBoolean("safety_case_required", false),
            perConditionMarginRequired = evidenceReqJson.optBoolean("per_condition_margin_required", false),
            directionalOrStateExplanationRequired = evidenceReqJson.optBoolean("directional_or_state_explanation_required", false),
            humanProximityAssessmentRequiredForHazardousMotion = evidenceReqJson.optBoolean("human_proximity_assessment_required_for_hazardous_motion", false),
            accessibleFallbackRequired = evidenceReqJson.optBoolean("accessible_fallback_required", false),
            provenanceGraphRequired = evidenceReqJson.optBoolean("provenance_graph_required", false),
            versionHistoryRequired = evidenceReqJson.optBoolean("version_history_required", false),
            criticalElementProfileRequired = evidenceReqJson.optBoolean("critical_element_profile_required", false)
        )

        val uncertainty = MetricUncertainty(
            method = uncertaintyJson.getString("method"),
            reported = uncertaintyJson.getBoolean("reported"),
            reviewThreshold = uncertaintyJson.getDouble("review_threshold"),
            sources = toJsonStringList(uncertaintyJson.optJSONArray("sources"))
        )

        val review = MetricReviewRequirements(
            humanReviewRequired = reviewJson.getBoolean("human_review_required"),
            accessibleExplanationRequired = reviewJson.getBoolean("accessible_explanation_required"),
            appealPathRequired = reviewJson.getBoolean("appeal_path_required"),
            nonDigitalEscalationRequired = reviewJson.getBoolean("non_digital_escalation_required"),
            communityReviewRequiredForLambdaChanges = reviewJson.optBoolean("community_review_required_for_lambda_changes", false),
            communityReviewRequiredForLReviewChanges = reviewJson.optBoolean("community_review_required_for_L_review_changes", false),
            maxMinFairnessRequiredForInvestmentPrioritization = reviewJson.optBoolean("max_min_fairness_required_for_investment_prioritization", false),
            lifecycleReviewRequiredForNetPositiveEcologicalClaim = reviewJson.optBoolean("lifecycle_review_required_for_net_positive_ecological_claim", false),
            communityReviewRequiredForEroiThresholdChanges = reviewJson.optBoolean("community_review_required_for_eroi_threshold_changes", false),
            modalityExpertReviewRequiredForToleranceChanges = reviewJson.optBoolean("modality_expert_review_required_for_tolerance_changes", false),
            hazardExpertReviewRequiredForBoundaryChanges = reviewJson.optBoolean("hazard_expert_review_required_for_boundary_changes", false),
            communityReviewRequiredForPublicSpaceAutomationChanges = reviewJson.optBoolean("community_review_required_for_public_space_automation_changes", false),
            accessibleServiceContinuityRequiredDuringProtectiveState = reviewJson.optBoolean("accessible_service_continuity_required_during_protective_state", false),
            communityReviewRequiredForWeightProfileChanges = reviewJson.optBoolean("community_review_required_for_weight_profile_changes", false),
            crossDomainReviewRequiredForCrossDomainProfileChanges = reviewJson.optBoolean("cross_domain_review_required_for_cross_domain_profile_changes", false),
            infrastructureExpertReviewRequiredForLambdaBaseChanges = reviewJson.optBoolean("infrastructure_expert_review_required_for_lambda_base_changes", false),
            communityReviewRequiredForInspectionValidityChanges = reviewJson.optBoolean("community_review_required_for_inspection_validity_changes", false),
            maintenancePriorityMustNotBeUsedAsNeglectJustification = reviewJson.optBoolean("maintenance_priority_must_not_be_used_as_neglect_justification", false)
        )

        val governance = MetricGovernance(
            advisoryOnly = governanceJson.getBoolean("advisory_only"),
            automatedActuationPermitted = governanceJson.getBoolean("automated_actuation_permitted"),
            automatedServiceDenialPermitted = governanceJson.getBoolean("automated_service_denial_permitted"),
            biometricIdentificationPermitted = governanceJson.getBoolean("biometric_identification_permitted"),
            cyberneticStatusPenaltyPermitted = governanceJson.getBoolean("cybernetic_status_penalty_permitted"),
            individualProfilingPermitted = governanceJson.optBoolean("individual_profiling_permitted", false),
            optionalTelemetryRequired = governanceJson.optBoolean("optional_telemetry_required", false),
            continuousConnectivityRequired = governanceJson.optBoolean("continuous_connectivity_required", false),
            gateRelationship = governanceJson.optString("gate_relationship", "")
        )

        return MetricDefinition(
            metricName = json.getString("metric_name"),
            semanticVersion = json.getString("semantic_version"),
            domain = json.optString("domain", ""),
            metricKind = json.getString("metric_kind"),
            definition = json.getString("definition"),
            formulaVersion = json.getString("formula_version"),
            formulaExpression = json.getString("formula_expression"),
            output = output,
            evidenceRequirements = evidenceRequirements,
            uncertainty = uncertainty,
            review = review,
            governance = governance,
            prohibitedInterpretations = toJsonStringList(json.optJSONArray("prohibited_interpretations")),
            intendedDecisionContexts = toJsonStringList(json.optJSONArray("intended_decision_contexts")),
            nonPermittedDecisionContexts = toJsonStringList(json.optJSONArray("non_permitted_decision_contexts"))
        )
    }

    private fun toJsonStringList(arr: JSONArray?): List<String> {
        if (arr == null) return emptyList()
        return (0 until arr.length()).map { arr.getString(it) }
    }
}
