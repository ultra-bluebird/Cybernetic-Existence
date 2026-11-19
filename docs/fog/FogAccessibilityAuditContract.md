# FOG Accessibility Audit Contract

## Purpose

This contract governs accessibility evaluation of FOG correction paths,
review-queue status messages, offline notices, and human-review interfaces.

The audit evaluates templates and interface conditions. It does not evaluate,
classify, rank, profile, or infer information about people.

## Required essential checks

Every active FOG correction or review template MUST pass all of these checks:

- plain-language status is present
- accessible human-review path is present
- programmatic labels are present
- logical heading structure is present
- keyboard flow is complete
- status meaning is available without color, position, icon, or other visual-only cue
- essential status text is available in offline conditions
- no forced time limit prevents reading or requesting review
- no executable or operational instruction is present
- no personal data is collected
- non-default language variants have community-reviewed translation status

A template that fails any essential check MUST return:

ACCESSIBILITY_REVIEW_REQUIRED

A composite accessibility score MUST NOT override an essential-check failure.

## Permitted measurements

Permitted template-level measurements include:

- word count
- sentence count
- estimated syllable count
- readability estimate
- presence or absence of structured labels
- presence or absence of headings
- keyboard path result
- screen-reader semantic result
- reflow result
- offline text result
- translation-review status
- template version
- non-personal evidence digest

## Prohibited data collection

The accessibility audit MUST NOT collect, infer, store, or derive:

- name
- account identifier
- address
- personal location
- disability identity
- literacy level
- reading ability
- assistive-device identity
- browser fingerprint
- biometric data
- neural data
- health information
- augmentation information
- demographic data
- visitor history
- individual interaction telemetry

## Readability interpretation

A readability formula is a screening signal for template clarity.

A readability result MUST NOT be interpreted as:

- an assessment of a person's literacy
- an assessment of a person's capacity
- a language-proficiency determination
- an accessibility certification
- a substitute for keyboard, screen-reader, reflow, offline, or translation testing

## Translation requirement

A default-language template MAY be active after essential accessibility checks pass.

A non-default-language template MUST additionally have documented
community-reviewed translation status before it may be marked accessible.

Translation review status MUST NOT be inferred from locale tags alone.

## Human fallback

Every review message MUST include an accessible path to human review.

The path MUST NOT require private health, neural, biometric, device,
augmentation, institutional, identity, or location disclosure.

## Audit retention

Only minimum necessary non-personal template metadata and audit results may be
retained.

The content of a template may be stored separately under the applicable
content-retention policy. The audit table should store an integrity digest,
version, result, and review status rather than user interaction records.
