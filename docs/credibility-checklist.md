# MSFP Credibility Checklist

## Purpose

Use this checklist before merging code, publishing documentation, presenting
research, exporting an audit artifact, or describing a system capability.

## Claim discipline

- [ ] Every factual implementation claim identifies the implemented component.
- [ ] Every simulation result is labeled SIMULATED.
- [ ] Every generated corpus result is labeled SYNTHETIC.
- [ ] Every local policy result is labeled LOCAL POLICY.
- [ ] Every locally reproducible check is labeled VERIFIED LOCALLY.
- [ ] Every manually entered laboratory measurement is labeled MANUAL LAB ENTRY.
- [ ] Every unverified hardware, accessibility, security, safety, or legal claim is labeled REQUIRES REVIEW.
- [ ] No unavailable capability is described as implemented.
- [ ] No claim uses “100% secure,” “unbreakable,” “absolute immunity,” or equivalent wording.
- [ ] No claim states universal physical data erasure without hardware-specific evidence.
- [ ] No claim implies identity, health, augmentation, credibility, or eligibility inference.

## MSFP terminology

- [ ] Every private MSFP label has a standard engineering translation.
- [ ] Firebreak is described as a time-bounded, least-authority session boundary.
- [ ] V-NIR is described as ephemeral session state, not guaranteed physical erasure.
- [ ] X-VAL is described as a strict parser and policy-enforcement boundary.
- [ ] TTL-HWC is described as a monotonic lease/watchdog abstraction.
- [ ] Passive Stasis is described as a read-only simulated state.
- [ ] Cold state is described as no active external authority.
- [ ] Organichain is described as a signed append-only provenance or audit chain.
- [ ] Enclosure safety is described as EMC, power-integrity, and thermal evaluation.

## Capability and consent

- [ ] Every external session is explicit, purpose-bound, and time-bounded.
- [ ] Capability authority is attenuated through request, policy, consent, and purpose intersection.
- [ ] A capability cannot widen in place.
- [ ] A lease cannot extend in place.
- [ ] Revocation removes external authority.
- [ ] Expiry removes key and capability usability.
- [ ] A new session requires fresh admission and a new generation.
- [ ] Agent text cannot mutate consent state.
- [ ] Agent tools expose only explicit allow-listed operations.
- [ ] No ambient authority exists in agent or gateway interfaces.

## Privacy and CyberRank

- [ ] CyberRank is represented as a private governance/preference layer.
- [ ] No CyberRank tier score is computed or exported.
- [ ] No consent history is converted into a score, reputation, or eligibility signal.
- [ ] No personal preference is required to obtain local access.
- [ ] No identity, health, augmentation, or institutional status is inferred.
- [ ] External components receive only derived capabilities, not full private profiles.
- [ ] Export requires visible scope and explicit confirmation.
- [ ] Audit records omit raw payloads, session keys, raw capability tokens, and private identity data by default.

## Testing and formal methods

- [ ] Unit tests cover capability attenuation and session transitions.
- [ ] Property tests cover arbitrary scope-expansion attempts.
- [ ] Replay tests cover repeated sequence and nonce cases.
- [ ] Parser tests cover oversize, unknown, duplicate, noncanonical, and downgrade inputs.
- [ ] Audit tests verify sequence and parent-head linkage.
- [ ] TLA+ safety properties are checked.
- [ ] TLA+ liveness properties include documented fairness assumptions.
- [ ] Counterexamples are preserved as research artifacts.
- [ ] Browser refresh and restart behavior is tested.
- [ ] No test presents synthetic values as measured observations.

## Accessibility and continuity

- [ ] All critical functions are keyboard operable.
- [ ] No keyboard trap exists.
- [ ] Focus remains visible.
- [ ] Revoke is available through more than one interaction route.
- [ ] Status is available as text and semantic assistive-technology output.
- [ ] Color, sound, vibration, animation, and timing are never the sole alert channel.
- [ ] Reduced-motion behavior is tested.
- [ ] Session termination preserves local controls.
- [ ] Session termination preserves local recovery guidance.
- [ ] Configured human fallback remains visible after lockout.
- [ ] Inactivity never constitutes consent.

## Storage and provenance

- [ ] Session secrets remain in ephemeral runtime memory.
- [ ] Session state is not serialized to persistent storage.
- [ ] Crash reports and verbose logs do not contain test canaries.
- [ ] Receipts contain minimal commitments and reason codes only.
- [ ] Provenance records include parent head, artifact hash, policy version, and retention class.
- [ ] Retention behavior is explicit.
- [ ] Deletion actions produce minimal deletion receipts where required.
- [ ] Any export is deliberate, visible, and reviewable.

## CMDeck and enclosure work

- [ ] Hardware telemetry is labeled with its source.
- [ ] Simulated values are not presented as measured values.
- [ ] Thermal and EMC limits come from test plans, component documentation, or reviewed engineering requirements.
- [ ] The interface remains locally usable when networking is unavailable.
- [ ] Power loss does not resurrect prior external session authority.
- [ ] Any hardware integration receives independent safety, security, accessibility, and privacy review.
