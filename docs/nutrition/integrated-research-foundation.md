# Food, Hydration, and Augmented Access:
# Integrated Research and Evidence Foundation

## Status and purpose

This document integrates the supplied Augmented-Crypto Session Ledger
with this conversation's food, hydration, protein, nutrient-composition,
hunger, thirst, augmented-ruleset, and BCI-dimension research.

It is a research specification, not an execution receipt, clinical
assessment, personalized prescription, or validated scientific model.

All paths describe proposed repository destinations. This document does
not claim that files were written, software ran, participants were
engaged, or measurements were collected.

The supplied session ledger is historical material furnished for
integration. Its execution counts and milestone claims are not
independently verified by this document.

## 1. Foundational separation

Keep these assessments separate:

1. Pathway membership:
   Whether a proposed method falls within a documented pathway definition.

2. Input adequacy:
   Whether the available observations and metadata support the proposed
   calculation within its declared scope.

3. Estimated benefit:
   Whether a proposed change improves a specified research or service
   outcome relative to an explicit comparator.

4. Operational acceptance:
   Whether a particular deployment or external action is approved under
   applicable constraints.

Membership does not establish adequacy.
Adequacy does not establish benefit.
Benefit does not authorize deployment.
Operational acceptance does not establish scientific validity.

The supplied term "intradetrenous pathway" is retained as project
vocabulary. Its complete definition is not supplied here. No biological
mechanism, nutritional adjustment, delivery route, or implementation
is inferred from the term.

## 2. What is being estimated

| Quantity | Proposed output | Required distinction |
|---|---|---|
| Caloric needs | Applicable reference-model estimate | Estimate versus personal requirement |
| Caloric demands | Expenditure over a declared interval | Model prediction versus measured expenditure |
| Protein adequacy | Intake relative to a selected reference | Dietary intake versus body-protein balance |
| Protein consistency | Variation across sufficiently recorded days | Consistency versus physiological stability |
| Nutrient composition | Known nutrient subtotal and coverage | Unknown versus zero |
| Water intake | Recorded food and beverage water | Intake versus hydration state |
| Water demand | Context-specific loss estimate or balance terms | Estimated losses versus measured deficit |
| Hunger | Optional reported experience | Experience versus inferred energy deficit |
| Thirst | Optional reported experience | Experience versus inferred water deficit |

No output is an eligibility score.

## 3. Mathematical objects and evidence requirements

The equations below preserve the prior conversation's proposed model
structure. Implementing an equation does not validate its applicability.

### 3.1 Energy

Energy balance over a common interval:

    change_in_stored_energy = intake_energy - expenditure_energy

Expenditure decomposition:

    TEE = REE + AEE + TEF

Reference estimate:

    estimated_requirement = published_model(inputs, model_manifest)

Evidence required before making a reference-model claim:

- Exact source, revision, coefficients, units, and population.
- Applicability conditions and exclusions.
- Published-example reproduction where available.
- Explicit treatment of activity already included in the model.
- Output uncertainty or an explicit unquantified-uncertainty label.

No BCI, CyberRank, or self-description multiplier is permitted.

### 3.2 Nutrient composition

For nutrient j:

    known_nutrient_j =
        sum(consumed_edible_mass_i_g / 100 * composition_ij_per_100g)

Sum only terms with available composition values.

Return:

- Known subtotal.
- Known and unknown contributing portions.
- Source and preparation-state matches.
- Coverage description.
- Whether a complete total can be reported.

Do not report the known subtotal as a complete total when contributions
are missing.

### 3.3 Protein

Reference amount:

    protein_reference_g_day = applicable_mass_kg * reference_g_kg_day

Reference-relative intake:

    protein_ratio = recorded_protein_g_day / protein_reference_g_day

Consistency:

    mean_protein = sum(complete_day_intakes) / complete_day_count
    protein_cv = sample_standard_deviation / mean_protein

The coefficient of variation is unavailable when its denominator or
sample-size requirements are not met.

A reference ratio is not evidence of tissue retention.
A consistency statistic is not evidence of nitrogen balance.
Incomplete days must not silently enter complete-day averages as zeros.

### 3.4 Water

Balance over a common interval:

    water_change =
        beverage_water + food_water + metabolic_water
        - urine_water - fecal_water - sweat_water
        - respiratory_and_other_skin_water

Return unknown balance status when required terms are unavailable.

A session-specific sweat-loss approximation may be implemented only
with its declared measurement assumptions, unit conversions, interval,
and applicability checks.

Negative inferred losses require review. Do not silently clamp them to
zero and describe the result as measured loss.

### 3.5 Hunger and thirst

Use optional user-selected categorical or ordinal reports.

Keep these distinct:

- Reported experience.
- Assistance requested.
- Model prediction of a future report.
- Physiological deficit estimate.

Do not convert an ordinal hunger score directly into kcal.
Do not convert an ordinal thirst score directly into liters.

A person may request food or water regardless of the recorded score.

### 3.6 Uncertainty and validation

For a derived quantity y = g(x), a proposed first-order approximation is:

    variance_y = J * covariance_x * transpose(J) + model_error_variance

The approximation requires documented assumptions.

If model error is unquantified, say so.
Do not describe input-error propagation alone as total predictive
uncertainty.

When appropriate reference observations exist:

    MAE  = mean(abs(prediction - reference))
    bias = mean(prediction - reference)

Report these with reference limitations, sample scope, missingness,
training/holdout separation, and interval coverage where applicable.

No fixed accuracy percentage is asserted by this document.

## 4. Independent evidence axes

Each result or review must carry independent fields.

| Axis | Example vocabulary | What it does not establish |
|---|---|---|
| Source availability | available, unavailable | Authenticity or correctness |
| Parse | not_started, passed, failed | Execution |
| Execution | not_started, in_progress, completed, terminated, outcome_lost | Scientific validity |
| Assertion outcome | not_started, in_progress, passed, failed, assertion_error, outcome_lost | Measurement truth |
| Observation | reported, instrument_recorded, derived, unavailable | Accuracy by itself |
| Assessment | not_assessed, supported, contradicted, conflicted, inconclusive | Authorization |
| Applicability | applicable, not_applicable, unresolved | Calibration |
| Calibration | uncalibrated, fitted, holdout_evaluated | Transfer to other settings |
| Authenticity | not_assessed, checked, check_failed | Authority or validity |
| Authority | not_assessed, authorized_for_scope, unauthorized_for_scope | Truth of a measurement |
| Freshness | current_for_declared_scope, stale, unresolved | Completeness |
| Action approval | absent, approved_for_exact_action, denied | Completion of the action |

These vocabularies are proposed for this nutrition workstream.
They do not silently replace another module's versioned vocabulary.

A signed food log can still contain inaccurate entries.
A passing unit test can still implement an inapplicable model.
A current composition source can still be matched to the wrong food.
An approved action can still fail to complete.

## 5. Non-compensatory improvement

Evaluate a candidate change relative to a declared baseline.

Let:

- Q = estimation and evidence quality.
- A = access fidelity.
- C = satisfaction of declared continuity constraints.
- R = satisfaction of rights and privacy constraints.

A proposed improvement claim requires:

    Q_candidate >= Q_baseline
    AND A_candidate >= A_baseline
    AND at least one documented strict improvement
    AND C is satisfied
    AND R is satisfied

Continuity is a constraint, not a compensable score.

A stronger calorie estimate cannot compensate for:
- Loss of a non-digital food or water access route.
- Mandatory identity disclosure.
- Forced intake logging.
- Unapproved interruption of an assistive workflow.
- Removal of a human fallback.
- Unauthorized disclosure or external action.

If a required comparison is unknown, report the improvement claim as
unresolved. Do not fabricate a scalar score that hides the uncertainty.

## 6. BCI dimensions and CyberRank governance

BCI dimensions remain optional interaction preferences:

- Communication route.
- Response pacing.
- Sensory presentation.
- Continuity preference.

They do not establish:
- Neural measurements.
- Device identity.
- Biological energy consumption.
- Protein turnover.
- Water loss.
- Nutritional eligibility.
- Authority over a companion or institutional system.

CyberRank personal context remains private and voluntary.

CyberRank governance requires:
- Equal access.
- Minimal disclosure.
- Accessible communication.
- Human fallback.
- Correction and appeal.
- Material-change review.
- Non-interference.

A missing profile must not become a missing service entitlement.

## 7. Corrections adopted from the supplied ledger

### Evidence and provenance

- A SHA-256 commitment and a signature serve different purposes.
- A matching commitment does not authenticate a producer.
- A valid signature does not establish nutritional accuracy.
- A renderer header is not producer provenance.
- Caller-asserted flags are not independently verified observations.
- Cross-process receipt uniqueness needs a defined durable mechanism.
- Historical execution reports must not be promoted into new execution
  evidence merely by copying them.

No cryptographic implementation is added by this document.

If commitment hashing is later implemented, use the project's approved
sha2 SHA-256 implementation. Do not publish personal-data commitments
by default or describe hashing as anonymization.

### Runtime and completion

- Parse success, invocation, execution, and completion are distinct.
- A stop request is not a stop confirmation.
- An assertion failure is distinct from a harness error.
- A missing terminal report is distinct from never starting.
- Framework cleanup is not runtime containment.
- Restricted name resolution is not CPU, memory, or native-call
  containment.

### Presentation and retention

- Text and tables are the primary presentation.
- AR remains optional.
- Presentation structure does not establish task usability.
- No detected correlation is not a general unlinkability claim.
- No observed egress requires an explicit monitoring-coverage statement.
- Deleting a local record does not recall shared or downloaded copies.
- A delayed callback must not recreate a logically deleted record.

### Numerical and language handling

- Do not treat an integral numeric table key as preserving a separately
  distinguishable integer-versus-float representation.
- Avoid Lua and/or defaulting where false or nil has semantic meaning.
- Keep evidence-information joins separate from constraint conjunction.
- Preserve numeric profile and runtime assumptions explicitly.

Version-specific Lua claims from the historical ledger remain items
for source review and runtime probes, not new verified findings here.

## 8. Evidence package

Every executable research milestone must record:

- Scope and exact claim.
- Source revision and runtime profile.
- Synthetic or permissioned input classification.
- Input bounds and units.
- Reproducible procedure.
- Assertions planned before execution.
- Per-assertion observed outcomes.
- Negative-control raw outcome.
- Negative-control interpretation.
- Missing harness reports.
- Runtime/build configuration.
- Results and retained artifacts.
- What was and was not established.
- Access, privacy, continuity, and authority review.
- Retention and deletion rules.

An expected-failure negative control retains raw outcome "failed".
Its interpretation may separately be "control behaved as expected".

Do not change the raw failure into a workload pass.

Document-review milestones use an explicit review procedure rather than
pretending a prose document executed. Where an executable negative
control is not applicable, record that limitation and the substitute
challenge review. This is a proposed clarification to the supplied
ledger's blanket negative-control requirement.

## 9. Nutrition research milestones

Status vocabulary:

    not_started
    in_progress
    blocked
    passed
    failed
    inconclusive

Status applies to a scoped claim and evidence level, not to an entire
topic indiscriminately.

| Milestone | Scope | Current position | Gate |
|---|---|---|---|
| Definitions | Separate intake, need, demand, and experience | Drafted; review not_started | Terminology review |
| Runtime baseline | Parse and execute the nutrition demonstrator | not_started | Retained runtime output |
| Composition arithmetic | Portions, units, missing values | not_started | Golden-case and negative-control evidence |
| Energy baseline | Reproduce a reviewed published model | not_started | Applicability and example checks |
| Protein summaries | Reference ratios and consistency | not_started | Missing-day and zero-denominator tests |
| Water accounting | Intake and scoped loss accounting | not_started | Unit and invalid-session tests |
| Evidence rendering | No axis promotion or collapse | not_started | Deliberately misleading-record tests |
| Access safeguards | Access without logging or metadata | not_started | Refusal and malformed-input tests |
| Calibration | Fit only against suitable references | not_started | Training and holdout report |
| Accessible use | Users understand the distinctions | not_started | Permissioned task evaluation |
| Retention | Deletion covers declared derivatives | not_started | Adapter and late-writer tests |

A milestone may pass software verification without passing scientific
validation. Record those as separate assessments.

## 10. Dependency-ordered research queue

### First executable slice

Build a self-contained Lua nutrition demonstrator using synthetic data.

It should:
1. Accept a food and water access request.
2. Calculate a composition subtotal with one missing nutrient value.
3. Preserve an optional hunger or thirst report.
4. Display independent evidence axes.
5. Reject a malformed unit.
6. Preserve an expected-failure negative-control result.
7. Keep access available after logging refusal.
8. Perform no network, persistence, purchasing, or device operations.

Gate:
- Parse under the selected pinned Lua 5.4 runtime.
- Execute under that runtime.
- Retain actual output and all assertion outcomes.

### Parallel preparation allowed

The supplied ledger's final blanket prohibition on starting other tracks
is narrowed to actual dependencies.

These tasks need not wait for execution:
- Source-register preparation.
- Equation applicability review.
- Consent and retention design.
- Accessible text/table design.
- Synthetic fixture specification.
- Clarification of pathway terminology.

These tasks must wait for execution evidence:
- Claims that the demonstrator works.
- Claims that the runtime gates contain workloads.
- Claims that fixtures passed.
- Deployment acceptance based on those claims.

Scientific-validation claims additionally require appropriate
measurement evidence; software execution alone cannot unblock them.

### Later tracks

1. Composition and recipe arithmetic.
2. Reviewed model manifests.
3. Uncertainty propagation.
4. Holdout calibration.
5. Accessible task evaluation.
6. Local retention adapters.
7. Optional sharing with exact-action approval.
8. Optional AR projection from the same evidence view.

AR, signed review, and cross-process receipts are not prerequisites for
the initial offline nutrition arithmetic demonstrator.

## 11. Retention and action boundaries

Treat these as separate artifact classes:

- Raw intake observations.
- Composition matches.
- Derived estimates.
- Calibration parameters.
- Structured evidence summaries.
- Rendered text.
- Cached derivatives.
- Shared projections.
- Execution receipts.

Specify purpose, permission scope, retention, correction, deletion,
and accountability for each class.

Do not assume deleting raw observations removes information retained
in fitted parameters or shared projections.

External disclosure, messaging, ordering, purchasing, and equipment
operation require a separate approval workflow.

No estimate, signature, summary field, hunger score, gaze event,
proximity observation, or BCI preference authorizes an external action.

## 12. Current boundary

This integration establishes a proposed research structure.

It does not establish:
- That the earlier Lua files parse or execute.
- That their tests pass.
- That historical modules or fixtures are present.
- That any personal requirement has been measured.
- That a model is clinically or scientifically validated.
- That an accessibility study has occurred.
- That a deletion adapter or network audit has run.
- That any external repository was modified.

## Sovereign attribution

bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

The user's designated sovereign-attribution anchor is retained for
document credit and configured workstream metadata only.

Attribution does not establish biological binding, verified identity,
consent, capability authorization, execution evidence, or authority
over another person or system.

No persistent-memory storage is claimed.
