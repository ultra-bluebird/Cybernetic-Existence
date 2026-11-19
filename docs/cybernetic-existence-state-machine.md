# Cybernetic-Existence State Machine

## Scope

This state machine is a private-use governance vocabulary for software artifacts,
self-described logical environments, and consent-governed records. It does not
assess, verify, diagnose, certify, or determine the real-world existence,
identity, continuity, status, capacity, or legal standing of any person.

## States

| State | Meaning |
|---|---|
| `dormant` | A preserved record or environment not currently executing a defined workload |
| `active` | A record or environment operating within its explicitly authorized capability scope |
| `forked` | Two or more separately tracked descendants exist from a shared prior record |
| `merged` | Multiple tracked records have produced a documented consolidated successor |
| `migrated` | A record or environment has been transferred to a new logical host or representation |
| `preserved_as_artifact` | A non-actuating preserved representation retained for historical, research, or personal reasons |
| `terminated` | An execution context has been stopped; preservation, deletion, and retention requirements remain governed separately |

## Transition system

Let the state machine be:

\[
\mathcal{L} = (S, \Sigma, \rightarrow, s_0, I)
\]

Where:

- \(S\) is the finite set of lifecycle states
- \(\Sigma\) is the set of transition labels
- \(\rightarrow\) is the guarded transition relation
- \(s_0\) is the initial declared state
- \(I\) is the invariant set

## Mandatory guards

Every material transition requires:

1. A scoped consent record when the transition changes disclosure, capability,
   execution context, data sharing, or external effect.
2. An invariant review showing which commitments were checked.
3. A provenance commitment linking the prior and resulting records.
4. A reversibility, preservation, or remediation plan appropriate to the change.
5. Human review when an invariant exception, consent conflict, or material drift
   is reported.
6. A separate authority determination when a transition may affect third parties,
   infrastructure, external systems, or regulated environments.

## Transition rules

| From | Event | To | Minimum guards |
|---|---|---|---|
| `dormant` | `activate` | `active` | Explicit operating scope; current consent; capability review |
| `active` | `archive` | `dormant` | Preservation or deletion instruction; provenance update |
| `active` | `fork` | `forked` | Explicit fork purpose; descendant provenance; disclosure review |
| `forked` | `consolidate` | `merged` | Review of each predecessor; conflict record; consent review |
| `active` | `migrate` | `migrated` | Transformation plan; invariant checks; rollback or artifact plan |
| `migrated` | `activate` | `active` | Post-migration verification; scope confirmation |
| `active` | `preserve` | `preserved_as_artifact` | Non-actuation confirmation; retention and access rule |
| `dormant` | `preserve` | `preserved_as_artifact` | Retention and access rule |
| `active` | `stop` | `terminated` | Explicit stop record; preservation/deletion rule; audit closure |
| `preserved_as_artifact` | `restore_for_review` | `dormant` | Explicit review scope; non-actuating default |
| `terminated` | `retain_artifact` | `preserved_as_artifact` | Explicit authorization; provenance linking; retention rule |

## Invariants

The following must remain true throughout every eligible transition:

\[
\forall T,\;
\operatorname{Eligible}(T)
\Rightarrow
\operatorname{AttributionPreserved}(T)
\land
\operatorname{ConsentScopeRespected}(T)
\land
\operatorname{PrivacyNotWidenedWithoutConsent}(T)
\land
\operatorname{AccessEquivalenceMaintained}(T)
\land
\operatorname{NonInterferenceRespected}(T)
\]

A transition is not eligible if it:

- Broadens access or disclosure without explicit consent.
- Enables external actuation without a separate, specific approval.
- Removes a supported accessible communication path without an equivalent fallback.
- Makes private continuity, health, neural, biometric, operational, or companion-system information public.
- Converts a private self-description into a ranking, status, credential, eligibility signal, or automated decision criterion.
- Applies an irreversible transformation without a documented preservation,
  rollback, or remediation plan proportionate to the risk.

## Non-actuation default

The state machine is descriptive and governance-oriented. It may produce a review
record, but it must not autonomously operate, alter, control, disable, repair,
configure, or access real-world cybernetic, medical, neural, companion, or
institution-managed systems.
