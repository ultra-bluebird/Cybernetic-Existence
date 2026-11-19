use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;

/// Represents the asset class for a continuity-sensitive public corridor.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum AssetKind {
    CorridorSensor,
    ChargingStation,
    CoolingStation,
}

/// Defines an asset requiring one preventive-maintenance intervention
/// during the requested planning horizon.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MaintenanceAsset {
    pub asset_id: String,
    pub asset_kind: AssetKind,
    pub corridor_id: String,
    pub required_crew_role: String,
    pub required_part_id: String,
    pub maintenance_duration_slots: u16,
    pub due_by_slot: u16,
    pub maximum_consecutive_downtime_slots: u16,
    pub continuity_disruption_weight: u64,
    pub essential_service_asset: bool,
}

/// Defines available workers for a named technical role at each discrete
/// time slot in the scheduling horizon.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CrewAvailability {
    pub crew_role: String,
    pub available_crew_count_by_slot: BTreeMap<u16, u16>,
}

/// Defines the available inventory for a replacement or maintenance part.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PartInventory {
    pub part_id: String,
    pub available_quantity: u32,
}

/// Defines the deterministic input domain for a preventive-maintenance plan.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MaintenancePlanningInput {
    pub horizon_slots: u16,
    pub assets: Vec<MaintenanceAsset>,
    pub crews: Vec<CrewAvailability>,
    pub parts: Vec<PartInventory>,
}

/// Represents the accepted start and end time for one asset intervention.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScheduledMaintenance {
    pub asset_id: String,
    pub start_slot: u16,
    pub end_slot_exclusive: u16,
}

/// Provides the continuity-aware result of a maintenance planning run.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MaintenancePlan {
    pub scheduled_maintenance: Vec<ScheduledMaintenance>,
    pub total_weighted_continuity_disruption: u64,
    pub unscheduled_asset_ids: Vec<String>,
    pub essential_service_continuity_preserved: bool,
    pub explanation: String,
}

/// Defines the abstract boundary between the deterministic PopMath model
/// and an approved external integer-programming solver.
pub trait ExternalSolverAdapter {
    fn solve(
        &self,
        model: &IntegerProgrammingModel,
    ) -> Result<ExternalSolverSolution, MaintenanceOptimizationError>;
}

/// Represents a solver-neutral mixed-integer linear-programming model.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IntegerProgrammingModel {
    pub horizon_slots: u16,
    pub binary_start_variables: Vec<BinaryStartVariable>,
    pub constraints: Vec<LinearConstraint>,
    pub objective: LinearObjective,
}

/// Represents a binary decision variable where one means that maintenance
/// starts for the named asset in the named time slot.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BinaryStartVariable {
    pub variable_name: String,
    pub asset_id: String,
    pub start_slot: u16,
    pub objective_cost: u64,
}

/// Represents a linear optimization constraint.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinearConstraint {
    pub name: String,
    pub relation: ConstraintRelation,
    pub right_hand_side: i64,
    pub coefficients: BTreeMap<String, i64>,
}

/// Defines a linear-constraint relationship.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConstraintRelation {
    Equal,
    LessOrEqual,
    GreaterOrEqual,
}

/// Represents a solver-neutral linear objective.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinearObjective {
    pub minimize: bool,
    pub coefficients: BTreeMap<String, i64>,
}

/// Represents the selected binary variable names returned by a solver.
/// The PopMath validation boundary independently checks all selections.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExternalSolverSolution {
    pub selected_variable_names: BTreeSet<String>,
}

/// Builds a deterministic integer-programming model for preventive maintenance.
///
/// Decision variable:
///
/// x[a,t] = 1 if maintenance for asset a begins at slot t, otherwise 0.
///
/// Objective:
///
/// minimize Σ(a,t) continuity_disruption_weight[a] × duration[a] × x[a,t]
///
/// Subject to:
///
/// - Each asset receives exactly one maintenance start.
/// - Each intervention completes no later than its due slot.
/// - Crew capacity is never exceeded.
/// - Required part inventory is never exceeded.
/// - Maintenance duration is no greater than the asset's allowed
///   maximum consecutive downtime.
/// - Essential assets remain subject to the same continuity constraints,
///   rather than being silently excluded from maintenance planning.
pub fn build_preventive_maintenance_model(
    input: &MaintenancePlanningInput,
) -> Result<IntegerProgrammingModel, MaintenanceOptimizationError> {
    validate_planning_input(input)?;

    let mut binary_start_variables = Vec::new();
    let mut constraints = Vec::new();
    let mut objective_coefficients = BTreeMap::new();

    for asset in &input.assets {
        let eligible_start_slots = eligible_start_slots(asset, input.horizon_slots)?;
        let mut exact_schedule_coefficients = BTreeMap::new();

        for start_slot in eligible_start_slots {
            let variable_name = start_variable_name(&asset.asset_id, start_slot);
            let objective_cost = weighted_disruption_cost(asset)?;

            exact_schedule_coefficients.insert(variable_name.clone(), 1);
            objective_coefficients.insert(variable_name.clone(), objective_cost as i64);

            binary_start_variables.push(BinaryStartVariable {
                variable_name,
                asset_id: asset.asset_id.clone(),
                start_slot,
                objective_cost,
            });
        }

        constraints.push(LinearConstraint {
            name: format!("schedule_exactly_once_{}", asset.asset_id),
            relation: ConstraintRelation::Equal,
            right_hand_side: 1,
            coefficients: exact_schedule_coefficients,
        });
    }

    add_crew_capacity_constraints(input, &binary_start_variables, &mut constraints)?;
    add_part_inventory_constraints(input, &binary_start_variables, &mut constraints)?;

    Ok(IntegerProgrammingModel {
        horizon_slots: input.horizon_slots,
        binary_start_variables,
        constraints,
        objective: LinearObjective {
            minimize: true,
            coefficients: objective_coefficients,
        },
    })
}

/// Requests a plan from an approved external solver and validates the solver
/// response locally before it can be used by corridor operations.
pub fn solve_with_external_adapter(
    input: &MaintenancePlanningInput,
    solver: &dyn ExternalSolverAdapter,
) -> Result<MaintenancePlan, MaintenanceOptimizationError> {
    let model = build_preventive_maintenance_model(input)?;
    let solver_solution = solver.solve(&model)?;

    materialize_and_validate_solution(input, &model, &solver_solution)
}

/// Creates a deterministic, feasible fallback plan without an external solver.
///
/// Ordering is stable and reproducible:
///
/// 1. Earlier due slot.
/// 2. Greater continuity-disruption weight.
/// 3. Asset class.
/// 4. Corridor identifier.
/// 5. Asset identifier.
///
/// The fallback is intended for testing, simulation, constrained deployments,
/// and degraded operations. It does not claim global optimality.
pub fn solve_with_deterministic_fallback(
    input: &MaintenancePlanningInput,
) -> Result<MaintenancePlan, MaintenanceOptimizationError> {
    validate_planning_input(input)?;

    let mut ordered_assets = input.assets.clone();
    ordered_assets.sort_by(compare_assets_for_deterministic_assignment);

    let mut crew_usage = BTreeMap::<(String, u16), u16>::new();
    let mut part_usage = BTreeMap::<String, u32>::new();
    let mut scheduled_maintenance = Vec::new();
    let mut unscheduled_asset_ids = Vec::new();

    for asset in ordered_assets {
        let start_slot = eligible_start_slots(&asset, input.horizon_slots)?
            .into_iter()
            .find(|candidate_slot| {
                can_assign(
                    input,
                    &asset,
                    *candidate_slot,
                    &crew_usage,
                    &part_usage,
                )
                .unwrap_or(false)
            });

        match start_slot {
            Some(start_slot) => {
                reserve_assignment(
                    &asset,
                    start_slot,
                    &mut crew_usage,
                    &mut part_usage,
                )?;

                scheduled_maintenance.push(ScheduledMaintenance {
                    asset_id: asset.asset_id,
                    start_slot,
                    end_slot_exclusive: start_slot
                        .checked_add(asset.maintenance_duration_slots)
                        .ok_or(MaintenanceOptimizationError::ArithmeticOverflow)?,
                });
            }
            None => unscheduled_asset_ids.push(asset.asset_id),
        }
    }

    scheduled_maintenance.sort_by(compare_scheduled_maintenance);
    unscheduled_asset_ids.sort();

    let total_weighted_continuity_disruption =
        calculate_plan_disruption(input, &scheduled_maintenance)?;

    let essential_service_continuity_preserved =
        essential_service_continuity_is_preserved(input, &scheduled_maintenance);

    Ok(MaintenancePlan {
        scheduled_maintenance,
        total_weighted_continuity_disruption,
        unscheduled_asset_ids,
        essential_service_continuity_preserved,
        explanation: "The deterministic fallback assigns the earliest feasible window after stable ordering by deadline, continuity impact, asset type, corridor, and asset identifier. It validates crew capacity, part inventory, due windows, and maximum allowed continuous downtime.".to_owned(),
    })
}

/// Converts selected external-solver variables into a plan and applies the full
/// local validation boundary.
pub fn materialize_and_validate_solution(
    input: &MaintenancePlanningInput,
    model: &IntegerProgrammingModel,
    solution: &ExternalSolverSolution,
) -> Result<MaintenancePlan, MaintenanceOptimizationError> {
    let variable_index = model
        .binary_start_variables
        .iter()
        .map(|variable| (variable.variable_name.as_str(), variable))
        .collect::<BTreeMap<_, _>>();

    let mut selected_by_asset = BTreeMap::<String, &BinaryStartVariable>::new();

    for variable_name in &solution.selected_variable_names {
        let variable = variable_index.get(variable_name.as_str()).ok_or_else(|| {
            MaintenanceOptimizationError::UnknownSolverVariable {
                variable_name: variable_name.clone(),
            }
        })?;

        if selected_by_asset
            .insert(variable.asset_id.clone(), *variable)
            .is_some()
        {
            return Err(MaintenanceOptimizationError::MultipleSelectionsForAsset {
                asset_id: variable.asset_id.clone(),
            });
        }
    }

    let expected_asset_ids = input
        .assets
        .iter()
        .map(|asset| asset.asset_id.clone())
        .collect::<BTreeSet<_>>();

    let selected_asset_ids = selected_by_asset
        .keys()
        .cloned()
        .collect::<BTreeSet<_>>();

    if expected_asset_ids != selected_asset_ids {
        return Err(MaintenanceOptimizationError::IncompleteSolverSchedule);
    }

    let mut scheduled_maintenance = Vec::new();

    for variable in selected_by_asset.values() {
        let asset = find_asset(input, &variable.asset_id)?;

        scheduled_maintenance.push(ScheduledMaintenance {
            asset_id: variable.asset_id.clone(),
            start_slot: variable.start_slot,
            end_slot_exclusive: variable
                .start_slot
                .checked_add(asset.maintenance_duration_slots)
                .ok_or(MaintenanceOptimizationError::ArithmeticOverflow)?,
        });
    }

    validate_plan_constraints(input, &scheduled_maintenance)?;
    scheduled_maintenance.sort_by(compare_scheduled_maintenance);

    Ok(MaintenancePlan {
        total_weighted_continuity_disruption:
            calculate_plan_disruption(input, &scheduled_maintenance)?,
        essential_service_continuity_preserved:
            essential_service_continuity_is_preserved(input, &scheduled_maintenance),
        scheduled_maintenance,
        unscheduled_asset_ids: Vec::new(),
        explanation: "The external solver schedule passed independent validation for asset coverage, timing, maximum continuous downtime, crew capacity, inventory capacity, and essential-service continuity constraints.".to_owned(),
    })
}

fn validate_planning_input(
    input: &MaintenancePlanningInput,
) -> Result<(), MaintenanceOptimizationError> {
    if input.horizon_slots == 0 {
        return Err(MaintenanceOptimizationError::InvalidHorizon);
    }

    let mut asset_ids = BTreeSet::new();

    for asset in &input.assets {
        validate_required_field("asset_id", &asset.asset_id)?;
        validate_required_field("corridor_id", &asset.corridor_id)?;
        validate_required_field("required_crew_role", &asset.required_crew_role)?;
        validate_required_field("required_part_id", &asset.required_part_id)?;

        if !asset_ids.insert(asset.asset_id.clone()) {
            return Err(MaintenanceOptimizationError::DuplicateAssetId {
                asset_id: asset.asset_id.clone(),
            });
        }

        if asset.maintenance_duration_slots == 0 {
            return Err(MaintenanceOptimizationError::InvalidMaintenanceDuration {
                asset_id: asset.asset_id.clone(),
            });
        }

        if asset.maximum_consecutive_downtime_slots == 0 {
            return Err(MaintenanceOptimizationError::InvalidMaximumDowntime {
                asset_id: asset.asset_id.clone(),
            });
        }

        if asset.maintenance_duration_slots > asset.maximum_consecutive_downtime_slots {
            return Err(MaintenanceOptimizationError::DowntimeConstraintViolation {
                asset_id: asset.asset_id.clone(),
            });
        }

        if asset.due_by_slot == 0 {
            return Err(MaintenanceOptimizationError::InvalidDueSlot {
                asset_id: asset.asset_id.clone(),
            });
        }
    }

    validate_unique_crew_roles(&input.crews)?;
    validate_unique_part_ids(&input.parts)?;

    for asset in &input.assets {
        if !input
            .crews
            .iter()
            .any(|crew| crew.crew_role == asset.required_crew_role)
        {
            return Err(MaintenanceOptimizationError::MissingCrewRole {
                crew_role: asset.required_crew_role.clone(),
            });
        }

        if !input
            .parts
            .iter()
            .any(|part| part.part_id == asset.required_part_id)
        {
            return Err(MaintenanceOptimizationError::MissingPart {
                part_id: asset.required_part_id.clone(),
            });
        }
    }

    Ok(())
}

fn validate_required_field(
    field: &'static str,
    value: &str,
) -> Result<(), MaintenanceOptimizationError> {
    if value.trim().is_empty() {
        return Err(MaintenanceOptimizationError::MissingField { field });
    }

    Ok(())
}

fn validate_unique_crew_roles(
    crews: &[CrewAvailability],
) -> Result<(), MaintenanceOptimizationError> {
    let mut crew_roles = BTreeSet::new();

    for crew in crews {
        validate_required_field("crew_role", &crew.crew_role)?;

        if !crew_roles.insert(crew.crew_role.clone()) {
            return Err(MaintenanceOptimizationError::DuplicateCrewRole {
                crew_role: crew.crew_role.clone(),
            });
        }
    }

    Ok(())
}

fn validate_unique_part_ids(
    parts: &[PartInventory],
) -> Result<(), MaintenanceOptimizationError> {
    let mut part_ids = BTreeSet::new();

    for part in parts {
        validate_required_field("part_id", &part.part_id)?;

        if !part_ids.insert(part.part_id.clone()) {
            return Err(MaintenanceOptimizationError::DuplicatePartId {
                part_id: part.part_id.clone(),
            });
        }
    }

    Ok(())
}

fn eligible_start_slots(
    asset: &MaintenanceAsset,
    horizon_slots: u16,
) -> Result<Vec<u16>, MaintenanceOptimizationError> {
    let latest_completion_slot = asset.due_by_slot.min(horizon_slots);

    if asset.maintenance_duration_slots > latest_completion_slot {
        return Err(MaintenanceOptimizationError::NoEligibleMaintenanceWindow {
            asset_id: asset.asset_id.clone(),
        });
    }

    let latest_start_slot = latest_completion_slot
        .checked_sub(asset.maintenance_duration_slots)
        .ok_or_else(|| MaintenanceOptimizationError::NoEligibleMaintenanceWindow {
            asset_id: asset.asset_id.clone(),
        })?;

    Ok((0..=latest_start_slot).collect())
}

fn add_crew_capacity_constraints(
    input: &MaintenancePlanningInput,
    variables: &[BinaryStartVariable],
    constraints: &mut Vec<LinearConstraint>,
) -> Result<(), MaintenanceOptimizationError> {
    for crew in &input.crews {
        for slot in 0..input.horizon_slots {
            let mut coefficients = BTreeMap::new();

            for variable in variables {
                let asset = find_asset(input, &variable.asset_id)?;

                if asset.required_crew_role == crew.crew_role
                    && slot >= variable.start_slot
                    && slot
                        < variable
                            .start_slot
                            .saturating_add(asset.maintenance_duration_slots)
                {
                    coefficients.insert(variable.variable_name.clone(), 1);
                }
            }

            let available_crew_count = crew
                .available_crew_count_by_slot
                .get(&slot)
                .copied()
                .unwrap_or(0);

            constraints.push(LinearConstraint {
                name: format!("crew_capacity_{}_{}", crew.crew_role, slot),
                relation: ConstraintRelation::LessOrEqual,
                right_hand_side: available_crew_count as i64,
                coefficients,
            });
        }
    }

    Ok(())
}

fn add_part_inventory_constraints(
    input: &MaintenancePlanningInput,
    variables: &[BinaryStartVariable],
    constraints: &mut Vec<LinearConstraint>,
) -> Result<(), MaintenanceOptimizationError> {
    for part in &input.parts {
        let mut coefficients = BTreeMap::new();

        for variable in variables {
            let asset = find_asset(input, &variable.asset_id)?;

            if asset.required_part_id == part.part_id {
                coefficients.insert(variable.variable_name.clone(), 1);
            }
        }

        constraints.push(LinearConstraint {
            name: format!("part_inventory_{}", part.part_id),
            relation: ConstraintRelation::LessOrEqual,
            right_hand_side: part.available_quantity as i64,
            coefficients,
        });
    }

    Ok(())
}

fn can_assign(
    input: &MaintenancePlanningInput,
    asset: &MaintenanceAsset,
    start_slot: u16,
    crew_usage: &BTreeMap<(String, u16), u16>,
    part_usage: &BTreeMap<String, u32>,
) -> Result<bool, MaintenanceOptimizationError> {
    let part_inventory = input
        .parts
        .iter()
        .find(|part| part.part_id == asset.required_part_id)
        .ok_or_else(|| MaintenanceOptimizationError::MissingPart {
            part_id: asset.required_part_id.clone(),
        })?;

    let used_parts = part_usage
        .get(&asset.required_part_id)
        .copied()
        .unwrap_or(0);

    if used_parts >= part_inventory.available_quantity {
        return Ok(false);
    }

    let crew = input
        .crews
        .iter()
        .find(|crew| crew.crew_role == asset.required_crew_role)
        .ok_or_else(|| MaintenanceOptimizationError::MissingCrewRole {
            crew_role: asset.required_crew_role.clone(),
        })?;

    let end_slot = start_slot
        .checked_add(asset.maintenance_duration_slots)
        .ok_or(MaintenanceOptimizationError::ArithmeticOverflow)?;

    for slot in start_slot..end_slot {
        let available_count = crew
            .available_crew_count_by_slot
            .get(&slot)
            .copied()
            .unwrap_or(0);

        let current_usage = crew_usage
            .get(&(asset.required_crew_role.clone(), slot))
            .copied()
            .unwrap_or(0);

        if current_usage >= available_count {
            return Ok(false);
        }
    }

    Ok(true)
}

fn reserve_assignment(
    asset: &MaintenanceAsset,
    start_slot: u16,
    crew_usage: &mut BTreeMap<(String, u16), u16>,
    part_usage: &mut BTreeMap<String, u32>,
) -> Result<(), MaintenanceOptimizationError> {
    let end_slot = start_slot
        .checked_add(asset.maintenance_duration_slots)
        .ok_or(MaintenanceOptimizationError::ArithmeticOverflow)?;

    for slot in start_slot..end_slot {
        let key = (asset.required_crew_role.clone(), slot);
        let usage = crew_usage.entry(key).or_insert(0);

        *usage = usage
            .checked_add(1)
            .ok_or(MaintenanceOptimizationError::ArithmeticOverflow)?;
    }

    let inventory_usage = part_usage
        .entry(asset.required_part_id.clone())
        .or_insert(0);

    *inventory_usage = inventory_usage
        .checked_add(1)
        .ok_or(MaintenanceOptimizationError::ArithmeticOverflow)?;

    Ok(())
}

fn validate_plan_constraints(
    input: &MaintenancePlanningInput,
    scheduled_maintenance: &[ScheduledMaintenance],
) -> Result<(), MaintenanceOptimizationError> {
    if scheduled_maintenance.len() != input.assets.len() {
        return Err(MaintenanceOptimizationError::IncompleteSolverSchedule);
    }

    let mut scheduled_asset_ids = BTreeSet::new();
    let mut crew_usage = BTreeMap::<(String, u16), u16>::new();
    let mut part_usage = BTreeMap::<String, u32>::new();

    for scheduled in scheduled_maintenance {
        let asset = find_asset(input, &scheduled.asset_id)?;

        if !scheduled_asset_ids.insert(asset.asset_id.clone()) {
            return Err(MaintenanceOptimizationError::MultipleSelectionsForAsset {
                asset_id: asset.asset_id.clone(),
            });
        }

        let expected_end_slot = scheduled
            .start_slot
            .checked_add(asset.maintenance_duration_slots)
            .ok_or(MaintenanceOptimizationError::ArithmeticOverflow)?;

        if scheduled.end_slot_exclusive != expected_end_slot
            || scheduled.end_slot_exclusive > input.horizon_slots
            || scheduled.end_slot_exclusive > asset.due_by_slot
        {
            return Err(MaintenanceOptimizationError::InvalidScheduledWindow {
                asset_id: asset.asset_id.clone(),
            });
        }

        if asset.maintenance_duration_slots > asset.maximum_consecutive_downtime_slots {
            return Err(MaintenanceOptimizationError::DowntimeConstraintViolation {
                asset_id: asset.asset_id.clone(),
            });
        }

        reserve_assignment(
            asset,
            scheduled.start_slot,
            &mut crew_usage,
            &mut part_usage,
        )?;
    }

    for crew in &input.crews {
        for slot in 0..input.horizon_slots {
            let assigned_count = crew_usage
                .get(&(crew.crew_role.clone(), slot))
                .copied()
                .unwrap_or(0);

            let available_count = crew
                .available_crew_count_by_slot
                .get(&slot)
                .copied()
                .unwrap_or(0);

            if assigned_count > available_count {
                return Err(MaintenanceOptimizationError::CrewCapacityViolation {
                    crew_role: crew.crew_role.clone(),
                    slot,
                });
            }
        }
    }

    for part in &input.parts {
        let assigned_quantity = part_usage.get(&part.part_id).copied().unwrap_or(0);

        if assigned_quantity > part.available_quantity {
            return Err(MaintenanceOptimizationError::PartInventoryViolation {
                part_id: part.part_id.clone(),
            });
        }
    }

    Ok(())
}

fn essential_service_continuity_is_preserved(
    input: &MaintenancePlanningInput,
    scheduled_maintenance: &[ScheduledMaintenance],
) -> bool {
    input.assets.iter().all(|asset| {
        if !asset.essential_service_asset {
            return true;
        }

        scheduled_maintenance.iter().any(|scheduled| {
            scheduled.asset_id == asset.asset_id
                && scheduled.end_slot_exclusive >= scheduled.start_slot
                && asset.maintenance_duration_slots <= asset.maximum_consecutive_downtime_slots
        })
    })
}

fn calculate_plan_disruption(
    input: &MaintenancePlanningInput,
    scheduled_maintenance: &[ScheduledMaintenance],
) -> Result<u64, MaintenanceOptimizationError> {
    scheduled_maintenance.iter().try_fold(0_u64, |total, scheduled| {
        let asset = find_asset(input, &scheduled.asset_id)?;

        total
            .checked_add(weighted_disruption_cost(asset)?)
            .ok_or(MaintenanceOptimizationError::ArithmeticOverflow)
    })
}

fn weighted_disruption_cost(
    asset: &MaintenanceAsset,
) -> Result<u64, MaintenanceOptimizationError> {
    asset
        .continuity_disruption_weight
        .checked_mul(asset.maintenance_duration_slots as u64)
        .ok_or(MaintenanceOptimizationError::ArithmeticOverflow)
}

fn find_asset<'a>(
    input: &'a MaintenancePlanningInput,
    asset_id: &str,
) -> Result<&'a MaintenanceAsset, MaintenanceOptimizationError> {
    input
        .assets
        .iter()
        .find(|asset| asset.asset_id == asset_id)
        .ok_or_else(|| MaintenanceOptimizationError::UnknownAsset {
            asset_id: asset_id.to_owned(),
        })
}

fn compare_assets_for_deterministic_assignment(
    left: &MaintenanceAsset,
    right: &MaintenanceAsset,
) -> Ordering {
    left.due_by_slot
        .cmp(&right.due_by_slot)
        .then_with(|| {
            right
                .continuity_disruption_weight
                .cmp(&left.continuity_disruption_weight)
        })
        .then_with(|| left.asset_kind.cmp(&right.asset_kind))
        .then_with(|| left.corridor_id.cmp(&right.corridor_id))
        .then_with(|| left.asset_id.cmp(&right.asset_id))
}

fn compare_scheduled_maintenance(
    left: &ScheduledMaintenance,
    right: &ScheduledMaintenance,
) -> Ordering {
    left.start_slot
        .cmp(&right.start_slot)
        .then_with(|| left.asset_id.cmp(&right.asset_id))
}

fn start_variable_name(asset_id: &str, start_slot: u16) -> String {
    format!("maintain_{}_at_{}", asset_id, start_slot)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MaintenanceOptimizationError {
    ArithmeticOverflow,
    CrewCapacityViolation {
        crew_role: String,
        slot: u16,
    },
    DowntimeConstraintViolation {
        asset_id: String,
    },
    DuplicateAssetId {
        asset_id: String,
    },
    DuplicateCrewRole {
        crew_role: String,
    },
    DuplicatePartId {
        part_id: String,
    },
    IncompleteSolverSchedule,
    InvalidDueSlot {
        asset_id: String,
    },
    InvalidHorizon,
    InvalidMaintenanceDuration {
        asset_id: String,
    },
    InvalidMaximumDowntime {
        asset_id: String,
    },
    InvalidScheduledWindow {
        asset_id: String,
    },
    MissingCrewRole {
        crew_role: String,
    },
    MissingField {
        field: &'static str,
    },
    MissingPart {
        part_id: String,
    },
    MultipleSelectionsForAsset {
        asset_id: String,
    },
    NoEligibleMaintenanceWindow {
        asset_id: String,
    },
    PartInventoryViolation {
        part_id: String,
    },
    UnknownAsset {
        asset_id: String,
    },
    UnknownSolverVariable {
        variable_name: String,
    },
}

impl fmt::Display for MaintenanceOptimizationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ArithmeticOverflow => write!(formatter, "an arithmetic operation overflowed"),
            Self::CrewCapacityViolation { crew_role, slot } => write!(
                formatter,
                "crew role '{}' exceeds available capacity in planning slot {}",
                crew_role, slot
            ),
            Self::DowntimeConstraintViolation { asset_id } => write!(
                formatter,
                "asset '{}' exceeds its maximum consecutive downtime allowance",
                asset_id
            ),
            Self::DuplicateAssetId { asset_id } => {
                write!(formatter, "asset identifier '{}' is duplicated", asset_id)
            }
            Self::DuplicateCrewRole { crew_role } => {
                write!(formatter, "crew role '{}' is duplicated", crew_role)
            }
            Self::DuplicatePartId { part_id } => {
                write!(formatter, "part identifier '{}' is duplicated", part_id)
            }
            Self::IncompleteSolverSchedule => write!(
                formatter,
                "solver output does not schedule every required asset exactly once"
            ),
            Self::InvalidDueSlot { asset_id } => {
                write!(formatter, "asset '{}' has an invalid due slot", asset_id)
            }
            Self::InvalidHorizon => {
                write!(formatter, "planning horizon must contain at least one slot")
            }
            Self::InvalidMaintenanceDuration { asset_id } => write!(
                formatter,
                "asset '{}' has an invalid maintenance duration",
                asset_id
            ),
            Self::InvalidMaximumDowntime { asset_id } => write!(
                formatter,
                "asset '{}' has an invalid maximum downtime allowance",
                asset_id
            ),
            Self::InvalidScheduledWindow { asset_id } => write!(
                formatter,
                "asset '{}' has a schedule outside allowed time boundaries",
                asset_id
            ),
            Self::MissingCrewRole { crew_role } => {
                write!(formatter, "no availability exists for crew role '{}'", crew_role)
            }
            Self::MissingField { field } => write!(formatter, "field '{}' is required", field),
            Self::MissingPart { part_id } => {
                write!(formatter, "no inventory exists for part '{}'", part_id)
            }
            Self::MultipleSelectionsForAsset { asset_id } => write!(
                formatter,
                "solver selected more than one maintenance start for asset '{}'",
                asset_id
            ),
            Self::NoEligibleMaintenanceWindow { asset_id } => write!(
                formatter,
                "asset '{}' has no feasible maintenance start before its deadline",
                asset_id
            ),
            Self::PartInventoryViolation { part_id } => write!(
                formatter,
                "scheduled maintenance exceeds inventory for part '{}'",
                part_id
            ),
            Self::UnknownAsset { asset_id } => {
                write!(formatter, "schedule references unknown asset '{}'", asset_id)
            }
            Self::UnknownSolverVariable { variable_name } => write!(
                formatter,
                "solver response references unknown variable '{}'",
                variable_name
            ),
        }
    }
}

impl std::error::Error for MaintenanceOptimizationError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn standard_input() -> MaintenancePlanningInput {
        MaintenancePlanningInput {
            horizon_slots: 8,
            assets: vec![
                MaintenanceAsset {
                    asset_id: "sensor-west".to_owned(),
                    asset_kind: AssetKind::CorridorSensor,
                    corridor_id: "west-corridor".to_owned(),
                    required_crew_role: "field-tech".to_owned(),
                    required_part_id: "sensor-calibration-kit".to_owned(),
                    maintenance_duration_slots: 1,
                    due_by_slot: 4,
                    maximum_consecutive_downtime_slots: 1,
                    continuity_disruption_weight: 50,
                    essential_service_asset: true,
                },
                MaintenanceAsset {
                    asset_id: "charging-east".to_owned(),
                    asset_kind: AssetKind::ChargingStation,
                    corridor_id: "east-corridor".to_owned(),
                    required_crew_role: "electrical-tech".to_owned(),
                    required_part_id: "charger-filter".to_owned(),
                    maintenance_duration_slots: 2,
                    due_by_slot: 6,
                    maximum_consecutive_downtime_slots: 2,
                    continuity_disruption_weight: 90,
                    essential_service_asset: true,
                },
            ],
            crews: vec![
                CrewAvailability {
                    crew_role: "field-tech".to_owned(),
                    available_crew_count_by_slot: BTreeMap::from([
                        (0, 1),
                        (1, 1),
                        (2, 1),
                        (3, 1),
                        (4, 1),
                        (5, 1),
                        (6, 1),
                        (7, 1),
                    ]),
                },
                CrewAvailability {
                    crew_role: "electrical-tech".to_owned(),
                    available_crew_count_by_slot: BTreeMap::from([
                        (0, 1),
                        (1, 1),
                        (2, 1),
                        (3, 1),
                        (4, 1),
                        (5, 1),
                        (6, 1),
                        (7, 1),
                    ]),
                },
            ],
            parts: vec![
                PartInventory {
                    part_id: "sensor-calibration-kit".to_owned(),
                    available_quantity: 1,
                },
                PartInventory {
                    part_id: "charger-filter".to_owned(),
                    available_quantity: 1,
                },
            ],
        }
    }

    #[test]
    fn deterministic_fallback_generates_a_feasible_plan() {
        let plan = solve_with_deterministic_fallback(&standard_input()).unwrap();

        assert_eq!(plan.scheduled_maintenance.len(), 2);
        assert!(plan.unscheduled_asset_ids.is_empty());
        assert!(plan.essential_service_continuity_preserved);
        assert_eq!(plan.scheduled_maintenance[0].asset_id, "charging-east");
        assert_eq!(plan.scheduled_maintenance[1].asset_id, "sensor-west");
    }

    #[test]
    fn model_contains_exactly_one_schedule_constraint_per_asset() {
        let model = build_preventive_maintenance_model(&standard_input()).unwrap();

        let scheduling_constraints = model
            .constraints
            .iter()
            .filter(|constraint| constraint.name.starts_with("schedule_exactly_once_"))
            .count();

        assert_eq!(scheduling_constraints, 2);
        assert!(model.objective.minimize);
        assert!(!model.binary_start_variables.is_empty());
    }

    #[test]
    fn rejects_downtime_longer_than_the_continuity_limit() {
        let mut input = standard_input();
        input.assets[0].maintenance_duration_slots = 3;
        input.assets[0].maximum_consecutive_downtime_slots = 2;

        assert!(matches!(
            build_preventive_maintenance_model(&input),
            Err(MaintenanceOptimizationError::DowntimeConstraintViolation { .. })
        ));
    }

    #[test]
    fn deterministic_fallback_reports_inventory_limited_work() {
        let mut input = standard_input();

        input.assets.push(MaintenanceAsset {
            asset_id: "sensor-central".to_owned(),
            asset_kind: AssetKind::CorridorSensor,
            corridor_id: "central-corridor".to_owned(),
            required_crew_role: "field-tech".to_owned(),
            required_part_id: "sensor-calibration-kit".to_owned(),
            maintenance_duration_slots: 1,
            due_by_slot: 7,
            maximum_consecutive_downtime_slots: 1,
            continuity_disruption_weight: 40,
            essential_service_asset: false,
        });

        let plan = solve_with_deterministic_fallback(&input).unwrap();

        assert_eq!(
            plan.unscheduled_asset_ids,
            vec!["sensor-central".to_owned()]
        );
    }

    #[test]
    fn materialized_solver_solution_rejects_duplicate_asset_selections() {
        let input = standard_input();
        let model = build_preventive_maintenance_model(&input).unwrap();

        let duplicate_solution = ExternalSolverSolution {
            selected_variable_names: BTreeSet::from([
                "maintain_sensor-west_at_0".to_owned(),
                "maintain_sensor-west_at_1".to_owned(),
                "maintain_charging-east_at_0".to_owned(),
            ]),
        };

        assert!(matches!(
            materialize_and_validate_solution(&input, &model, &duplicate_solution),
            Err(MaintenanceOptimizationError::MultipleSelectionsForAsset { .. })
        ));
    }

    #[test]
    fn essential_asset_requires_a_valid_maintenance_assignment() {
        let input = standard_input();

        let scheduled = vec![ScheduledMaintenance {
            asset_id: "sensor-west".to_owned(),
            start_slot: 0,
            end_slot_exclusive: 1,
        }];

        assert!(!essential_service_continuity_is_preserved(
            &input,
            &scheduled
        ));
    }
}
