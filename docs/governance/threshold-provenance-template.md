# Threshold Provenance Template

## Purpose

This document records the provenance, authority, intended use, and change controls for thresholds used by Augmented-Hub.

A threshold is not self-justifying because it is numeric, historically used, or convenient for implementation.

## Threshold record

| Threshold name | Current value | Category | Applies to | Rationale | Evidence basis | Decision authority | Change process | Anti-regression requirement | Review cadence | Active status |
|---|---|---|---|---|---|---|---|---|---|---|
| `knowledge_factor_minimum` | Documented project value | Calibration default or governance invariant | Defined planning context | Plain-language rationale | Source-oriented research note or project charter rationale | Declared governance role | Accessible review, documented impact analysis, versioned approval | Change may not conceal weaker evidence requirements or bypass review | Declared interval and trigger conditions | `active`, `under_review`, `retired` |

## Threshold categories

- `governance_invariant`: a rights, privacy, accessibility, or auditability boundary that cannot be weakened by a model result.
- `research_default`: a provisional value used only while calibration evidence is incomplete.
- `calibration_parameter`: an empirically revisable value tied to a stated model version and validation context.
- `community_reviewed_parameter`: a context-specific value established through an accessible community process.
- `operational_safety_boundary`: a boundary that triggers review, pause, or restricted use pending further evidence.

## Change controls

Every proposed threshold change must include:

- A clear explanation of the proposed old and new values.
- The affected metrics, workflows, and communities.
- A sensitivity analysis or reasoned impact assessment.
- An accessibility impact statement.
- A privacy and rights-alignment statement.
- A description of whether the proposal increases the chance of false assurance, exclusion, surveillance, or under-maintenance.
- A documented human-review and appeal pathway.
- A versioned changelog entry.

No threshold change may silently alter historical interpretation. Historical outputs retain the threshold version used at the time of evaluation.
