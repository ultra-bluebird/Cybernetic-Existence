#![cfg(kani)]

use super::{
    merge, CorridorMerged, CorridorPolytope, CorridorPop, CorridorEnv, CorridorHost,
    ROH_GLOBAL_CEILING,
};

fn small_poly(dim: usize) -> CorridorPolytope {
    let a = vec![vec![1.0_f64; dim]];
    let b = vec![1.0_f64];
    CorridorPolytope { a, b }
}

#[kani::proof]
fn preserves_usf_roh_max() {
    let pop = CorridorPop {
        roh_max: ROH_GLOBAL_CEILING,
        poly: small_poly(2),
    };
    let env = CorridorEnv {
        roh_max: ROH_GLOBAL_CEILING,
        poly: small_poly(2),
    };
    let host = CorridorHost {
        roh_max: ROH_GLOBAL_CEILING,
        poly: small_poly(2),
    };

    let merged = merge(&pop, &env, &host);
    assert!(merged.roh_max <= pop.roh_max);
    assert!(merged.preserves_usf(&pop));
}
