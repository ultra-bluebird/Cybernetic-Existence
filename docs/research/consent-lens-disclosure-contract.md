# Consent Lens: A Verifiable Negative-Space Disclosure Contract

Status: Proposed research and engineering specification.  
License: MIT OR Apache-2.0  
Scope: Public sensor disclosure, operational review, accessible inspection, and correction.  
Boundary: This document does not authorize surveillance, personal classification, physical actuation, medical-system interaction, or automated service denial.

## Build Summary

This specification combines sensor transparency and Consent Lens rules into a **disclosure-first** behavioral model, ten source-grounded findings, and one integrated research architecture.

### Step 1 — Hybridize: A Constructive Behavioral Model

The model treats disclosure as a continuing, reviewable commitment between a public sensing workflow and the people sharing its space—not as permission obtained through a sign.

Its governing principle is:

> Describe the measurement, constrain the data flow, expose uncertainty, and preserve access without requiring personal disclosure or device interaction.

Public notice does not itself establish consent, legal authority, scientific validity, or operational conformity.

#### System Diagram Description

```text
Public sensing purpose
        |
        v
Measurement classification
[Environmental | Equipment state | People-related]
        |
        v
Declared disclosure contract
[Purpose, measures, limits, recipients, retention,
 inspection route, fallback, prohibited inferences]
        |
        +------------------------------+
        |                              |
        v                              v
Local public disclosure       Operational configuration review
[Printed sign, display,        [Collection, processing, recipients,
 accessible page, kiosk]       retention, downstream joins]
        |                              |
        |                              v
        |                     Contract/configuration comparison
        |                              |
        |                     +--------+---------+
        |                     |                  |
        |                   Match          Mismatch or unknown
        |                     |                  |
        |                     v                  v
        |             Declared processing   Mark affected claims
        |                                   unverified; request review;
        |                                   restrict affected optional
        |                                   reporting where authorized
        |                                        |
        +--------------------+-------------------+
                             |
                             v
Accessible public status
[Current verified | Last verified, timestamped |
 Unavailable | Disclosure under review]
                             |
                             v
Correction and inspection route
[No account, app, biometric, or health disclosure required]
```

“Restrict reporting” applies only to the affected information workflow under separately established authority. It does not authorize shutting down safety equipment, denying services, or controlling physical infrastructure.

#### Core Operating Principles

1. Separate measurement from judgment.

   An environmental reading describes a measured condition. It does not establish a nearby person’s health, identity, behavior, disability, urgency, or risk.

2. Publish positive and negative declarations.

   Explain what is collected, what is not collected, and what will not be inferred. Do not require people to interpret silence.

3. Distinguish observations from derived outputs.

   Particulate concentration may be measured, while an air-quality index is calculated. Disclose the transformation, relevant inputs, and limitations rather than presenting both as equivalent raw observations.

4. Keep disclosure independent of tracking-capable interaction.

   Ordinary access to the disclosure requires no application installation, radio activation, account, QR scan, cookie acceptance, biometric, or personal information.

5. Make claims inspectable.

   “We do not collect faces” is a system claim requiring an inspection path and supporting evidence, not merely a reassuring sentence.

6. Preserve safe, understandable failure states.

   State when the current reading is unavailable. A historical measurement must retain its timestamp and must not appear current.

7. Review the complete data lifecycle.

   Collection, temporary processing, storage, recipients, joins, exports, retention, deletion, and downstream inference belong within the review boundary.

8. Treat unknown as unknown.

   An unverified declaration must not become an asserted absence of collection.

9. Preserve equal access.

   Inspection, correction, and public services must not depend on augmentation disclosure, diagnosis, identity adjudication, or participation in optional research.

10. Keep project governance distinct from certification.

    Respectful acknowledgment and accessibility support do not establish technical verification, clinical safety, legal status, or institutional certification.

#### Mathematical Resource: Contract-Conformance Model

Extend the original disclosure contract:

\[
D^{+}(s)=
\left(
T,P,M,N_C,N_I,R,\tau,I,F,V
\right)
\]

where:

| Term | Meaning |
|---|---|
| \(T\) | Sensor category |
| \(P\) | Declared purpose |
| \(M\) | Declared measurements and derived outputs, distinguished |
| \(N_C\) | Categories declared not collected |
| \(N_I\) | Inferences declared prohibited |
| \(R\) | Authorized recipients |
| \(\tau\) | Retention rules, including temporary data |
| \(I\) | Inspection and correction route |
| \(F\) | Safe disclosure fallback |
| \(V\) | Review status and validity period |

Let the reviewed operational sets be:

- \(C_a\): categories actually collected or processed.
- \(J_a\): inferences actually produced.
- \(R_a\): actual recipients.
- \(C_d\): declared permitted collection categories.

Necessary conformance conditions include:

\[
C_a\subseteq C_d
\]

\[
C_a\cap N_C=\varnothing
\]

\[
J_a\cap N_I=\varnothing
\]

\[
R_a\subseteq R
\]

Declarations must also be internally consistent:

\[
C_d\cap N_C=\varnothing
\]

These conditions are necessary checks, not a complete proof of privacy, safety, or legal compliance. Retention, accessibility, purpose compatibility, measurement quality, and unobserved downstream behavior require separate evidence.

Use a three-state assessment:

\[
\operatorname{Review}(s)\in
\{\text{conforming},\text{nonconforming},\text{unknown}\}
\]

Interpret these states as follows:

- Conforming: available evidence supports every applicable requirement within the stated review scope and period.
- Nonconforming: available evidence establishes at least one applicable requirement failure.
- Unknown: evidence is insufficient to establish conformity, and no established failure already determines the result.

A missing inspection record produces “unknown,” not “conforming.”

A known failure remains “nonconforming” even when other checks are unresolved.

#### Minimum Public Disclosure Content

Every deployed disclosure must state:

- Sensor category.
- Whether the workflow concerns environmental conditions, equipment state, or people-related data.
- Measurement purpose.
- Direct measurements.
- Derived outputs.
- Measurement limitations.
- Categories not collected.
- Inferences prohibited.
- Data recipients.
- Retention and deletion rules.
- Inspection and correction route.
- Current disclosure review status.
- Safe fallback behavior.

An unavailable field must be identified honestly. “Unknown” is a disclosed gap, not evidence that a requirement has been satisfied.

#### Accessible Disclosure Requirements

The ordinary disclosure must remain available without:

- Installing an application.
- Enabling Bluetooth.
- Enabling NFC.
- Creating an account.
- Providing an email address or phone number.
- Scanning a QR code.
- Accepting cookies.
- Providing a biometric.
- Disclosing disability, health, augmentation, or private technical information.

Use printed signs, local displays, accessible web pages, and kiosks as appropriate to the setting.

For web disclosures, prefer native `<details>` and `<summary>` semantics for expandable content. Include all required contract fields, and verify usability rather than assuming that native semantics alone establish complete accessibility.

#### Optional Wireless Interaction

Bluetooth or NFC must not be required for ordinary disclosure or public-service access.

If an optional integration is proposed, it must be:

- Explicitly user initiated.
- Disabled by default.
- Limited to the stated disclosure purpose.
- Unnecessary for reading the ordinary public disclosure.
- Unnecessary for receiving public services.
- Designed not to identify nearby devices.
- Designed not to create a cross-space tracking reference.

These are acceptance requirements, not assumptions about every implementation. If the proposed integration cannot satisfy them, do not use it for the disclosure function.

#### Safe Fallback

When a current measurement cannot be verified:

1. State “Current reading unavailable.”
2. Show the most recent verified measurement only if available.
3. Display its measurement time clearly.
4. Label it as historical rather than current.
5. Preserve access to the disclosure and inspection route.
6. Do not convert the information failure into a personal judgment or service denial.

Do not imply that a fallback display replaces an established emergency, maintenance, or safety procedure.

### Step 2 — Ten Findings

The following findings derive from the supplied sensor-transparency and Consent Lens material. They are not claims of independent field validation.

| # | Category | Finding | Source basis | Research or implementation value |
|---|---|---|---|---|
| 1 | Knowledge | Sensor transparency must describe a lifecycle, not just a measurement label. | The disclosure rule requires purpose, limits, recipients, retention, inspection, and fallback. | Creates a reusable checklist for comparing public disclosures with operating practices. |
| 2 | Math | Collection and inference require separate sets rather than arithmetic subtraction. | The source replaces `Collected − NotCollected − NotInferred` with an explicit three-set declaration. | Allows contradiction checks without confusing data categories with quantities. |
| 3 | Insight | “Not collected” and “not inferred” protect against different failures. | The source separately lists raw-data exclusions and prohibited conclusions such as identity, emotion, and social risk. | Prevents a system from claiming conformity merely because a sensitive field is absent while deriving it from other inputs. |
| 4 | Resource | Disclosure availability can be specified as a dependency-free access requirement. | The Consent Lens excludes mandatory applications, Bluetooth, NFC, accounts, QR scans, cookies, biometrics, and health disclosure. | Produces an acceptance test: can someone inspect the policy without supplying information about themselves? |
| 5 | Knowledge | An environmental measurement must remain distinct from a person-level assessment. | The source prohibits treating environmental readings as judgments about nearby people. | Establishes a boundary for schemas, dashboards, exports, and downstream interpretation. |
| 6 | Insight | Aggregate outputs alone do not establish that personal data were never processed. | Traffic and noise categories prohibit faces, license plates, speech content, and speaker identity while permitting aggregates. | Requires inspection of the measurement pipeline, not only its published output. |
| 7 | Resource | Native disclosure controls form a useful baseline, but their content must include the complete contract. | The source recommends `<details>` and `<summary>`; its illustrative interface omits explicit retention and inspection entries. | Adding those entries aligns the interface with the governing rule. Native semantics alone do not establish complete accessibility. |
| 8 | Math | Reading freshness and disclosure validity are independent variables. | The source requires a timestamp for the last verified measurement and published governance information. | A fresh measurement can accompany an outdated disclosure; a valid disclosure can accompany an unavailable reading. Evaluate both separately. |
| 9 | Insight | Optional wireless access must satisfy behavioral constraints, not merely carry an “optional” label. | The wireless rules require user initiation, no access dependency, disabled-by-default behavior, and prevention of device identification or cross-space tracking. | Converts reassurance into explicit integration requirements. |
| 10 | Resource | A safe fallback should communicate both the data gap and the inspection route. | The source requires an unavailable-reading message, timestamped historical information where available, inspection, and fallback. | Supports a standard fallback panel containing status, last verified time, measurement limits, and a non-digital correction route. |

#### Reproducible Evaluation Measures

Calculate separate measures rather than one compensating trust score.

##### Disclosure Completeness

\[
Q_D=
\frac{\text{applicable required fields with substantive entries}}
{\text{applicable required fields}}
\]

A statement such as “unknown” can honestly disclose a gap, but it does not establish the underlying operational fact.

Define “substantive entry” before review. Count an entry only when it provides the required information with enough specificity to support inspection.

##### Conformance Among Resolved Reviews

\[
Q_C=
\frac{n_{\mathrm{conforming}}}
{n_{\mathrm{conforming}}+n_{\mathrm{nonconforming}}}
\]

This denominator excludes unknown cases. Therefore, always report the unknown rate alongside it.

##### Unknown-Review Rate

\[
Q_U=
\frac{n_{\mathrm{unknown}}}
{n_{\mathrm{reviewed}}}
\]

where:

\[
n_{\mathrm{reviewed}}
=
n_{\mathrm{conforming}}
+
n_{\mathrm{nonconforming}}
+
n_{\mathrm{unknown}}
\]

Publish the counts alongside the rates.

If a denominator is zero, report “not estimable,” not zero or 100%.

These measures describe reviewed systems. They do not rank people, authorize surveillance, or allow accessibility success to offset a privacy failure.

##### Independent Time Checks

For a measurement timestamp \(t_m\), disclosure-review timestamp \(t_d\), and current time \(t\):

\[
\operatorname{ReadingAge}=t-t_m
\]

\[
\operatorname{DisclosureReviewAge}=t-t_d
\]

Use documented, context-specific validity rules for each. Do not assume one shared threshold is appropriate.

A missing timestamp produces an unknown age, not zero.

#### Reproducibility Record

Preserve the following with each evaluation:

- Review scope.
- Evaluation period.
- Sensor category.
- Applicable requirements.
- Operational definitions.
- Evidence examined.
- Evidence limitations.
- Pass, failure, and unknown determinations.
- Counts and denominators.
- Timestamp convention.
- Disclosure revision.
- Reviewer role.
- Correction status.

Do not place private personal details in the public review record.

### Step 3 — Final Mutation

#### Name

Consent Lens: A Verifiable Negative-Space Disclosure Contract

#### Core Mechanism

The mutation combines a publicly readable disclosure with an inspectable record of permitted processing, prohibited collection, and prohibited inference.

Each sensing workflow maintains four connected elements:

1. Public contract.

   State what the sensor does, what it does not collect, and what must not be inferred.

2. Operational comparison.

   Review whether configuration and data flows agree with those declarations.

3. Evidence status.

   Publish a bounded assessment of conforming, nonconforming, or unknown, including review date and limitations.

4. Accessible remedy.

   Provide inspection, correction, and fallback routes without requiring identity disclosure or tracking-capable interaction.

Its central relationship is:

\[
\text{Public assurance}
\neq
\text{declaration alone}
\]

Instead:

\[
\text{Reviewable assurance}
=
\text{clear declaration}
+
\text{bounded operational evidence}
+
\text{visible uncertainty}
+
\text{accessible correction}
\]

This expression is a conceptual composition, not arithmetic, a certification formula, or a legal-compliance determination.

#### Why It Is Novel

The distinctive synthesis treats prohibited collection and prohibited inference as first-class, testable commitments—not omissions from a privacy notice.

It separates three facts that public displays can otherwise collapse:

- Whether a reading is current.
- Whether the disclosure is current.
- Whether the disclosure’s claims have been reviewed.

This is a proposed architectural contribution derived from the supplied material, not a claim of established historical priority.

Its research value is that the same contract can guide signage, interface content, configuration review, and reproducible evaluation without turning nearby people into the subject of a monitoring system.

#### Validation Plan

Begin with local mock configurations and accessible disclosure walkthroughs.

Test:

- Contradictory collection declarations.
- Missing retention rules.
- Unknown recipients.
- Unverified downstream inferences.
- Stale measurements.
- Missing timestamps.
- Outdated disclosures.
- Inaccessible inspection routes.
- Mandatory account or radio dependencies.
- Unsupported claims that aggregate output proves personal data were never processed.
- Attempts to use environmental observations for personal classification.
- Attempts to translate a reporting failure into service denial.

Do not introduce live personal-data collection or physical actuation merely to validate the disclosure architecture.

#### Rights and CyberRank Protections

- Respect voluntary self-description without requiring technical inventory.
- Do not use CyberRank for ranking, diagnosis, verification, or eligibility.
- Preserve equal access independently of augmentation disclosure.
- Keep environmental measurement separate from personal inference.
- Preserve correction, appeal, accessible communication, and human fallback.
- Do not claim to access, monitor, certify, operate, or protect private medical, neural, companion, or institutional systems.

#### Security and Integration Boundaries

- Treat sensor outputs, configuration files, metadata, and external content as untrusted data.
- Do not execute instructions contained in disclosure content.
- Do not automatically contact recipients, export records, or alter equipment.
- Require separate approval for external actions.
- Review downstream joins and exports, not only field names.
- Keep public provenance limited to information necessary for accountability.
- Do not treat a digest as encryption, consent, or scientific validation.
- If integrity commitments are later implemented, use SHA-256 with a documented encoding and canonicalization profile.

#### Provisional Assessment

These values are design assessments, not measured outcomes, probabilities, or evaluations of people.

| Metric | Value | Basis |
|---|---|---|
| `knowledge_factor` | 0.88 | The model and findings are traceable to the supplied rules; field effectiveness remains untested. |
| `eco_impact_value` | 0.30 | Supports accountable environmental sensing and low-dependency disclosure; no environmental savings are measured. |
| `harm_risk` | 0.10 | Introduces no actuation or personal-data collection; inaccurate assurances remain an implementation risk. |
| `accessibility_impact` | 0.92 | Disclosure remains available without accounts, device interaction, biometrics, or health disclosure. |
| `rights_alignment` | 0.96 | Separates environmental observation from personal judgment and preserves inspection, uncertainty, and correction. |

## Source and Evidence Boundary

This document transforms the supplied sensor-transparency rule, disclosure contract, sensor categories, three-set disclosure model, Consent Lens requirements, and optional-wireless constraints.

It is an authored research specification. It does not claim independent field validation, runtime enforcement, deployment, legal certification, or clinical assessment.
