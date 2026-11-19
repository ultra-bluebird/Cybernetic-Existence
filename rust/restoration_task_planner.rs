use std::cmp::Ordering;
use std::collections::BinaryHeap;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TaskCandidate {
    pub task_reference: u64,
    pub host_energy_cost: f64,
    pub swarm_energy_cost: f64,
    pub ecological_benefit: f64,
    pub photo_vulnerability: f64,
    pub thermal_stress: f64,
    pub return_energy_reserve: f64,
    pub required_return_reserve: f64,
    pub evidence_quality: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PlanningWeights {
    pub host_energy: f64,
    pub swarm_energy: f64,
    pub ecological_benefit: f64,
    pub photo_vulnerability: f64,
    pub thermal_stress: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskDecision {
    Eligible,
    WithheldInsufficientEvidence,
    WithheldThermalStress,
    WithheldReturnReserve,
    WithheldInvalidInput,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EvaluatedTask {
    pub task_reference: u64,
    pub decision: TaskDecision,
    pub priority_cost: f64,
}

impl Eq for EvaluatedTask {}

impl Ord for EvaluatedTask {
    fn cmp(&self, other: &Self) -> Ordering {
        other
            .priority_cost
            .partial_cmp(&self.priority_cost)
            .unwrap_or(Ordering::Equal)
    }
}

impl PartialOrd for EvaluatedTask {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

pub fn evaluate_task(
    task: TaskCandidate,
    weights: PlanningWeights,
    minimum_evidence_quality: f64,
    maximum_thermal_stress: f64,
) -> EvaluatedTask {
    let values = [
        task.host_energy_cost,
        task.swarm_energy_cost,
        task.ecological_benefit,
        task.photo_vulnerability,
        task.thermal_stress,
        task.return_energy_reserve,
        task.required_return_reserve,
        task.evidence_quality,
        weights.host_energy,
        weights.swarm_energy,
        weights.ecological_benefit,
        weights.photo_vulnerability,
        weights.thermal_stress,
        minimum_evidence_quality,
        maximum_thermal_stress,
    ];

    if values.iter().any(|value| !value.is_finite() || *value < 0.0) {
        return EvaluatedTask {
            task_reference: task.task_reference,
            decision: TaskDecision::WithheldInvalidInput,
            priority_cost: f64::INFINITY,
        };
    }

    if task.evidence_quality < minimum_evidence_quality {
        return EvaluatedTask {
            task_reference: task.task_reference,
            decision: TaskDecision::WithheldInsufficientEvidence,
            priority_cost: f64::INFINITY,
        };
    }

    if task.thermal_stress > maximum_thermal_stress {
        return EvaluatedTask {
            task_reference: task.task_reference,
            decision: TaskDecision::WithheldThermalStress,
            priority_cost: f64::INFINITY,
        };
    }

    if task.return_energy_reserve < task.required_return_reserve {
        return EvaluatedTask {
            task_reference: task.task_reference,
            decision: TaskDecision::WithheldReturnReserve,
            priority_cost: f64::INFINITY,
        };
    }

    let priority_cost = weights.host_energy * task.host_energy_cost
        + weights.swarm_energy * task.swarm_energy_cost
        + weights.photo_vulnerability * task.photo_vulnerability
        + weights.thermal_stress * task.thermal_stress
        - weights.ecological_benefit * task.ecological_benefit;

    EvaluatedTask {
        task_reference: task.task_reference,
        decision: TaskDecision::Eligible,
        priority_cost,
    }
}

pub fn plan(tasks: Vec<TaskCandidate>, weights: PlanningWeights, minimum_evidence_quality: f64, maximum_thermal_stress: f64) -> Vec<EvaluatedTask> {
    let mut queue = BinaryHeap::new();

    for task in tasks {
        let evaluated = evaluate_task(
            task,
            weights,
            minimum_evidence_quality,
            maximum_thermal_stress,
        );

        if evaluated.decision == TaskDecision::Eligible {
            queue.push(evaluated);
        }
    }

    queue.into_sorted_vec()
}
