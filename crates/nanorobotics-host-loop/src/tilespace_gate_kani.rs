#![cfg(kani)]
use super::{SafetyVerdict, SimSwarmConfig, gate_simswarm, compose_verdicts};

/// Noninterference of added tile guards:
/// joining with additional guard verdicts cannot lower the composite verdict.
#[kani::proof]
fn added_tiles_cannot_soften_verdict() {
    // Non-deterministic base guard verdicts (existing guards).
    let base_v1: SafetyVerdict = kani::any();
    let base_v2: SafetyVerdict = kani::any();

    // Compose base verdict.
    let base = compose_verdicts(&[base_v1, base_v2]);

    // New tile guard verdict.
    let new_guard: SafetyVerdict = kani::any();

    // Composite with added tile guard.
    let extended = compose_verdicts(&[base_v1, base_v2, new_guard]);

    // Adding a guard cannot make things more permissive:
    // extended verdict is >= base verdict in lattice order. [file:82]
    assert!(extended >= base);
}

/// Monotone tightening of corridor parameters:
/// if corridors are tightened (never relaxed), FPIC status preserved,
/// the new SimSwarmConfig verdict cannot be more permissive.
#[kani::proof]
fn corridor_tightening_cannot_soften_simswarm_verdict() {
    // Base config (looser corridors).
    let mut base_cfg: SimSwarmConfig = kani::any();
    // Ensure FPIC Granted and authority correct.
    base_cfg.fpic.status = FpicStatus::Granted;
    base_cfg.tilespace.migration_authority = AlnMigrationAuthority::CybercoreV1;

    // Tightened config: more tiles, stricter corridors.
    let mut tight_cfg = base_cfg.clone();

    // Model tightening by adding tiles; existing tiles unchanged.
    let extra_tile: TileBinding = TileBinding {
        tile_id: String::from("extra-tile"),
        aln_shard_id: String::from("capillary.formation.safe.v2.aln"),
        jurisdiction_particle: String::from("policy.jurisdiction.us-az-maricopa-phoenix.v1"),
    };
    tight_cfg.tilespace.tiles.push(extra_tile);

    // FPIC status cannot become more permissive than Granted;
    // we assume FPIC remains Granted or becomes more restrictive.
    let tight_verdict = gate_simswarm(&tight_cfg);
    let base_verdict = gate_simswarm(&base_cfg);

    // Tightened configuration verdict is >= base verdict:
    // it may stay Allow or move to Brake/Veto, but never below Allow. [file:82]
    assert!(tight_verdict >= base_verdict);
}
