// crates/neurorights-behavior-guard-macro/src/lib.rs
use proc_macro::TokenStream;

#[proc_macro_attribute]
pub fn neurorights_sensitive_export(_attr: TokenStream, item: TokenStream) -> TokenStream {
    // Pseudocode sketch:
    // 1. Parse item as a function.
    // 2. Check its body for at least one call to `behavior_policy_check(...)`.
    // 3. If missing, emit a compile_error! with a descriptive message.
    //
    // In real code, use `syn` + `quote` to walk the AST and detect the call.
    item
}
