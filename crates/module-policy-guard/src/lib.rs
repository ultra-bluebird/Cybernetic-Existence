// path: crates/module-policy-guard/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(clippy::all, clippy::pedantic))]

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Forbidden modules from .evo shard:
/// dreamplex, dreamcontext, subconscious_targeting, etc.
pub const FORBIDDEN_MODULES: &[&str] = &[
    "dreamplex",
    "dreamcontext",
    "subconscious_targeting",
    "anonymous_neural_scoring",
];

/// Policy error for module loading
#[derive(Debug, Error)]
pub enum ModulePolicyError {
    #[error("forbidden module detected in crate graph: {0}")]
    ForbiddenModule(String),
}

/// Lightweight representation of a crate in the graph
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CrateNode {
    pub name: String,
    pub features: Vec<String>,
}

/// Guard that inspects the crate graph at startup
pub struct ModulePolicyGuard;

impl ModulePolicyGuard {
    pub fn validate_crate_graph(nodes: &[CrateNode]) -> Result<(), ModulePolicyError> {
        for node in nodes {
            for forbidden in FORBIDDEN_MODULES {
                if node.name.contains(forbidden)
                    || node
                        .features
                        .iter()
                        .any(|f| f.contains(forbidden))
                {
                    return Err(ModulePolicyError::ForbiddenModule(
                        node.name.clone(),
                    ));
                }
            }
        }
        Ok(())
    }
}
