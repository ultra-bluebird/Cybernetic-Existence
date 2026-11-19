# neuro-ad-guard

Alzheimer network-health Lyapunov guard for BCI/EEG and nanoswarm-safe evolution.

This crate defines:

- A scalar Alzheimer Lyapunov envelope:

  - `V_AD = a1*(1 - CSI) + a2*(1 - sigma_sw) + a3*xbar_tau`

- Guard logic enforcing:

  - Per-step `RoH <= roh_max <= 0.30`
  - `V_AD_next <= V_AD_prev` (monotone non-increase)
  - `V_AD_next <= v_ad_max` ceiling

- Kani harnesses to prove that any allowed step cannot increase `V_AD`.

The invariants are provided by the ALN shard:

- `specs/aln/neuro.ad.progression.v1.aln`

and are host-bound to:

- `hostdid        = OrganicCPU`
- `bostromaddress = bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`
- `authority      = ALN.MIGRATION.CYBERCORE_AUTHORITY.v1`

## Integration

- The BCI gateway aggregates EEG/graph/diffusion features into `AdSample`.
- `check_ad_step` is called before committing any AD-targeted intervention.
- The resulting `v_ad_next` is logged as a progression record and bound
  into an EvidenceBundle10.
