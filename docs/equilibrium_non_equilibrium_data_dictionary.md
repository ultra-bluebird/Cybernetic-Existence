# Equilibrium and Non-Equilibrium Data Dictionary

This dictionary documents every field used by
`schemas/ecosystem_thermodynamic_research_record.schema.json`. All values are
research and decision support subject to human scientific and community-governance
review. No field in this record may contain personal, household, biometric,
assistive-technology, neural, medical, or identity data.

## Top-level fields

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `record_version` | string | Semantic version `MAJOR.MINOR.PATCH` | Yes | Version changes signal schema-evolution provenance only; no personal data. | Must match `^[0-9]+\.[0-9]+\.[0-9]+$` |
| `record_id` | string | Plain identifier, 1–160 characters | Yes | Must not encode person, household, device, or exact-location identifiers. | Length 1–160; unique within a study register |
| `purpose` | string enum | One of `research`, `restoration_monitoring`, `ecological_risk_assessment`, `method_validation` | Yes | Purpose limitation: records may only be used for the declared purpose. | Value must be one of the four enumerated purposes |
| `ecosystem_context` | string enum | One of `desert`, `monsoon`, `riparian`, `urban_green`, `restoration`, `mixed`, `other_documented` | Yes | Context labels are ecological only; they must not proxy community or landholder identity. | Value must be one of the seven enumerated contexts |
| `temporal_scope` | object | See Temporal scope table | Yes | Time ranges must not be fine-grained enough to identify individual visits or people. | Object with required date fields; start ≤ end |
| `spatial_scope` | object | See Spatial scope table | Yes | Exact sensitive habitat coordinates must not be placed in this record. Only coarse, plain-language spatial references are permitted. | Object with area reference, positive resolution, sensitivity class |
| `constraint_vector` | object | See Constraint vector table | Yes | Constraint descriptions must stay environmental; no management-identity details about persons or households. | Seven named constraint objects, each fully documented |
| `entropy_production` | object | See Entropy production table | Yes | Derived diagnostics are advisory; out-of-range values flag review, never automated action. | Envelope strictly ordered; finite numbers; unit constant |
| `co_indicators` | object | See Co-indicators table | Yes | Co-indicator text must avoid species locations precise enough to enable harvesting or disturbance. | Seven named indicator objects, all documented |
| `modeling` | object | See Modeling table | Yes | Modeling claims require baseline comparisons and a falsification plan; no universal-health claims. | Constants true; ≥4 unique baselines; falsification plan text |
| `uncertainty` | object | See Uncertainty table | Yes | Uncertainty documentation is mandatory; unquantified results must not be published as decisions. | Method enum; four inclusion flags constant true |
| `governance` | object | See Governance table | Yes | Encodes data minimization, habitat protection, review requirements, and prohibited uses. | Four flags constant true; ≥4 unique prohibited uses incl. mandated four |
| `review` | object | See Review table | Yes | A record is never self-certifying; material changes force re-review. | Status enum; basis text; material-change flag constant true |

## Ecosystem context enumeration

`ecosystem_context` must be exactly one of:

- `desert`
- `monsoon`
- `riparian`
- `urban_green`
- `restoration`
- `mixed`
- `other_documented`

No universal thermodynamic optimum is presumed across these contexts; feasible
envelopes are context-specific (hypothesis H3).

## Purpose enumeration

`purpose` must be exactly one of:

- `research`
- `restoration_monitoring`
- `ecological_risk_assessment`
- `method_validation`

## Temporal scope (`temporal_scope`)

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `temporal_scope.start_date` | string | ISO 8601 calendar date (`format: date`) | Yes | Dates must not resolve to individual observation events tied to people. | Valid date string; ≤ `end_date` |
| `temporal_scope.end_date` | string | ISO 8601 calendar date (`format: date`) | Yes | Same as start date. | Valid date string; ≥ `start_date` |
| `temporal_scope.sampling_interval` | string | Plain-language cadence description, 1–120 characters | Yes | Cadence description only; no observer identities. | Non-empty, max length 120 |

## Spatial scope (`spatial_scope`)

Exact sensitive habitat coordinates must not be placed in this record. The
schema permits only the three fields below — no latitude, longitude, geometry,
address, device identifier, person identifier, household identifier, or any
equivalent location-precision field.

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `spatial_scope.area_reference` | string | Plain-language area description, 1–500 characters | Yes | Must be coarse and non-navigational; must not reveal exact habitat locations. | Non-empty string, max length 500 |
| `spatial_scope.spatial_resolution_meters` | number | Meters (metres of aggregation grid) | Yes | Coarser resolutions protect sensitive habitats; choose minimum necessary precision. | Finite number strictly greater than 0 |
| `spatial_scope.sensitivity_class` | string enum | One of `public`, `aggregated_only`, `restricted` | Yes | Drives publication aggregation rules; `restricted` sites are never externally disclosed at site level. | Must be one of the three enumerated classes |

## Constraint vector (`constraint_vector`)

Seven required constraint components: `radiative_forcing`,
`water_availability`, `temperature_boundary`, `soil_or_substrate`,
`vegetation_structure`, `hydrologic_connectivity`, `disturbance_boundary`.
Each is an object with the same four fields:

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `<constraint>.value` | number | Documented physical unit carried in `unit` | Yes | Environmental measurement only; no person-linked metadata. | Finite number (no NaN/Infinity); unit mandatory |
| `<constraint>.unit` | string | Unit expression, 1–80 characters | Yes | Units must be explicit; unitless numeric claims are rejected downstream. | Non-empty string, max length 80 |
| `<constraint>.source_description` | string | Prose, 20–2000 characters | Yes | Provenance for instruments/models; omit operator or landholder identities. | String length 20–2000 |
| `<constraint>.uncertainty_description` | string | Prose, 20–2000 characters | Yes | Every constraint value requires documented uncertainty. | String length 20–2000 |

## Entropy production (`entropy_production`)

Required units for physical fields:

- entropy-production values: `W K^-1 m^-2`
- energy flux values: `W m^-2`
- temperature values: `K`
- water balance values: explicitly documented local unit

For every numeric physical field in this section, the unit is mandatory and a
finite numeric value is required (NaN and infinities are rejected).

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `entropy_production.observed_entropy_production` | number | `W K^-1 m^-2` (fixed by `entropy_production_unit`) | Yes | Estimate of Σ_k J_k X_k; advisory, never a standalone health verdict. | Finite number |
| `entropy_production.entropy_production_unit` | string | Constant `W K^-1 m^-2` | Yes | Fixed unit prevents silent unit drift between studies. | Must equal `W K^-1 m^-2` |
| `entropy_production.feasible_minimum` | number | `W K^-1 m^-2` | Yes | Σ_min^F(C), the infimum of the documented feasible set. | Finite number; strictly less than `feasible_maximum` |
| `entropy_production.feasible_maximum` | number | `W K^-1 m^-2` | Yes | Σ_max^F(C), the supremum of the documented feasible set. | Finite number; strictly greater than `feasible_minimum` |
| `entropy_production.normalized_diagnostic` | number | Dimensionless Φ_F (expected range [0, 1]) | Yes | Out-of-range values are diagnostic signals (uncertainty, boundary mismatch, missing processes, measurement error, misspecification); do not clip. | Finite number; out-of-range produces a WARNING, not rejection |
| `entropy_production.flux_components` | array | Items per Flux component table; ≥1 item | Yes | Each component's flux and force must be dimensionally consistent. | Array with at least one fully documented component |
| `entropy_production.boundary_assumptions` | string | Prose, 40–4000 characters | Yes | Must let a reviewer reproduce the envelope; no site-precise locating detail. | String length 40–4000 |

### Flux component (`entropy_production.flux_components[*]`)

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `name` | string | Process label (e.g. sensible heat) | Yes | Process names only; no instrument-operator identity. | Non-empty string |
| `flux_value` | number | Energy flux: `W m^-2`; other fluxes use documented units | Yes | Measured or modelled flux `J_k`. | Finite number; unit mandatory |
| `flux_unit` | string | Unit expression, 1–80 characters | Yes | Explicit unit required for every numeric flux. | Non-empty string, max length 80 |
| `force_value` | number | Conjugate force unit (documented; temperature forces in `K` denominators as applicable) | Yes | Thermodynamic force `X_k`. | Finite number; unit mandatory |
| `force_unit` | string | Unit expression, 1–80 characters | Yes | Explicit unit required for every numeric force. | Non-empty string, max length 80 |
| `contribution_value` | number | Constant `W K^-1 m^-2` | Yes | Product J_k·X_k contribution to Σ_obs. | Finite number; must be `W K^-1 m^-2` unit |
| `contribution_unit` | string | Constant `W K^-1 m^-2` | Yes | Fixed unit keeps contributions summable. | Must equal `W K^-1 m^-2` |
| `measurement_method` | string | Prose description of retrieval/instrument method | Yes | Provenance only; no personal data. | Non-empty string |
| `uncertainty_description` | string | Prose, 20–2000 characters | Yes | Propagated uncertainty must be described per component. | String length 20–2000 |

## Co-indicators (`co_indicators`)

All seven co-indicators are required: `functional_effect_diversity`,
`response_diversity`, `water_balance_indicator`,
`habitat_structure_indicator`, `disturbance_history`,
`recovery_time_indicator`, `quasi_extinction_risk`. Each is an object with:

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `status` | string enum | One of `available`, `not_available`, `not_applicable` | Yes | Honest availability reporting; absence must not silently degrade interpretation. | Must be one of the three statuses |
| `value_description` | string | Prose, 20–2000 characters; water-balance values carry an explicitly documented local unit | Yes | No harvest-sensitive species locations; no protected-community attributes. | String length 20–2000 |
| `method_description` | string | Prose, 20–2000 characters | Yes | Survey/model method provenance; anonymized. | String length 20–2000 |
| `uncertainty_description` | string | Prose, 20–2000 characters | Yes | Every derived value needs an uncertainty interval or documented limit. | String length 20–2000 |

## Modeling (`modeling`)

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `modeling.equilibrium_reference_included` | boolean | Constant `true` | Yes | Confirms equilibrium baselines were considered before invoking non-equilibrium claims. | Must equal `true` |
| `modeling.non_equilibrium_diagnostic_included` | boolean | Constant `true` | Yes | Confirms the constraint-matched diagnostic is part of the analysis. | Must equal `true` |
| `modeling.baseline_comparisons` | array of string enum | ≥4 unique entries from `climate_only`, `vegetation_only`, `biodiversity_only`, `hydrology_only`, `combined_conventional`, `documented_other` | Yes | H2 requires all four single-domain baselines be compared. | Unique items; must include `climate_only`, `vegetation_only`, `biodiversity_only`, `hydrology_only` |
| `modeling.falsification_plan` | string | Prose, 40–4000 characters | Yes | Pre-committed falsification criteria prevent post-hoc health claims. | String length 40–4000 |

## Uncertainty (`uncertainty`)

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `uncertainty.method` | string enum | One of `bootstrap`, `bayesian_posterior`, `ensemble`, `sensitivity_analysis`, `documented_other` | Yes | Named method ensures reproducibility. | Must be one of the five methods |
| `uncertainty.parameter_uncertainty_included` | boolean | Constant `true` | Yes | Parameter spread must be propagated. | Must equal `true` |
| `uncertainty.measurement_uncertainty_included` | boolean | Constant `true` | Yes | Instrument/retrieval error must be propagated. | Must equal `true` |
| `uncertainty.boundary_uncertainty_included` | boolean | Constant `true` | Yes | Boundary-condition choice must be propagated. | Must equal `true` |
| `uncertainty.missing_process_risk_documented` | boolean | Constant `true` | Yes | Known unknowns (omitted flux pathways) must be recorded. | Must equal `true` |

## Governance (`governance`)

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `governance.data_minimization` | boolean | Constant `true` | Yes | Only minimum necessary data collected. | Must equal `true` |
| `governance.sensitive_habitat_protection` | boolean | Constant `true` | Yes | Sensitive-habitat location protections applied. | Must equal `true` |
| `governance.human_scientific_review_required` | boolean | Constant `true` | Yes | No output bypasses scientific review. | Must equal `true` |
| `governance.community_governance_review_required` | boolean | Constant `true` | Yes | Affected-community review is mandatory where stakes exist. | Must equal `true` |
| `governance.prohibited_uses` | array of string enum | ≥4 unique entries from `human_or_community_ranking`, `automated_enforcement`, `land_displacement_decision`, `benefit_or_service_eligibility`, `protected_attribute_inference`, `unreviewed_publication_of_sensitive_locations` | Yes | Declares hard exclusions on downstream use. | Unique items; must include the first four listed values |

## Review (`review`)

| Field | Type | Unit or encoding | Required | Privacy and governance notes | Validation rule |
|---|---|---|---|---|---|
| `review.review_status` | string enum | One of `draft`, `technical_review`, `ecological_review`, `community_review`, `approved_for_research_use`, `withdrawn` | Yes | Lifecycle tracking; external use requires approval state. | Must be one of the six statuses |
| `review.review_basis` | string | Prose, 20–3000 characters | Yes | Names reviewers' remit and evidence; no personal identifiers required. | String length 20–3000 |
| `review.material_change_review_required` | boolean | Constant `true` | Yes | Any material change reopens the review lifecycle. | Must equal `true` |
