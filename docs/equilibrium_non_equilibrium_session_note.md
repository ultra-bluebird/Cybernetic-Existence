# Equilibrium and Non-Equilibrium Research Session Note

## Implemented scope

This session created the compact equilibrium/non-equilibrium research package:

- `docs/equilibrium_non_equilibrium_research_protocol.md` — full protocol with
  the ten required sections, exact mathematical definitions (generalized
  Lotka–Volterra dynamics, equilibrium condition, Jacobian stability criterion,
  observed entropy production, feasible envelope, normalized diagnostic Φ_F)
  each followed by plain-language interpretation, binding interpretation
  constraints, the seven named co-indicators, hypotheses H1–H3, and governance
  limits. Links to `docs/levy_trophic_dynamics_spec.md` (trophic shock /
  quasi-extinction risk) and
  `schemas/functional_redundancy_assessment.schema.json` (response diversity).
- `docs/equilibrium_non_equilibrium_data_dictionary.md` — Markdown tables with
  the columns Field | Type | Unit or encoding | Required | Privacy and
  governance notes | Validation rule covering all thirteen top-level schema
  fields plus nested temporal, spatial, constraint, entropy-production, flux,
  co-indicator, modeling, uncertainty, governance, and review fields; mandatory
  units (`W K^-1 m^-2`, `W m^-2`, `K`, documented local water-balance unit);
  explicit prohibition of exact sensitive habitat coordinates.
- `schemas/ecosystem_thermodynamic_research_record.schema.json` — JSON Schema
  Draft 2020-12 record schema with `additionalProperties: false` at every
  object level, required root fields, enums, constants, length bounds, and no
  location-precision or personal-data fields.
- `python/validate_ecosystem_thermodynamic_research_record.py` — standard-library
  semantic validator (`load_json`, `validate_record`, CLI) implementing the
  eleven focused checks, warning-not-error handling for out-of-range Φ_F, and
  exit codes 0/1/2.
- `tests/test_ecosystem_thermodynamic_schema.py` — unittest suite using an
  in-memory synthetic minimal valid record and the ten required assertions.

No runtime services, package installation, Rust tooling, external APIs, or
repository-wide discovery were used. No example record containing real
ecological measurements was fabricated; test values are clearly synthetic
placeholders.

## Validation performed

Focused checks run after editing (only the three prescribed commands):

1. `python -m json.tool schemas/ecosystem_thermodynamic_research_record.schema.json > /dev/null`
   — confirms the schema is complete, valid UTF-8 JSON. Outcome: PASS.
2. `python -m unittest tests/test_ecosystem_thermodynamic_schema.py`
   — runs the schema-integrity and validator test suite. Outcome: PASS
   (10 tests, OK). The first run failed to import the test module because the
   pre-existing `tests/` directory was not an importable package; per the
   focused-error procedure, the only fix applied was adding an empty
   `tests/__init__.py`, and the same check was re-run successfully.
3. `python -m py_compile python/validate_ecosystem_thermodynamic_research_record.py`
   — compiles the validator module. Outcome: PASS.

Additional local confirmation using only standard-library execution of the CLI:
a synthetic record passed with exit 0; a missing-baseline record exited 1; an
out-of-range diagnostic produced a `WARNING:` on stderr with exit 0; malformed
JSON, a non-object JSON root, and a missing file each exited 2. No example
record containing real ecological measurements was created.

## Known limits

- The schema describes a research record but does not validate physical
  correctness of measurements.
- The Python validator complements, but does not replace, JSON Schema
  validation.
- Entropy-production metrics remain context-dependent and require scientific
  and community review.
- No real ecological measurements are created by this milestone.

## Qwen Coder connection note

If the coding environment reports "Oops! There was an issue connecting to Qwen
Coder. Internal Error", preserve local edits and complete only the explicitly
scoped file changes and local Python checks. Do not repeatedly retry broad
repository analysis, dependency installation, or tool setup. Record whether the
error prevented any requested local validation.

Occurrence during this session: none observed. All three focused checks were
attempted locally without any connection error interrupting them.

## Follow-up review gate

Before any external publication, sensitive-habitat disclosure, restoration
claim, or decision use of this package or any record conforming to it:

1. Technical review of units, dimensional consistency, envelope derivation, and
   uncertainty propagation.
2. Ecological review of co-indicator interpretation and alternative
   explanations.
3. Community-governance review where affected communities have stakes.
4. Confirmation that prohibited uses (human/community ranking, automated
   enforcement, land displacement, benefit or service eligibility,
   protected-attribute inference, unreviewed publication of sensitive
   locations) are excluded downstream.

Material changes to constraints, envelopes, schema, or validator reopen this
gate; nothing in this package is self-certifying.
