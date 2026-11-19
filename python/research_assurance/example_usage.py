from python.research_assurance.invariant_gate import (
    ResearchRequest,
    evaluate_research_request,
)


synthetic_heat_research = ResearchRequest(
    purpose=(
        "Evaluate whether a synthetic heat anomaly should be routed to a "
        "human cooling-center and irrigation review workflow."
    ),
    uses_synthetic_or_public_data=True,
    includes_sensitive_personal_data=False,
    infrastructure_connection_requested=False,
    makes_individual_decision=False,
    requires_augmentation_disclosure_for_service=False,
    automation_interlocks_clear=True,
    automation_command_unexpired=True,
    automation_simulation_passed=True,
    aggregate_minimum_group_size_met=True,
    aggregate_disclosure_risk_acceptable=True,
    aggregate_voluntary_governance_confirmed=True,
    legal_jurisdiction_matched=False,
    legal_source_authoritative=False,
    legal_source_effective=False,
    legal_claim_entailment_confirmed=False,
    legal_outcome_prediction=False,
    accessibility_fallback_available=True,
    uncertainty_declared=True,
)

result = evaluate_research_request(synthetic_heat_research)

print(
    {
        "decision": result.decision.value,
        "reasons": result.reasons,
        "checks": dict(result.checks),
    }
)
