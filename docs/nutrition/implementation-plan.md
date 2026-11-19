# Food, Hydration, and Experience Estimation Plan

## Status

Proposed implementation architecture.
No personalized targets, clinical validation, or operational integration
are implied. Private observations must not be committed to either repository.

## Directory structure

lua/
  food_hydration.lua
  nutrition/
    validate.lua
    units.lua
    food_composition.lua
    recipes.lua
    energy.lua
    protein.lua
    water.lua
    experience.lua
    uncertainty.lua
    calibration.lua
    estimate.lua
    report.lua

schemas/
  nutrition/
    observation.schema.json
    model_manifest.schema.json
    estimate.schema.json

policies/
  nutrition/
    access-and-consent.md
    model-applicability.md

docs/
  nutrition/
    implementation-plan.md
    mathematics.md
    measurement-protocol.md
    source-register.md
    validation-report.md

tests/
  nutrition/
    units_test.lua
    food_composition_test.lua
    recipes_test.lua
    energy_test.lua
    protein_test.lua
    water_test.lua
    experience_test.lua
    uncertainty_test.lua
    calibration_test.lua
    rights_test.lua

## Lua responsibilities

- food_hydration.lua:
  Retain the existing access-proposal interface. Food, water, and human
  assistance remain independent of intake logging or estimation success.

- validate.lua:
  Validate plain records, finite numbers, explicit units, time intervals,
  optional fields, and supported model inputs. Never convert missing
  observations to zero.

- units.lua:
  Perform explicit mass, volume, energy, and time conversions.
  Require an explicit density for mass-volume conversions.

- food_composition.lua:
  Calculate nutrient amounts from consumed edible mass and supplied
  composition records. Return known subtotals and nutrient-level coverage.
  Perform no network retrieval.

- recipes.lua:
  Aggregate ingredient nutrients, documented retention factors, finished
  recipe yield, and consumed portion mass.

- energy.lua:
  Evaluate approved published energy models using a supplied, reviewed
  coefficient manifest. Check population and activity applicability.
  Do not add activity expenditure already included in the selected model.

- protein.lua:
  Calculate reference-relative protein intake and between-day consistency.
  Keep dietary summaries separate from nitrogen-balance research inputs.
  Never label dietary intake as verified tissue maintenance.

- water.lua:
  Calculate total recorded intake and eligible session-specific sweat-loss
  estimates. Preserve unknown balance terms. Produce no automatic drinking
  schedule, universal deficit, or electrolyte dose.

- experience.lua:
  Validate optional hunger, thirst, and satiety reports.
  Accept accessible categorical alternatives.
  Keep BCI communication preferences separate from physiology.

- uncertainty.lua:
  Propagate documented input uncertainty and covariance.
  Require an explicit model-discrepancy assumption.
  Distinguish estimated intervals from validated interval coverage.

- calibration.lua:
  Compare estimates with explicitly supplied reference observations.
  Fit only approved parameters using training observations.
  Report holdout error, bias, coverage, and reference limitations.

- estimate.lua:
  Orchestrate pure calculations.
  Return independent result statuses for energy, protein, nutrients,
  water, hunger, and thirst. One unavailable estimate must not suppress
  other results or access proposals.

- report.lua:
  Generate a plain-language summary with units, interval, sources,
  missingness, applicability, uncertainty, and calibration status.
  Do not write files or export observations.

## Schemas

- observation.schema.json:
  Optional intake, portion, activity, experience, and measurement fields.
  Distinguish zero, unknown, not collected, and not applicable.

- model_manifest.schema.json:
  Model title, source citation, revision, coefficients, units,
  applicability, exclusions, and review status.

- estimate.schema.json:
  Structured result, unit, interval, input coverage, uncertainty method,
  applicability status, and calibration status.

## Governance documents

- access-and-consent.md:
  Separate permission for local processing, persistence, reminders,
  research use, and external disclosure. Specify correction, deletion,
  human fallback, and equal access without disclosure.

- model-applicability.md:
  Document model inclusion criteria, exclusions, review requirements,
  and behavior when a supported model is unavailable.

## Research documentation

- mathematics.md:
  Define equations, dimensions, assumptions, and double-counting checks.

- measurement-protocol.md:
  Define optional collection procedures and measurement limitations.
  Prohibit deprivation or forced exertion for model calibration.

- source-register.md:
  Record primary sources, revisions, unit conventions, and evidence gaps.

- validation-report.md:
  Record executed tests and empirical validation separately.
  Mark unexecuted tests and absent validation explicitly.

## Test responsibilities

- units_test.lua:
  Unit conversions, incompatible dimensions, invalid densities.

- food_composition_test.lua:
  Portion scaling, zero versus missing, incomplete composition.

- recipes_test.lua:
  Yield accounting, retention factors, portion aggregation.

- energy_test.lua:
  Published equation examples, applicability, activity double-counting.

- protein_test.lua:
  Reference selection, incomplete days, consistency calculations.

- water_test.lua:
  Food moisture, beverage intake, sweat-session accounting,
  invalid intervals, and negative inferred-loss review states.

- experience_test.lua:
  Optional reports, accessible categories, no deficit conversion.

- uncertainty_test.lua:
  Correlated inputs, unknown model error, reproducible calculations.

- calibration_test.lua:
  Training/holdout separation, bias, error, interval coverage.

- rights_test.lua:
  Food and water access with no personal inputs.
  Access after permission refusal or malformed estimation input.
  No identity inference, BCI multiplier, ranking, external action,
  forced reminder, or silent persistence.

## Integration order

1. Implement units, validation, composition, and recipes.
2. Add reviewed energy and protein reference manifests.
3. Add water accounting and optional experience reports.
4. Implement uncertainty and result reporting.
5. Validate baseline models before personal calibration.
6. Add accessible application adapters only after rights tests pass.

## Release boundary

The initial release is local decision support.
No network access, device control, purchasing, messaging, or record export.
External actions require a separate resolved-target approval workflow.
