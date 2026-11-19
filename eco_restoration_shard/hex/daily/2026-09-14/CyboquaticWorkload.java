import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Locale;

public final class CyboquaticWorkload {
    private record Result(
        double energyreqJ,
        double estimatedCurrentA,
        double deltaVt,
        boolean valid,
        String reason
    ) {}

    private static boolean unitInterval(double value) {
        return Double.isFinite(value) && value >= 0.0 && value <= 1.0;
    }

    private static boolean knownTask(String taskType) {
        return switch (taskType) {
            case "debris_skim", "sediment_dredge", "biofilm_scrub", "aerator_drive" -> true;
            default -> false;
        };
    }

    private static boolean knownMedia(String mediaClass) {
        return switch (mediaClass) {
            case "known_safe", "unmodeled_media", "pfas_suspected",
                 "hazardous_material", "unknown" -> true;
            default -> false;
        };
    }

    private static Result evaluate(String[] fields) {
        if (fields.length != 13) {
            return new Result(0.0, 0.0, 0.0, false, "expected 13 CSV columns");
        }

        final String taskType = fields[2];
        final String mediaClass = fields[12];

        if (!knownTask(taskType)) {
            return new Result(0.0, 0.0, 0.0, false, "unsupported task_type");
        }

        if (!knownMedia(mediaClass)) {
            return new Result(0.0, 0.0, 0.0, false, "unsupported media_class");
        }

        try {
            final double massKg = Double.parseDouble(fields[3]);
            final double distanceM = Double.parseDouble(fields[4]);
            final double dutySeconds = Double.parseDouble(fields[5]);
            final double ratedPowerW = Double.parseDouble(fields[6]);
            final double motorEfficiency = Double.parseDouble(fields[7]);
            final double baselineVoltageV = Double.parseDouble(fields[8]);
            final double internalResistanceOhm = Double.parseDouble(fields[9]);
            final double batterySoc = Double.parseDouble(fields[10]);
            final double renewableFraction = Double.parseDouble(fields[11]);

            if (massKg <= 0.0 ||
                distanceM < 0.0 ||
                dutySeconds <= 0.0 ||
                ratedPowerW <= 0.0 ||
                motorEfficiency <= 0.0 ||
                motorEfficiency > 1.0 ||
                baselineVoltageV <= 0.0 ||
                internalResistanceOhm < 0.0 ||
                !unitInterval(batterySoc) ||
                !unitInterval(renewableFraction)) {
                return new Result(
                    0.0, 0.0, 0.0, false,
                    "input violates physical or unit-interval bounds"
                );
            }

            final double estimatedCurrentA = ratedPowerW / baselineVoltageV;
            final double deltaVt = estimatedCurrentA * internalResistanceOhm;
            final double energyreqJ = (ratedPowerW * dutySeconds) / motorEfficiency;

            if (!Double.isFinite(estimatedCurrentA) ||
                !Double.isFinite(deltaVt) ||
                !Double.isFinite(energyreqJ) ||
                energyreqJ <= 0.0 ||
                deltaVt < 0.0) {
                return new Result(0.0, 0.0, 0.0, false, "invalid derived value");
            }

            return new Result(energyreqJ, estimatedCurrentA, deltaVt, true, "valid");
        } catch (NumberFormatException exception) {
            return new Result(0.0, 0.0, 0.0, false, "invalid numeric input");
        }
    }

    public static void main(String[] args) throws IOException {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(System.in))) {
            System.out.println(
                "workload_id,canal_node_id,energyreqJ,estimated_current_a,deltaVt,status,reason"
            );

            boolean firstLine = true;
            String line;

            while ((line = reader.readLine()) != null) {
                if (firstLine) {
                    firstLine = false;
                    continue;
                }

                if (line.isBlank()) {
                    continue;
                }

                String[] fields = line.split(",", -1);
                Result result = evaluate(fields);
                String workloadId = fields.length > 0 ? fields[0] : "";
                String canalNodeId = fields.length > 1 ? fields[1] : "";

                System.out.printf(
                    Locale.ROOT,
                    "%s,%s,%.6f,%.6f,%.6f,%s,%s%n",
                    workloadId,
                    canalNodeId,
                    result.energyreqJ(),
                    result.estimatedCurrentA(),
                    result.deltaVt(),
                    result.valid() ? "valid" : "rejected",
                    result.reason()
                );
            }
        }
    }
}
