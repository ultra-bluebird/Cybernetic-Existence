#![cfgattr(not(test), deny(warnings))]
#![forbid(unsafe_code)]

pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION_CYBERCORE_AUTHORITY_v1";

/// Nanoswarm activity vector: duty, density, task mode weights.
#[derive(Debug, Clone, Copy)]
pub struct SwarmActivity {
    pub duty: f32,
    pub density: f32,
    pub scavenging_weight: f32,
    pub repair_weight: f32,
    pub idle_weight: f32,
}

/// Host metabolic axes: ATP, thermal, immune, lifeforce.
#[derive(Debug, Clone, Copy)]
pub struct MetabolicAxes {
    pub atp_load: f32,
    pub thermal_load: f32,
    pub immune_activation: f32,
    pub lifeforce_chi: f32,
}

/// Metabolic coupling matrix Λ mapping swarm activity to metabolic axes.
#[derive(Debug, Clone, Copy)]
pub struct MetabolicCouplingMatrix {
    /// Λ is stored as a 4x5 matrix: rows (ATP, thermal, immune, lifeforce),
    /// columns (duty, density, scavenging, repair, idle).
    pub lambda: [[f32; 5]; 4],
}

/// Host metabolic ceilings.
#[derive(Debug, Clone, Copy)]
pub struct MetabolicCeilings {
    pub atp_max: f32,
    pub thermal_max: f32,
    pub immune_max: f32,
    pub lifeforce_min: f32,
}

/// Compute metabolic impact from swarm activity via Λ.
pub fn apply_coupling(matrix: &MetabolicCouplingMatrix, activity: &SwarmActivity) -> MetabolicAxes {
    let x = [
        activity.duty,
        activity.density,
        activity.scavenging_weight,
        activity.repair_weight,
        activity.idle_weight,
    ];

    let mut out = [0.0f32; 4];
    for (row_idx, row) in matrix.lambda.iter().enumerate() {
        let mut acc = 0.0f32;
        for (col_idx, &lam) in row.iter().enumerate() {
            acc += lam * x[col_idx];
        }
        out[row_idx] = acc;
    }

    MetabolicAxes {
        atp_load: out[0],
        thermal_load: out[1],
        immune_activation: out[2],
        lifeforce_chi: out[3],
    }
}

/// Guard function: check that projected metabolic axes stay within ceilings.
///
/// Returns true if the activity is admissible under the given matrix and ceilings.
pub fn metabolic_guard(
    matrix: &MetabolicCouplingMatrix,
    activity: &SwarmActivity,
    ceilings: &MetabolicCeilings,
) -> bool {
    let axes = apply_coupling(matrix, activity);

    if axes.atp_load > ceilings.atp_max {
        return false;
    }
    if axes.thermal_load > ceilings.thermal_max {
        return false;
    }
    if axes.immune_activation > ceilings.immune_max {
        return false;
    }
    if axes.lifeforce_chi < ceilings.lifeforce_min {
        return false;
    }

    true
}

/// Monotone tightening requirement: any updated matrix must
/// be more conservative or equal in each entry.
///
/// This function checks that lambda_new >= lambda_old component-wise.
/// Larger couplings mean same activity produces greater metabolic impact.
pub fn is_tightening_update(
    lambda_old: &MetabolicCouplingMatrix,
    lambda_new: &MetabolicCouplingMatrix,
) -> bool {
    for row in 0..4 {
        for col in 0..5 {
            if lambda_new.lambda[row][col] < lambda_old.lambda[row][col] {
                return false;
            }
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn apply_coupling_computes_linear_map() {
        let matrix = MetabolicCouplingMatrix {
            lambda: [
                [1.0, 0.0, 0.0, 0.0, 0.0],
                [0.0, 1.0, 0.0, 0.0, 0.0],
                [0.1, 0.1, 0.0, 0.0, 0.0],
                [0.0, 0.0, 0.2, 0.2, 0.0],
            ],
        };
        let activity = SwarmActivity {
            duty: 0.5,
            density: 0.3,
            scavenging_weight: 0.2,
            repair_weight: 0.1,
            idle_weight: 0.0,
        };

        let axes = apply_coupling(&matrix, &activity);
        assert!((axes.atp_load - 0.5).abs() < 1e-6);
        assert!((axes.thermal_load - 0.3).abs() < 1e-6);
    }

    #[test]
    fn metabolic_guard_respects_ceilings() {
        let matrix = MetabolicCouplingMatrix {
            lambda: [
                [1.0, 0.0, 0.0, 0.0, 0.0],
                [0.0, 1.0, 0.0, 0.0, 0.0],
                [0.2, 0.1, 0.0, 0.0, 0.0],
                [0.0, 0.0, 0.2, 0.2, 0.0],
            ],
        };
        let ceilings = MetabolicCeilings {
            atp_max: 0.7,
            thermal_max: 0.5,
            immune_max: 0.4,
            lifeforce_min: 0.3,
        };
        let activity_ok = SwarmActivity {
            duty: 0.5,
            density: 0.3,
            scavenging_weight: 0.2,
            repair_weight: 0.1,
            idle_weight: 0.0,
        };
        assert!(metabolic_guard(&matrix, &activity_ok, &ceilings));

        let activity_bad = SwarmActivity {
            duty: 1.0,
            density: 1.0,
            scavenging_weight: 0.5,
            repair_weight: 0.5,
            idle_weight: 0.0,
        };
        assert!(!metabolic_guard(&matrix, &activity_bad, &ceilings));
    }

    #[test]
    fn tightening_update_requires_non_decreasing_entries() {
        let old = MetabolicCouplingMatrix {
            lambda: [
                [0.1, 0.1, 0.1, 0.1, 0.1],
                [0.1, 0.1, 0.1, 0.1, 0.1],
                [0.1, 0.1, 0.1, 0.1, 0.1],
                [0.1, 0.1, 0.1, 0.1, 0.1],
            ],
        };
        let new_ok = MetabolicCouplingMatrix {
            lambda: [
                [0.2, 0.1, 0.1, 0.1, 0.1],
                [0.1, 0.2, 0.1, 0.1, 0.1],
                [0.1, 0.1, 0.2, 0.1, 0.1],
                [0.1, 0.1, 0.1, 0.2, 0.1],
            ],
        };
        let new_bad = MetabolicCouplingMatrix {
            lambda: [
                [0.05, 0.1, 0.1, 0.1, 0.1],
                [0.1, 0.1, 0.1, 0.1, 0.1],
                [0.1, 0.1, 0.1, 0.1, 0.1],
                [0.1, 0.1, 0.1, 0.1, 0.1],
            ],
        };

        assert!(is_tightening_update(&old, &new_ok));
        assert!(!is_tightening_update(&old, &new_bad));
    }
}
