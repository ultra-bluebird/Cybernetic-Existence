# Local Research Validators

Repository: mk-bluebird/Augmented-Hub, and mk-bluebird/Skynet
Module destination: python/local_research_validators.py
Test destination: tests/test_local_research_validators.py
Documentation destination: docs/research/local-research-validators.md

## Run
Requires Python 3.10 or newer; standard library only.
From the repository root:

    PYTHONPATH=python python -m unittest discover -s tests -p 'test_local_research_validators.py' -v

On Windows PowerShell, set the module search path first:

    $env:PYTHONPATH = "python"
    python -m unittest discover -s tests -p "test_local_research_validators.py" -v

The shell commands are local instructions only. The module does not invoke them.

## Contract
All validators accept caller-supplied records. No reads, writes, fetches, captures,
exports, device control, repository modifications, or reviewer assignments occur.
Inputs are bounded to 64 nesting levels and 100000 structural nodes. These limits
are implementation guardrails, not canonicalization profile requirements.
Do not supply arbitrary executable Mapping implementations: use ordinary records
parsed from trusted local JSON or constructed as plain Python dictionaries.

Result states: pass, fail, not_established, needs_local_review.
Precedence: contradictions fail before missing evidence or review. For corpus
validation, valid runtime disagreement takes precedence over incomplete coverage.
Flags remain false. Findings are categorical labels, not numeric drift counts.

The corpus validator compares supplied runtime records. It does not execute Python
or PowerShell canonicalizers, authenticate runtime reports, or certify conformance.
A passing synthetic unit-test fixture is not a real canonicalization corpus result.
Each runtime report binds profile_id, profile_version, vector_id, runtime,
runtime_version, and outcome. Pass reports carry output_sha256; rejection reports
carry a shared configured rejection_code. Matching output digests establish only
reported byte equality within the declared corpus, subject to report provenance.

Profile required fields: profile_id, profile_version, mandatory_risk_classes,
required_vector_ids, required_outcomes_by_risk_class. Each vector declares vector_id,
profile_id, profile_version, risk_classes, expected_outcome (pass or reject).
The profile declares whether a risk class requires pass, reject, or both.

## Explicit specification gaps
The provided mandatory-risk list contains thirteen named classes, although the
request requires fourteen. The validator requires all thirteen and exactly one
additional caller-reviewed class. No production class is invented. The additional
class in unit tests is visibly a synthetic fixture only.

The six baseline freshness non-claims were not supplied. This module does not
invent that compatibility floor or certify specialized freshness artifacts.

Term projections are normalized, caller-extracted mappings. No Markdown YAML,
ALN, or fragment-selector parser is implied. The six projections are mapping,
policy, documentation, locale, constraints, and optional vector. Constraints and
non-claims use sets of exact strings; duplicate declarations fail in documentation.
This is a minimal declared contract, not a general semantic equivalence engine.
The policy projection's term_ids must be extracted from ALN by a separately reviewed
adapter. Presence checks do not prove policy enforcement. Locale key resolution is
supplied explicitly; no language fallback graph is inferred.

Remote digests or byte sizes are rejected without a separate reviewed reference
contract. Missing local bytes produce not_established. Binary media types are
metadata declarations; the validator does not inspect image semantics or rendering.

Envelope lifecycle metadata is a separate observation, not rewritten committed
content. Pairwise checks detect changed bytes under a reused envelope label;
they cannot prove append-only storage or historical retention. Orphan references
produce not_established and do not invalidate readable history.

Metric validation accepts canonical decimal strings with optional minus and
fractional part, no exponent, grouping separator, leading zeros, or locale syntax.
This is a local lexical profile, not an interoperability standard. Conversion,
rounding, comparison permissions, and cross-DERT comparison are not implemented.

Preservation-mode selection, freshness capture policy, escalation classification,
DERT review epochs, cross-session provenance, and full historical corpus management
remain separate integration work. No function in this module authorizes them.

## Tests
Fourteen test methods cover term parity, required/optional vectors, locale lifecycle,
missing projections, review triggers, local and remote manifests, corpus coverage,
runtime disagreement, duplicates, forbidden scoring, envelope immutability,
canonical numeric strings, and counterfactual authorization boundaries.
Tests use synthetic data only and no production personal records.

## Non-claims
No legal, medical, source authenticity, source completeness, source currency,
image semantics, cross-runtime universal parity, Unicode certification, causal
validity, person status, or automatic action determination is performed.
