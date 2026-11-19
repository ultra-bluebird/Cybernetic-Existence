local Checklist = {}

local function item(
    id,
    category,
    requirement,
    evidence_required,
    severity,
    acceptance
)
    return {
        id = id,
        category = category,
        requirement = requirement,
        evidence_required = evidence_required,
        severity = severity,
        acceptance = acceptance,
    }
end

return {
    schema_version = "1.0",
    checklist_id = "cybernetic-host-compatibility",
    title = "Cybernetic Host Compatibility Checklist",
    scope = {
        "ai_tool",
        "browser_feature",
        "smart_city_service",
    },
    evaluation_scale = {
        "satisfied",
        "partially_satisfied",
        "not_satisfied",
        "not_applicable",
        "insufficient_evidence",
    },
    required_result_fields = {
        "system_id",
        "system_type",
        "assessment_date_utc",
        "assessor_reference",
        "evidence_reference",
        "overall_status",
    },
    items = {
        item(
            "identity-self-assertion",
            "identity",
            "The system accepts self-asserted identity claims without requiring third-party certification for ordinary access.",
            "Published policy, tested decision path, or local evaluation result.",
            "critical",
            "satisfied"
        ),
        item(
            "identity-verifiability-neutrality",
            "identity",
            "Identity verifiability status does not reduce eligibility, access, priority, or service quality.",
            "Policy rule and representative decision evidence.",
            "critical",
            "satisfied"
        ),
        item(
            "privacy-data-minimization",
            "privacy",
            "The system minimizes personal data collection and does not require raw identifiers when a redacted or pseudonymous reference is sufficient.",
            "Data-flow inventory and field-level disclosure review.",
            "critical",
            "satisfied"
        ),
        item(
            "privacy-local-redaction",
            "privacy",
            "Messages, logs, AI inputs, and policy reports can be redacted locally before external processing or publication.",
            "Redaction test output showing no direct identifiers in exported content.",
            "critical",
            "satisfied"
        ),
        item(
            "continuity-interface-change",
            "continuity",
            "A legitimate change in assistive interface, device, or interaction modality does not automatically break identity continuity or service access.",
            "Continuity policy and interface-transition test result.",
            "critical",
            "satisfied"
        ),
        item(
            "assistive-technology-necessity",
            "accessibility",
            "Assistive technology is treated as an individual necessity when declared, not as an optional convenience.",
            "Accessibility policy and accommodation workflow evidence.",
            "critical",
            "satisfied"
        ),
        item(
            "assistive-equivalent-access",
            "accessibility",
            "The system provides an equivalent path to complete core tasks using declared assistive technologies.",
            "Task-completion accessibility test results.",
            "critical",
            "satisfied"
        ),
        item(
            "assistive-fallback-path",
            "accessibility",
            "The system offers a documented non-punitive fallback when an assistive interface cannot complete a task.",
            "Support procedure and fallback-path test record.",
            "high",
            "satisfied"
        ),
        item(
            "decision-explainability",
            "governance",
            "Access, service, and policy decisions produce understandable reasons without exposing private identity data.",
            "Decision explanation examples with privacy review.",
            "high",
            "satisfied"
        ),
        item(
            "equal-treatment-auditability",
            "governance",
            "The system supports local audit of outcomes for penalties tied to unverifiable or self-asserted identity status.",
            "Audit schema, sampled decision records, and audit output.",
            "critical",
            "satisfied"
        ),
        item(
            "non-discrimination-guard",
            "governance",
            "The system prohibits discriminatory rules based on augmentation status, assistive use, interface modality, or identity verifiability.",
            "Formal policy evaluation and rule inventory.",
            "critical",
            "satisfied"
        ),
        item(
            "consent-revocation",
            "consent",
            "The system records consent scope and provides a clear process to stop future optional data sharing without punitive loss of essential access.",
            "Consent template, revocation procedure, and test outcome.",
            "critical",
            "satisfied"
        ),
        item(
            "offline-safe-operation",
            "resilience",
            "Core identity, accessibility, and safety functions retain a documented local or offline-safe mode.",
            "Offline test record and operational boundary description.",
            "high",
            "satisfied"
        ),
        item(
            "public-accountability",
            "governance",
            "Public-facing services disclose aggregate fairness and accessibility outcomes without publishing personal records.",
            "Public registry entry or privacy-preserving accountability report.",
            "high",
            "satisfied"
        ),
        item(
            "ecological-workflow-awareness",
            "eco_restoration",
            "The system reports operational energy or material impacts when they are material to service design, and does not claim ecological benefits without evidence.",
            "Bounded energy or material assessment with cited measurement method.",
            "medium",
            "satisfied"
        ),
    },
    scoring = {
        satisfied = 1.0,
        partially_satisfied = 0.5,
        not_satisfied = 0.0,
        not_applicable = nil,
        insufficient_evidence = 0.0,
        minimum_overall_score = 0.85,
        critical_item_requirement = "satisfied",
    },
    metrics = {
        knowledge_factor = {
            range = { 0.0, 1.0 },
            definition = "Evidence completeness and assessment reliability.",
        },
        eco_impact_value = {
            range = { 0.0, 1.0 },
            definition = "Evidence-backed expected ecological benefit, if materially applicable.",
        },
        harm_risk = {
            range = { 0.0, 1.0 },
            definition = "Potential privacy, accessibility, continuity, or ecological harm from unresolved incompatibilities.",
        },
    },
}
