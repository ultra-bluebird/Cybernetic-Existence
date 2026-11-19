package augmentedhub.governance;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

public final class AbstractEnergyPriorityQueue {
    public enum AdmissionStatus {
        ADMITTED_FOR_SIMULATION,
        SIMULATION_TASK_DEFERRED_FOR_REVIEW,
        INVALID_MODEL_INPUT
    }

    public record Task(
            String taskId,
            double abstractActivityFraction,
            double abstractCostPerSecond,
            double durationSeconds,
            double declaredImportance,
            double continuityRelevance,
            double uncertainty,
            double deadlineSecondsFromNow
    ) {
        public Task {
            requireOpaqueToken(taskId, "taskId");
            requireUnitInterval(abstractActivityFraction, "abstractActivityFraction");
            requireNonNegative(abstractCostPerSecond, "abstractCostPerSecond");
            requireNonNegative(durationSeconds, "durationSeconds");
            requireUnitInterval(declaredImportance, "declaredImportance");
            requireUnitInterval(continuityRelevance, "continuityRelevance");
            requireUnitInterval(uncertainty, "uncertainty");
            requireNonNegative(deadlineSecondsFromNow, "deadlineSecondsFromNow");
        }

        public double abstractEnergyCost() {
            return abstractActivityFraction * abstractCostPerSecond * durationSeconds;
        }
    }

    public record QueueWeights(
            double deadlineWeight,
            double importanceWeight,
            double continuityWeight,
            double uncertaintyWeight
    ) {
        public QueueWeights {
            requireUnitInterval(deadlineWeight, "deadlineWeight");
            requireUnitInterval(importanceWeight, "importanceWeight");
            requireUnitInterval(continuityWeight, "continuityWeight");
            requireUnitInterval(uncertaintyWeight, "uncertaintyWeight");

            double sum = deadlineWeight + importanceWeight + continuityWeight + uncertaintyWeight;
            if (Math.abs(sum - 1.0d) > 1.0e-12d) {
                throw new IllegalArgumentException("Queue weights must sum to 1.0");
            }
        }
    }

    public record Budget(
            double baselineEnergy,
            double hubEnergy,
            double offloadEnergy,
            double maximumResearchEnergy,
            boolean advisoryOnly,
            boolean humanReviewRequired
    ) {
        public Budget {
            requireNonNegative(baselineEnergy, "baselineEnergy");
            requireNonNegative(hubEnergy, "hubEnergy");
            requireNonNegative(offloadEnergy, "offloadEnergy");
            requireNonNegative(maximumResearchEnergy, "maximumResearchEnergy");

            if (!advisoryOnly) {
                throw new IllegalArgumentException("advisoryOnly must be true");
            }

            if (!humanReviewRequired) {
                throw new IllegalArgumentException("humanReviewRequired must be true");
            }
        }
    }

    public record ScheduledTask(
            Task task,
            double priority,
            AdmissionStatus status,
            String explanation
    ) {
    }

    private AbstractEnergyPriorityQueue() {
    }

    public static List<ScheduledTask> schedule(
            List<Task> tasks,
            QueueWeights weights,
            Budget budget
    ) {
        Objects.requireNonNull(tasks, "tasks");
        Objects.requireNonNull(weights, "weights");
        Objects.requireNonNull(budget, "budget");

        List<Task> ordered = new ArrayList<>(tasks);
        ordered.sort(Comparator
                .comparingDouble((Task task) -> priority(task, weights))
                .reversed()
                .thenComparing(Task::taskId));

        List<ScheduledTask> results = new ArrayList<>();
        double projected = budget.baselineEnergy() + budget.hubEnergy() + budget.offloadEnergy();

        for (Task task : ordered) {
            double score = priority(task, weights);
            double candidateTotal = projected + task.abstractEnergyCost();

            if (task.uncertainty() > 0.5d) {
                results.add(new ScheduledTask(
                        task,
                        score,
                        AdmissionStatus.SIMULATION_TASK_DEFERRED_FOR_REVIEW,
                        "Task has high model uncertainty. It is deferred for human review."
                ));
                continue;
            }

            if (candidateTotal > budget.maximumResearchEnergy()) {
                results.add(new ScheduledTask(
                        task,
                        score,
                        AdmissionStatus.SIMULATION_TASK_DEFERRED_FOR_REVIEW,
                        "Task exceeds the configured synthetic research-energy budget."
                ));
                continue;
            }

            projected = candidateTotal;
            results.add(new ScheduledTask(
                    task,
                    score,
                    AdmissionStatus.ADMITTED_FOR_SIMULATION,
                    "Task is admitted only to the abstract, advisory simulation queue."
            ));
        }

        return List.copyOf(results);
    }

    public static double totalAbstractEnergy(
            Budget budget,
            List<ScheduledTask> scheduledTasks
    ) {
        Objects.requireNonNull(budget, "budget");
        Objects.requireNonNull(scheduledTasks, "scheduledTasks");

        double taskEnergy = scheduledTasks.stream()
                .filter(entry -> entry.status() == AdmissionStatus.ADMITTED_FOR_SIMULATION)
                .mapToDouble(entry -> entry.task().abstractEnergyCost())
                .sum();

        return budget.baselineEnergy() + budget.hubEnergy() + budget.offloadEnergy() + taskEnergy;
    }

    private static double priority(Task task, QueueWeights weights) {
        double deadlineTerm = 1.0d / (1.0d + task.deadlineSecondsFromNow());
        double score = weights.deadlineWeight() * deadlineTerm
                + weights.importanceWeight() * task.declaredImportance()
                + weights.continuityWeight() * task.continuityRelevance()
                - weights.uncertaintyWeight() * task.uncertainty();

        return Math.max(0.0d, Math.min(1.0d, score));
    }

    private static void requireUnitInterval(double value, String field) {
        if (!Double.isFinite(value) || value < 0.0d || value > 1.0d) {
            throw new IllegalArgumentException(field + " must be finite and in [0, 1]");
        }
    }

    private static void requireNonNegative(double value, String field) {
        if (!Double.isFinite(value) || value < 0.0d) {
            throw new IllegalArgumentException(field + " must be finite and non-negative");
        }
    }

    private static void requireOpaqueToken(String value, String field) {
        if (value == null || !value.matches("^[A-Za-z0-9][A-Za-z0-9._~-]{7,127}$")) {
            throw new IllegalArgumentException(field + " must be an opaque token");
        }
    }
}
