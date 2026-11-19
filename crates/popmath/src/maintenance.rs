use crate::bounds::PositiveF64;
use crate::error::{PopmathError, PopmathResult};
use crate::units::{DurationSeconds, PopulationCount};

/// Input for an aggregate maintenance-backlog projection.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MaintenanceBacklogInput {
    /// Open work items at the start of the period.
    pub opening_backlog: PopulationCount,
    /// New work items expected during the period.
    pub expected_arrivals: PopulationCount,
    /// Completed work items expected during the period.
    pub expected_completions: PopulationCount,
    /// Maximum acceptable backlog at period end.
    pub target_backlog: PopulationCount,
}

/// Result of a deterministic maintenance-backlog projection.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MaintenanceBacklogResult {
    /// Projected backlog at period end.
    pub projected_backlog: PopulationCount,
    /// Work items beyond the declared target.
    pub excess_backlog: PopulationCount,
    /// Whether the target backlog is met.
    pub target_met: bool,
}

/// Calculates a projected maintenance backlog.
pub fn calculate_maintenance_backlog(
    input: MaintenanceBacklogInput,
) -> PopmathResult<MaintenanceBacklogResult> {
    let projected = input
        .opening_backlog
        .get()
        .saturating_add(input.expected_arrivals.get())
        .saturating_sub(input.expected_completions.get());

    let projected_backlog = PopulationCount::new(projected);
    let excess_backlog =
        PopulationCount::new(projected.saturating_sub(input.target_backlog.get()));

    Ok(MaintenanceBacklogResult {
        projected_backlog,
        excess_backlog,
        target_met: excess_backlog.get() == 0,
    })
}

/// Input for a response-capacity calculation.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MaintenanceResponseInput {
    /// Available crews.
    pub crew_count: PopulationCount,
    /// Mean completed tasks per crew during the period.
    pub tasks_per_crew: PositiveF64,
    /// Required response tasks during the period.
    pub required_tasks: PopulationCount,
    /// Target maximum response duration.
    pub response_target: DurationSeconds,
    /// Modeled average response duration.
    pub modeled_response_duration: DurationSeconds,
}

/// Result of aggregate response-capacity analysis.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MaintenanceResponseResult {
    /// Projected completed tasks during the period.
    pub projected_task_capacity: PopulationCount,
    /// Task deficit relative to required tasks.
    pub task_deficit: PopulationCount,
    /// Whether the declared response target is met.
    pub response_target_met: bool,
    /// Whether task capacity meets projected need.
    pub capacity_met: bool,
}

/// Calculates crew task capacity and response-target status.
pub fn calculate_maintenance_response(
    input: MaintenanceResponseInput,
) -> PopmathResult<MaintenanceResponseResult> {
    let projected_capacity = (input.crew_count.get() as f64 * input.tasks_per_crew.get()).floor();

    if projected_capacity > u64::MAX as f64 {
        return Err(PopmathError::NumericalInstability {
            component: "maintenance_task_capacity",
        });
    }

    let projected_task_capacity = PopulationCount::new(projected_capacity as u64);
    let task_deficit = PopulationCount::new(
        input
            .required_tasks
            .get()
            .saturating_sub(projected_task_capacity.get()),
    );

    Ok(MaintenanceResponseResult {
        projected_task_capacity,
        task_deficit,
        response_target_met: input.modeled_response_duration.get() <= input.response_target.get(),
        capacity_met: task_deficit.get() == 0,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn backlog_projection_tracks_excess() {
        let result = calculate_maintenance_backlog(MaintenanceBacklogInput {
            opening_backlog: PopulationCount::new(20),
            expected_arrivals: PopulationCount::new(15),
            expected_completions: PopulationCount::new(10),
            target_backlog: PopulationCount::new(18),
        })
        .expect("valid backlog calculation");

        assert_eq!(result.projected_backlog.get(), 25);
        assert_eq!(result.excess_backlog.get(), 7);
        assert!(!result.target_met);
    }

    #[test]
    fn response_capacity_reports_shortfall() {
        let result = calculate_maintenance_response(MaintenanceResponseInput {
            crew_count: PopulationCount::new(2),
            tasks_per_crew: PositiveF64::new(5.0, "tasks_per_crew").expect("valid"),
            required_tasks: PopulationCount::new(12),
            response_target: DurationSeconds::new(7_200.0).expect("valid"),
            modeled_response_duration: DurationSeconds::new(8_000.0).expect("valid"),
        })
        .expect("valid response calculation");

        assert_eq!(result.projected_task_capacity.get(), 10);
        assert_eq!(result.task_deficit.get(), 2);
        assert!(!result.response_target_met);
        assert!(!result.capacity_met);
    }
}
