pub fn update_shear_dose(
    d_k: f32,
    shear_k: f32,
    lipschitz_l: f32,
    dt: f32,
) -> f32 {
    let dt_pos = dt.max(0.0);
    let term = shear_k.abs() * dt_pos + 0.5 * lipschitz_l * dt_pos * dt_pos;
    (d_k + term).max(0.0)
}
