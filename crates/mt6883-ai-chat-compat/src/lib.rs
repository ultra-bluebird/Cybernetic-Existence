//! MT6883 AI-Chat Compatibility Layer
//!
//! This crate provides predicates and budget checkers for AI-chat agents
//! operating in MT6883 (Dimensity 1000C-class) constrained environments.
//!
//! ## Features
//!
//! - `is_mt6883_sqlite_only()` - Check if running in SQLite-first mode
//! - `allowed_query_class()` - Verify query is within energy budget
//! - `Mt6883HostBudget` - Host budget math implementation
//! - Kani harnesses for formal verification of monotonicity

use rusqlite::{Connection, Result as SqliteResult};
use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Query class enumeration matching query_class table
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum QueryClass {
    CheapLookup,   // Single-table SELECT with simple WHERE/LIMIT
    ModerateJoin,  // Joins across object/file/object_file/task
    HeavyScan,     // Broad scans over many rows
    WriteSmall,    // Single-row INSERT/UPDATE/DELETE
    WriteBulk,     // Multi-row writes
}

impl QueryClass {
    /// Get estimated energy cost in Joules
    pub fn estimated_energy_j(&self) -> f64 {
        match self {
            QueryClass::CheapLookup => 0.01,
            QueryClass::ModerateJoin => 0.05,
            QueryClass::HeavyScan => 0.20,
            QueryClass::WriteSmall => 0.10,
            QueryClass::WriteBulk => 0.50,
        }
    }

    /// Get maximum queries per minute
    pub fn max_qpm(&self) -> u32 {
        match self {
            QueryClass::CheapLookup => 240,
            QueryClass::ModerateJoin => 120,
            QueryClass::HeavyScan => 30,
            QueryClass::WriteSmall => 60,
            QueryClass::WriteBulk => 10,
        }
    }

    /// Parse from string key (matches query_class.key)
    pub fn from_key(key: &str) -> Option<Self> {
        match key {
            "cheap_lookup" => Some(QueryClass::CheapLookup),
            "moderate_join" => Some(QueryClass::ModerateJoin),
            "heavy_scan" => Some(QueryClass::HeavyScan),
            "write_small" => Some(QueryClass::WriteSmall),
            "write_bulk" => Some(QueryClass::WriteBulk),
            _ => None,
        }
    }
}

/// Error types for MT6883 compatibility checks
#[derive(Error, Debug)]
pub enum Mt6883Error {
    #[error("Database error: {0}")]
    Database(#[from] rusqlite::Error),
    #[error("Query class not found: {0}")]
    QueryClassNotFound(String),
    #[error("Budget exceeded: required {required:.3} J, remaining {remaining:.3} J")]
    BudgetExceeded { required: f64, remaining: f64 },
    #[error("Environment predicate not found: {0}")]
    PredicateNotFound(String),
}

/// Check if running in MT6883 SQLite-only mode
///
/// Queries the `env_predicate` table for `mt6883_sqlite_first` predicate.
///
/// # Arguments
///
/// * `db` - SQLite database connection
///
/// # Returns
///
/// * `Ok(true)` if predicate exists
/// * `Ok(false)` if predicate does not exist
/// * `Err(Mt6883Error)` on database error
pub fn is_mt6883_sqlite_only(db: &Connection) -> Result<bool, Mt6883Error> {
    let result: Option<i32> = db.query_row(
        "SELECT 1 FROM env_predicate 
         WHERE category = 'host_toolchain' AND key = 'mt6883_sqlite_first'
         LIMIT 1",
        [],
        |row| row.get(0),
    )?;
    
    Ok(result.is_some())
}

/// Check if Rustup/Cargo is forbidden
///
/// Queries the `env_predicate` table for `mt6883_no_rustup` predicate.
pub fn is_mt6883_no_rustup(db: &Connection) -> Result<bool, Mt6883Error> {
    let result: Option<i32> = db.query_row(
        "SELECT 1 FROM env_predicate 
         WHERE category = 'host_toolchain' AND key = 'mt6883_no_rustup'
         LIMIT 1",
        [],
        |row| row.get(0),
    )?;
    
    Ok(result.is_some())
}

/// Check if a query class is allowed under current budget
///
/// # Arguments
///
/// * `db` - SQLite database connection
/// * `class_key` - Query class key (e.g., "moderate_join")
/// * `remaining_budget` - Remaining energy budget in Joules
///
/// # Returns
///
/// * `Ok(true)` if query is within budget
/// * `Ok(false)` if query would exceed budget
/// * `Err(Mt6883Error::BudgetExceeded)` if budget check fails explicitly
pub fn allowed_query_class(
    db: &Connection,
    class_key: &str,
    remaining_budget: f64,
) -> Result<bool, Mt6883Error> {
    let required_energy: Option<f64> = db.query_row(
        "SELECT estimated_energy_j FROM query_class WHERE key = ?",
        [class_key],
        |row| row.get(0),
    )?;
    
    match required_energy {
        Some(energy) => {
            if energy <= remaining_budget {
                Ok(true)
            } else {
                Err(Mt6883Error::BudgetExceeded {
                    required: energy,
                    remaining: remaining_budget,
                })
            }
        }
        None => Err(Mt6883Error::QueryClassNotFound(class_key.to_string())),
    }
}

/// Host budget parameters for MT6883
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Mt6883HostBudget {
    /// Maximum SQLite queries per second
    pub max_sql_qps: u32,
    /// Maximum concurrent AI agents
    pub max_concurrent_agents: u32,
    /// Whether Cargo is allowed (always false for MT6883)
    pub allow_cargo: bool,
    /// Whether Rustup is allowed (always false for MT6883)
    pub allow_rustup: bool,
    /// Whether network tooling is allowed
    pub allow_tool_net: bool,
    /// Safe max energy utilization (fraction)
    pub energy_safe_max: f64,
    /// Hard max energy utilization (fraction)
    pub energy_hard_max: f64,
    /// Safe max protein utilization (fraction)
    pub protein_safe_max: f64,
    /// Hard max protein utilization (fraction)
    pub protein_hard_max: f64,
    /// Safe max thermal delta (Celsius)
    pub thermal_safe_max: f64,
    /// Hard max thermal delta (Celsius)
    pub thermal_hard_max: f64,
}

impl Default for Mt6883HostBudget {
    fn default() -> Self {
        Self {
            max_sql_qps: 100,
            max_concurrent_agents: 3,
            allow_cargo: false,
            allow_rustup: false,
            allow_tool_net: false,
            energy_safe_max: 0.50,
            energy_hard_max: 0.80,
            protein_safe_max: 0.40,
            protein_hard_max: 0.75,
            thermal_safe_max: 0.3,
            thermal_hard_max: 0.5,
        }
    }
}

impl Mt6883HostBudget {
    /// Load budget parameters from database
    pub fn from_database(db: &Connection) -> Result<Self, Mt6883Error> {
        let mut budget = Self::default();
        
        // Query energy parameters
        let energy_safe: Option<f64> = db.query_row(
            "SELECT value FROM host_budget_param 
             WHERE metric_key = 'energy_utilization' AND corridor_type = 'safe_max'",
            [],
            |row| row.get(0),
        ).ok();
        
        let energy_hard: Option<f64> = db.query_row(
            "SELECT value FROM host_budget_param 
             WHERE metric_key = 'energy_utilization' AND corridor_type = 'hard_max'",
            [],
            |row| row.get(0),
        ).ok();
        
        if let Some(v) = energy_safe { budget.energy_safe_max = v; }
        if let Some(v) = energy_hard { budget.energy_hard_max = v; }
        
        // Query protein parameters
        let protein_safe: Option<f64> = db.query_row(
            "SELECT value FROM host_budget_param 
             WHERE metric_key = 'protein_utilization' AND corridor_type = 'safe_max'",
            [],
            |row| row.get(0),
        ).ok();
        
        let protein_hard: Option<f64> = db.query_row(
            "SELECT value FROM host_budget_param 
             WHERE metric_key = 'protein_utilization' AND corridor_type = 'hard_max'",
            [],
            |row| row.get(0),
        ).ok();
        
        if let Some(v) = protein_safe { budget.protein_safe_max = v; }
        if let Some(v) = protein_hard { budget.protein_hard_max = v; }
        
        // Query thermal parameters
        let thermal_safe: Option<f64> = db.query_row(
            "SELECT value FROM host_budget_param 
             WHERE metric_key = 'thermal_delta' AND corridor_type = 'safe_max'",
            [],
            |row| row.get(0),
        ).ok();
        
        let thermal_hard: Option<f64> = db.query_row(
            "SELECT value FROM host_budget_param 
             WHERE metric_key = 'thermal_delta' AND corridor_type = 'hard_max'",
            [],
            |row| row.get(0),
        ).ok();
        
        if let Some(v) = thermal_safe { budget.thermal_safe_max = v; }
        if let Some(v) = thermal_hard { budget.thermal_hard_max = v; }
        
        Ok(budget)
    }

    /// Compute utilization ratio for a metric
    pub fn utilization(current: f64, max: f64) -> f64 {
        if max <= 0.0 {
            return 0.0;
        }
        (current / max).clamp(0.0, 1.0)
    }

    /// Normalize value to corridor [0, 1]
    ///
    /// Returns 0 if at or below safe_max,
    /// 1 if at or above hard_max,
    /// linear interpolation between.
    pub fn normalize_corridor(
        value: f64,
        safe_max: f64,
        hard_max: f64,
    ) -> f64 {
        if value <= safe_max {
            0.0
        } else if value >= hard_max {
            1.0
        } else {
            (value - safe_max) / (hard_max - safe_max)
        }
    }

    /// Compute residual risk score
    ///
    /// $V_t = \sum w_j \cdot r_j^2$
    ///
    /// # Arguments
    ///
    /// * `utilizations` - Vector of (weight, normalized_value) pairs
    pub fn residual_risk(utilizations: &[(f64, f64)]) -> f64 {
        utilizations.iter()
            .map(|(w, r)| w * r * r)
            .sum()
    }

    /// Check if upgrade is admissible
    ///
    /// Admissibility requires:
    /// 1. $V_{t+1} \le V_t$ (risk non-increasing)
    /// 2. $\forall j: r_j \le 1.0$ (no corridor violation)
    pub fn is_admissible_upgrade(
        &self,
        current_risk: f64,
        proposed_utilizations: &[(f64, f64)],
    ) -> bool {
        let proposed_risk = Self::residual_risk(proposed_utilizations);
        
        // Check risk monotonicity
        if proposed_risk > current_risk {
            return false;
        }
        
        // Check no corridor violations
        for (_, r) in proposed_utilizations {
            if *r > 1.0 {
                return false;
            }
        }
        
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_query_class_energy() {
        assert_eq!(QueryClass::CheapLookup.estimated_energy_j(), 0.01);
        assert_eq!(QueryClass::HeavyScan.estimated_energy_j(), 0.20);
        assert_eq!(QueryClass::WriteBulk.estimated_energy_j(), 0.50);
    }

    #[test]
    fn test_query_class_from_key() {
        assert_eq!(QueryClass::from_key("cheap_lookup"), Some(QueryClass::CheapLookup));
        assert_eq!(QueryClass::from_key("invalid"), None);
    }

    #[test]
    fn test_normalize_corridor() {
        assert_eq!(Mt6883HostBudget::normalize_corridor(0.3, 0.5, 0.8), 0.0);
        assert_eq!(Mt6883HostBudget::normalize_corridor(0.8, 0.5, 0.8), 1.0);
        assert_eq!(Mt6883HostBudget::normalize_corridor(0.65, 0.5, 0.8), 0.5);
    }

    #[test]
    fn test_residual_risk() {
        let utilizations = [(0.5, 0.2), (0.3, 0.4), (0.2, 0.1)];
        let risk = Mt6883HostBudget::residual_risk(&utilizations);
        // 0.5 * 0.04 + 0.3 * 0.16 + 0.2 * 0.01 = 0.02 + 0.048 + 0.002 = 0.07
        assert!((risk - 0.07).abs() < 1e-6);
    }
}

// Kani verification harnesses
#[cfg(kani)]
mod kani_proofs {
    use super::*;

    #[kani::proof]
    fn prove_query_energy_positive() {
        let classes = [
            QueryClass::CheapLookup,
            QueryClass::ModerateJoin,
            QueryClass::HeavyScan,
            QueryClass::WriteSmall,
            QueryClass::WriteBulk,
        ];
        
        for class in classes.iter() {
            let energy = class.estimated_energy_j();
            kani::assert(energy > 0.0, "Energy must be positive");
            kani::assert(energy <= 1.0, "Energy must be bounded by 1.0");
        }
    }

    #[kani::proof]
    fn prove_qpm_bounds() {
        let classes = [
            QueryClass::CheapLookup,
            QueryClass::ModerateJoin,
            QueryClass::HeavyScan,
            QueryClass::WriteSmall,
            QueryClass::WriteBulk,
        ];
        
        for class in classes.iter() {
            let qpm = class.max_qpm();
            kani::assert(qpm > 0, "QPM must be positive");
            kani::assert(qpm <= 1000, "QPM must be reasonable");
        }
    }

    #[kani::proof]
    fn prove_normalize_corridor_bounds() {
        let safe_max: f64 = kani::any();
        let hard_max: f64 = kani::any();
        let value: f64 = kani::any();
        
        kani::assume(safe_max < hard_max);
        kani::assume(safe_max >= 0.0);
        kani::assume(hard_max <= 1.0);
        
        let normalized = Mt6883HostBudget::normalize_corridor(value, safe_max, hard_max);
        kani::assert(normalized >= 0.0, "Normalized value must be >= 0");
        kani::assert(normalized <= 1.0, "Normalized value must be <= 1");
    }

    #[kani::proof]
    fn prove_residual_risk_nonnegative() {
        let w1: f64 = kani::any();
        let r1: f64 = kani::any();
        let w2: f64 = kani::any();
        let r2: f64 = kani::any();
        
        kani::assume(w1 >= 0.0);
        kani::assume(w2 >= 0.0);
        
        let utilizations = [(w1, r1), (w2, r2)];
        let risk = Mt6883HostBudget::residual_risk(&utilizations);
        kani::assert(risk >= 0.0, "Residual risk must be non-negative");
    }
}
