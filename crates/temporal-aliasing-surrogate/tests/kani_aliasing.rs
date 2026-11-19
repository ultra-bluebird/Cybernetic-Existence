#![cfg(kani)]
use kani::any;
use temporal_aliasing_surrogate::{AliasParams, next_state};

#[kani::proof]
fn temporal_aliasing_closure() {
    let mut params: AliasParams = any();

    // basic relationships
    kani::assume(params.y_safe.is_finite());
    kani::assume(params.y_hard.is_finite());
    kani::assume(params.lipschitz_l.is_finite());
    kani::assume(params.dt.is_finite());

    kani::assume(params.y_hard > params.y_safe);
    kani::assume(params.lipschitz_l >= 0.0);
    kani::assume(params.dt > 0.0);

    let m = params.y_hard - params.y_safe;
    let eps: f32 = 1.0e-4;
    kani::assume(m > params.lipschitz_l * params.dt + eps);

    let y_k: f32 = any();
    kani::assume(y_k <= params.y_safe);

    let delta: f32 = any();
    let bound = params.lipschitz_l * params.dt;
    kani::assume(delta >= -bound && delta <= bound);

    let y_next = next_state(y_k, delta);
    assert!(y_next <= params.y_hard + 1.0e-6);
}
