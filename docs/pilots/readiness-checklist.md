# Pilot Readiness Checklist

## Purpose

This is a fail-closed readiness gate for a bounded Augmented-Hub pilot. It
consolidates technical, ecological, privacy, accessibility, governance,
lifecycle, and independent-review requirements into one inspectable record.

A checked box must link to reviewed evidence. Code presence, a feature flag,
a draft document, a test file, a schema, or a claimed future process is not
sufficient by itself.

A pilot is **not ready** when any applicable required item is absent,
unreviewed, expired, contested, inaccessible, or outside the declared scope.

## Pilot Identity

- Pilot reference:
- Jurisdiction/basin/watershed reference:
- Scope and purpose:
- Start/end dates:
- Accountable human governance process:
- Community governance charter reference, if applicable:
- Rights-holder/tribal process reference, where applicable:
- Independent review reference:
- Correction and appeal reference:
- Material-change review date:

## Technical Freeze

### Canonical records

- [ ] Canonical serialization profile is frozen and versioned.
- [ ] Canonical byte vectors are independently reproduced.
- [ ] SHA-256 content-hash scope is documented.
- [ ] Ed25519 verification, if used, is verification-only and tested against
  valid and invalid vectors.
- [ ] Canonical envelope excludes signature and hash from its signing
  preimage.
- [ ] Unsupported canonicalization backend fails closed.
- [ ] No private-key, signing, remote key discovery, or automatic
  publication capability exists in the pilot path.
- [ ] Canonical envelope retains `NonActuating::Required`.

Evidence references:

## Verification and Assurance

- [ ] Example/unit tests for applicable modules pass in the reviewed CI
  environment.
- [ ] Required property-test feature set is enabled in CI.
- [ ] Required property tests pass.
- [ ] Required conformance-test feature set is enabled in CI.
- [ ] Applicable conformance vectors pass.
- [ ] Vector format version and comparison profile are recorded.
- [ ] Test runner environment, architecture, Rust version, and lockfile
  revision are recorded.
- [ ] No unresolved failing seed, minimized counterexample, or regression
  vector is present.
- [ ] Formal-model result records are attached for applicable critical
  invariants, or the pilot is explicitly marked as lacking formal-model
  verification.
- [ ] No test result is presented as a legal, ecological, permit, or
  authority determination.

Evidence references:

## Reliance and Non-Actuation

- [ ] Every project-level output has a current, verified reliance boundary.
- [ ] Composite prohibited inferences equal the union of constituent
  prohibitions plus required baseline prohibitions.
- [ ] Composite permitted uses are the intersection of constituent permitted
  uses.
- [ ] Every output carries `NonActuating::Required`.
- [ ] No output can directly invoke a permit, utility, water, sensor,
  generator, workload, land-use, service-access, enforcement, registry,
  sharing, or retention action.
- [ ] Any separately authorized external action requires an independent human
  authorization artifact outside the evaluation pipeline.
- [ ] CyberRank is not collected, inferred, registered, ranked, verified, or
  used for eligibility, enforcement, access, compensation, review, or appeal.

Evidence references:

## Human Review and Governance

- [ ] Role-based `ReviewDecision` records are used instead of bare review
  booleans.
- [ ] Review records include scope, rationale, evidence categories, conflict
  status, expiry, correction, appeal, and accessible communication fields.
- [ ] Every relied-upon review is current, not superseded, and within scope.
- [ ] Independent review is complete where the profile requires it.
- [ ] Conflict-of-interest disclosure and mitigation review are complete.
- [ ] Governance-envelope controls are asserted and held:
  - [ ] Threat model
  - [ ] Recovery and revocation
  - [ ] Portability
  - [ ] Dispute and appeal
  - [ ] Accessibility
  - [ ] Independent audit
  - [ ] Downstream-use restriction
  - [ ] Lifecycle and deletion
- [ ] Community governance charter is assessed where local governance applies.
- [ ] Steward registry is role-based and does not require public identity,
  identity documents, CyberRank, health, disability, or private-system
  disclosure.
- [ ] Authority matrix distinguishes city/building, stormwater, utility,
  water, wildlife, environmental, rights-holder, community, and other
  applicable processes.
- [ ] No handoff package is represented as an application, permit approval,
  legal conclusion, or authority determination.

Evidence references:

## Accessible Grievance and Appeal

- [ ] Accessible web route exists.
- [ ] Non-digital route exists.
- [ ] Language access path exists.
- [ ] No email requirement.
- [ ] No smartphone requirement.
- [ ] No identity-document requirement.
- [ ] No CyberRank disclosure requirement.
- [ ] No health/disability/assistive-technology disclosure requirement.
- [ ] Anonymous or pseudonymous route exists where safe and practical.
- [ ] Independent technical support is available.
- [ ] Correction and appeal route is documented.
- [ ] Retaliation-risk review path exists.
- [ ] Service targets are documented as non-enforceable transparency targets,
  not automatic remedy claims.
- [ ] Dispute record routing is tested for accessible intake, evidence gaps,
  external-process referral, resolution, and appeal states.

Evidence references:

## Data, Consent, and Privacy

- [ ] Data layers are separated: raw observation, derived metric, public
  aggregate, methodology/retention notice.
- [ ] Raw records remain restricted by default.
- [ ] Public release uses reviewed aggregation, suppression, rounding/noise
  where appropriate, methodology notice, and retention notice.
- [ ] No public output exposes household data, individual movement, private
  system data, exact sensitive ecological locations, credentials, or security
  layouts.
- [ ] Purpose-limited permission is separate from ecological observations.
- [ ] Material sensing/sharing/retention/linkage changes use Tier 1 fresh
  consent and review where applicable.
- [ ] Tier 0 maintenance equivalence decisions are documented.
- [ ] Withdrawal stops future discretionary collection and sharing under the
  declared scope.
- [ ] Raw/derived/public deletion propagation rules are documented.
- [ ] Retention and legal-hold process is documented.
- [ ] Community/rights-holder data access restrictions are preserved.
- [ ] Federated learning, if used, keeps raw sensitive observations local and
  uses reviewed secure aggregation/update controls.

Evidence references:

## Ecological and Environmental Integrity

- [ ] Water, thermal, ecology, community, privacy, and accessibility gates are
  independently evaluated.
- [ ] Non-compensatory composition blocks a pass if any required gate fails or
  is insufficient.
- [ ] Water benefit/restoration claims are same-basin, same-period, measured,
  additional, legally protected, non-duplicative, uncertainty-adjusted, and
  survival/performance verified where required.
- [ ] Direct versus indirect water accounting remains distinct.
- [ ] Groundwater, cooling, reclaimed-water, blowdown, and stormwater claims
  use source-appropriate quality and authority review.
- [ ] Thermal results include matched measurement, uncertainty, and public
  receptor review.
- [ ] Wildlife/sensitive-species controls prioritize avoidance before land
  control and protect sensitive location data.
- [ ] Parameter values, if used, have source, unit, uncertainty, geography,
  time scope, local calibration/review, and reliance boundary.
- [ ] Missing environmental data results in `Indeterminate` or
  `InsufficientEvidence`, not a favorable claim.
- [ ] Multi-season/multi-year claims use bounded temporal horizon definitions
  and missing-data policy.

Evidence references:

## Local Evaluation and Handoff

- [ ] Browser/WASM evaluation, if offered, is local-first and does not make
  network, storage, telemetry, or actuator calls.
- [ ] CLI/pipeline evaluation, if offered, has line-size and record-count
  limits and produces non-actuating output.
- [ ] Persistence, if used, has separate access, encryption, retention,
  deletion, backup, recovery, and audit review.
- [ ] Permit evidence package, if used, has current scope, evidence, review,
  reliance, authority-boundary, correction, and appeal records.
- [ ] Public summary has plain-language, keyboard, non-web, and language
  access review.
- [ ] Public summary has privacy/sensitive-location/retaliation review.
- [ ] Audit bundle has evidence hashes/references, access/retention/reliance
  limits, independent review path, correction/appeal route, and no public
  identity registry.
- [ ] No package has been automatically submitted, published, or represented
  as approved.

Evidence references:

## Emergency, Exit, and Decommissioning

- [ ] Emergency pathway, if applicable, identifies declared scope, evidence,
  maximum duration, review cadence, accessible notice, appeal, and
  decommission default.
- [ ] Emergency is not based solely on private operational convenience.
- [ ] Emergency resumption can become only
  `EligibleForHumanResumptionDecision`, never automatic operation.
- [ ] Emergency expiry escalates to pause, independent review, or documented
  decommission default.
- [ ] Exit manifest is demonstrated with portable artifacts, dependency
  tracking, retention/deletion instructions, accessible support, correction,
  appeal, and independent support.
- [ ] Unconditional exit path can stop future discretionary collection/sharing
  without coercion proof, identity disclosure, CyberRank disclosure, or
  compulsory mediation.
- [ ] Coercion-risk signals are restricted, non-diagnostic, non-punitive, and
  cannot automatically deny exit or services.
- [ ] Decommissioning plan includes funding/successor obligation review, asset
  recovery, data stewardship, monitoring, restoration, reopening, and dispute
  path where applicable.
- [ ] No fail-closed hold is indefinite; every hold has maximum duration,
  escalation role, and non-retaliation protection.

Evidence references:

## Independent Readiness Decision

- [ ] Affected-group/community review is complete where applicable.
- [ ] Accessibility review is complete.
- [ ] Privacy/data-stewardship review is complete.
- [ ] Ecological/water/thermal/wildlife review is complete where applicable.
- [ ] Security/dependency review is complete.
- [ ] Independent audit/review is complete.
- [ ] All material disputes, appeal states, stale evidence, and unresolved
  coercion/retaliation risks are listed.
- [ ] No unresolved required gate is hidden by an aggregate score, funding
  claim, carbon claim, or benefit narrative.
- [ ] The final determination is signed by the accountable human process,
  outside this checklist.

Final status:

```text
[ ] Not ready — evidence or governance gaps remain
[ ] Ready only for bounded human pilot-approval review
[ ] Paused pending correction, appeal, authority, or independent review
[ ] Withdrawn
[ ] Superseded
```

This checklist never produces “approved for deployment” automatically.
