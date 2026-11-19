// path: crates/module-policy-guard/build.rs
fn main() {
    // Enforce that forbidden modules cannot be compiled by using cfg flags
    // wired from Cargo.toml. Any attempt to enable a forbidden feature
    // fails compilation.
    for forbidden in &["dreamplex", "dreamcontext", "subconscious_targeting", "anonymous_neural_scoring"] {
        let env_var = format!("CARGO_FEATURE_{}", forbidden.to_uppercase());
        if std::env::var_os(&env_var).is_some() {
            panic!("Forbidden module feature enabled: {}", forbidden);
        }
    }
}
