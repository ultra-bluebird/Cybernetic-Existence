# CyberRank-Forward Sovereign Research Notes

## Scope

CyberRank is modeled as a private, voluntary self-description and a set of
governance duties. It is not a public registry, identity verification system,
medical assessment, technical audit, eligibility rule, or automated decision
criterion.

## Personal continuity record

Let M(t) be a holder-defined private milestone function:

M(t) = Σ_i w_i · clamp(Φ_i(t), 0, 1)

with w_i >= 0 and Σ_i w_i = 1.

The forward-only personal record is:

R_personal(t) = max(R_personal(t-), M(t))

Therefore:

R_personal(t + Δt) >= R_personal(t)

The value is local by default and must not be used to rank people or determine
rights, service access, credibility, identity, health, augmentation, or
eligibility.

## Milestone-set representation

Let A(t) be the set of holder-asserted private milestones at time t.

M_set(t) = ⋃_(τ <= t) A(τ)

For t1 <= t2:

M_set(t1) ⊆ M_set(t2)

A holder may selectively disclose a bounded claim derived from M_set without
disclosing M_set itself.

## Authorization separation

Historical continuity records do not create permanent authorization.

An authorization is:

A = <subject, purpose, capability, issued_at, expires_at, revocation_id>

Valid(A, t) iff:

issued_at <= t < expires_at
and not Revoked(A)
and ConsentActive(A, t)

## Owner-controlled commitment chain

A private event record is:

E_i = <version, pseudonym, commitment, previous_root,
       disclosure_policy, retention_policy, local_sequence>

C_i = Hash(CanonicalEncode(E_i))

σ_i = Sign(holder_private_key, C_i)

h_i = Hash(h_(i-1) || C_i || σ_i)

Private payloads are encrypted locally. Shared proofs disclose only the
minimum claim needed for the stated purpose.

## CyberFS transaction rule

A file system transaction may prepare private writes, but only a complete,
verified commit root becomes externally visible.

Visible(file, state, capability) =
  Projection(capability, CommittedVersion(file, state))

After interruption:

Recover(interrupted_state) ∈ {previous_committed_snapshot,
                              next_complete_committed_snapshot}

Partial prepared state is never visible.

## Governance-constraint lattice

Let U be the set of recognized governance constraints.

T = P(U)

a <= b iff a ⊆ b

a ∧ b = a ∩ b

a ∨ b = a ∪ b

For any S ⊆ T:

meet(S) = ⋂ S
join(S) = ⋃ S

The order denotes inclusion of governance constraints only. It does not denote
human value, identity validity, medical status, integration depth, credibility,
or entitlement.

## Effective capability rule

Let H be holder constraints, P be mandatory protections, and C be requested
capabilities.

G_effective = H ∪ P

C_allowed = C ∩ PolicyAllows(G_effective)

Additional constraints can narrow technical authority but cannot reduce
baseline human rights, accessibility, correction, appeal, or service access.
