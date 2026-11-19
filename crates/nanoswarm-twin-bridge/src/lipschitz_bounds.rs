pub fn sup_bound(f_k: f32, lipschitz_l: f32, dt: f32) -> f32 {
    f_k.abs() + lipschitz_l * dt.abs()
}

pub fn integral_bound(f_k: f32, lipschitz_l: f32, dt: f32) -> f32 {
    let dt_pos = dt.abs();
    f_k.abs() * dt_pos + 0.5 * lipschitz_l * dt_pos * dt_pos
}
