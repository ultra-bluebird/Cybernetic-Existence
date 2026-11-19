// File: mk-bluebird/nanorobotics/crates/nanoswarm-gas-core/src/kani_harness.rs
#![forbid(unsafe_code)]
#![deny(warnings)]

use std::collections::HashMap;

use kani::any;

use cybernetic_energy_objects::{
    HOSTDID,
    BOSTROMADDRESSPRIMARY,
    ALNMIGRATIONCYBERCOREAUTHORITYV1,
    TokenKind,
    TokenConfig,
    TokenLedgerEntry,
    BiophysicalEnergyLedger,
};
use crate::{
    NanoswarmGasBudget2026v1,
    NanoswarmGasBurn2026v1,
    GasCoeffs,
    PdeDoseState,
    RiskScalars,
    estimate_gas_for_mission,
    check_daily_budget,
};

#[kani::proof]
fn dev_non_negative_burns() {
    let pde = PdeDoseState {
        blood_phys_cost: any::<f32>().abs(),
        protein_phys_cost: any::<f32>().abs(),
        sugar_phys_cost: any::<f32>().abs(),
        lifeforce_phys_cost: any::<f32>().abs(),
        oxygen_phys_cost: any::<f32>().abs(),
    };

    let risk = RiskScalars {
        blood_risk: any::<f32>().abs(),
        protein_risk: any::<f32>().abs(),
        sugar_risk: any::<f32>().abs(),
        lifeforce_risk: any::<f32>().abs(),
        oxygen_risk: any::<f32>().abs(),
    };

    let mut alpha = HashMap::new();
    let mut beta = HashMap::new();
    for kind in [
        TokenKind::Blood,
        TokenKind::Protein,
        TokenKind::NeuromodEnergy,
        TokenKind::Lifeforce,
        TokenKind::Oxygen,
    ] {
        alpha.insert(kind, any::<f32>().abs());
        beta.insert(kind, any::<f32>().abs());
    }
    let coeffs = GasCoeffs { alpha, beta };

    let burns = estimate_gas_for_mission(&pde, &risk, &coeffs);

    assert!(burns.blood >= 0.0);
    assert!(burns.protein >= 0.0);
    assert!(burns.sugar >= 0.0);
    assert!(burns.lifeforce >= 0.0);
    assert!(burns.oxygen >= 0.0);
}

#[kani::proof]
fn dev_no_debt_in_check_daily_budget() {
    // Build a simple ledger with positive ceilings and balances.
    let configs = vec![
        TokenConfig {
            name: TokenKind::Blood,
            dailyceiling: 100.0,
            baselinereplenishrate: 0.0,
            jurisdictionmodifiers: vec![],
        },
        TokenConfig {
            name: TokenKind::Protein,
            dailyceiling: 100.0,
            baselinereplenishrate: 0.0,
            jurisdictionmodifiers: vec![],
        },
    ];

    let mut tokens = Vec::new();
    for cfg in configs {
        tokens.push(TokenLedgerEntry {
            config: cfg,
            usedtoday: 0.0,
        });
    }

    let ledger = BiophysicalEnergyLedger::new("subject-1", tokens);

    let mut daily_ceilings = HashMap::new();
    daily_ceilings.insert(TokenKind::Blood, 100.0);
    daily_ceilings.insert(TokenKind::Protein, 100.0);

    let mut mission_ceilings = HashMap::new();
    mission_ceilings.insert(TokenKind::Blood, 100.0);
    mission_ceilings.insert(TokenKind::Protein, 100.0);

    let mut lifetime_ceilings = HashMap::new();
    lifetime_ceilings.insert(TokenKind::Blood, 1000.0);
    lifetime_ceilings.insert(TokenKind::Protein, 1000.0);

    let budget = NanoswarmGasBudget2026v1 {
        hostdid: HOSTDID.to_string(),
        bostrom_address: BOSTROMADDRESSPRIMARY.to_string(),
        aln_clause: ALNMIGRATIONCYBERCOREAUTHORITYV1.to_string(),
        date: chrono::NaiveDate::from_ymd_opt(2026, 7, 13).unwrap(),
        daily_ceilings,
        mission_ceilings,
        lifetime_ceilings,
    };

    // Burns under ceilings.
    let mut burns_map = HashMap::new();
    burns_map.insert(TokenKind::Blood, 50.0);
    burns_map.insert(TokenKind::Protein, 50.0);
    let burn = NanoswarmGasBurn2026v1::new("mission-1", burns_map).unwrap();

    let result = check_daily_budget(&budget, &[burn], &ledger).unwrap();
    assert!(result);
}

#[kani::proof]
fn dev_corridor_compliance_ceiling() {
    // Burns equal to ceilings should still be accepted, not exceed.
    let mut daily_ceilings = HashMap::new();
    daily_ceilings.insert(TokenKind::Blood, 20.0);

    let mut mission_ceilings = HashMap::new();
    mission_ceilings.insert(TokenKind::Blood, 20.0);

    let mut lifetime_ceilings = HashMap::new();
    lifetime_ceilings.insert(TokenKind::Blood, 200.0);

    let budget = NanoswarmGasBudget2026v1 {
        hostdid: HOSTDID.to_string(),
        bostrom_address: BOSTROMADDRESSPRIMARY.to_string(),
        aln_clause: ALNMIGRATIONCYBERCOREAUTHORITYV1.to_string(),
        date: chrono::NaiveDate::from_ymd_opt(2026, 7, 13).unwrap(),
        daily_ceilings,
        mission_ceilings,
        lifetime_ceilings,
    };

    let cfg = TokenConfig {
        name: TokenKind::Blood,
        dailyceiling: 20.0,
        baselinereplenishrate: 0.0,
        jurisdictionmodifiers: vec![],
    };
    let entry = TokenLedgerEntry {
        config: cfg,
        usedtoday: 0.0,
    };
    let ledger = BiophysicalEnergyLedger::new("subject-1", vec![entry]);

    let mut burns_map = HashMap::new();
    burns_map.insert(TokenKind::Blood, 20.0);
    let burn = NanoswarmGasBurn2026v1::new("mission-1", burns_map).unwrap();

    let result = check_daily_budget(&budget, &[burn], &ledger).unwrap();
    assert!(result);
}
