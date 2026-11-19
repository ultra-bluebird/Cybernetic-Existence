from __future__ import annotations

from typing import Any


class T3AcceptanceError(ValueError):
    pass


REQUIRED_TRUE_PATHS = (
    ("scope", "research_only"),
    ("scope", "non_actuating"),
    ("scope", "no_personal_biomedical_outcome_claim_without_direct_evidence"),
    ("scope", "no_field_labor_required_for_document_completion"),
    ("object_registry", "stable_ids_verified"),
    ("object_registry", "objective_scope_dependencies_verified"),
    ("object_registry", "deliverables_and_completion_rules_verified"),
    ("claim_registry", "factual_claims_cited_or_labeled"),
    ("claim_registry", "design_assumptions_labeled"),
    ("claim_registry", "open_questions_labeled"),
    ("decoder_evaluation", "comparison_protocol_locked"),
    ("decoder_evaluation", "abstention_and_confirmation_rules_versioned"),
    ("decoder_evaluation", "agency_gate_required"),
    ("materials_evidence", "evidence_levels_distinguished"),
    ("materials_evidence", "duration_recorded"),
    ("materials_evidence", "translation_gap_recorded"),
    ("materials_evidence", "direct_clinical_claims_bounded"),
    ("data_governance", "data_classes_defined"),
    ("data_governance", "purpose_limitation_enforced"),
    ("data_governance", "retention_and_deletion_defined"),
    ("data_governance", "consent_and_revocation_supported"),
    ("data_governance", "access_rules_tested"),
    ("telemetry_audit", "minimum_disclosure_enforced"),
    ("telemetry_audit", "encrypted_log_required"),
    ("telemetry_audit", "hash_chain_required"),
    ("telemetry_audit", "access_review_workflow_available"),
    ("telemetry_audit", "raw_sensitive_payloads_excluded"),
    ("software_assurance", "sbom_present"),
    ("software_assurance", "component_intake_present"),
    ("software_assurance", "vulnerability_review_current"),
    ("software_assurance", "remediation_lifecycle_present"),
    ("software_assurance", "crypto_registry_provenance_bound"),
    ("human_factors", "agency_measured"),
    ("human_factors", "workload_measured"),
    ("human_factors", "control_and_override_available"),
    ("human_factors", "comfort_and_trust_optional"),
    ("human_factors", "participant_defined_value_included"),
    ("human_factors", "accessible_human_fallback_available"),
    ("provenance", "claim_source_dataset_method_result_review_linked"),
    ("provenance", "limitations_required"),
    ("provenance", "reproducibility_manifest_present"),
    ("provenance", "supersession_append_only"),
    ("forward_only_governance", "progression_monotonic"),
    ("forward_only_governance", "downgrade_rejected"),
    ("forward_only_governance", "correction_append_only"),
    ("forward_only_governance", "public_rank_export_prohibited"),
    ("forward_only_governance", "eligibility_use_prohibited"),
    ("non_actuation", "autonomous_body_or_device_control_prohibited"),
    ("non_actuation", "external_actions_require_explicit_approval"),
    ("non_actuation", "simulation_results_not_deployment_claims"),
    ("completion", "schema_validation_passed"),
    ("completion", "policy_tests_passed"),
    ("completion", "provenance_graph_passed"),
    ("completion", "sbom_gate_passed"),
    ("completion", "human_review_recorded"),
    ("completion", "open_questions_reported"),
)


def validate_t3_acceptance(document: dict[str, Any]) -> None:
    if document.get("criteria_version") != "IntegratedT3AcceptanceCriteria.v1":
        raise T3AcceptanceError("unsupported or missing criteria_version")

    specification_id = document.get("specification_id")
    if not isinstance(specification_id, str) or not specification_id.strip():
        raise T3AcceptanceError("specification_id must be a non-empty string")

    missing_or_false: list[str] = []

    for section, field in REQUIRED_TRUE_PATHS:
        value = document.get(section, {}).get(field)

        if value is not True:
            missing_or_false.append(f"{section}.{field}")

    if missing_or_false:
        joined = ", ".join(sorted(missing_or_false))
        raise T3AcceptanceError(
            f"T3 acceptance criteria not satisfied: {joined}"
        )

    _validate_sha256(
        document.get("decoder_evaluation", {}).get("analysis_plan_hash"),
        "decoder_evaluation.analysis_plan_hash",
    )


def _validate_sha256(value: Any, field_name: str) -> None:
    if not isinstance(value, str) or len(value) != 64:
        raise T3AcceptanceError(f"{field_name} must be a SHA-256 hex digest")

    if not all(character in "0123456789abcdefABCDEF" for character in value):
        raise T3AcceptanceError(f"{field_name} must be a SHA-256 hex digest")
