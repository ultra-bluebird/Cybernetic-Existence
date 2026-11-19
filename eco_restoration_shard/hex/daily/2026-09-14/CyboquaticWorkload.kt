import java.util.Locale

data class WorkloadResult(
    val energyreqJ: Double,
    val estimatedCurrentA: Double,
    val deltaVt: Double,
    val valid: Boolean,
    val reason: String
)

fun unitInterval(value: Double): Boolean =
    value.isFinite() && value >= 0.0 && value <= 1.0

fun knownTask(taskType: String): Boolean =
    taskType in setOf(
        "debris_skim",
        "sediment_dredge",
        "biofilm_scrub",
        "aerator_drive"
    )

fun knownMedia(mediaClass: String): Boolean =
    mediaClass in setOf(
        "known_safe",
        "unmodeled_media",
        "pfas_suspected",
        "hazardous_material",
        "unknown"
    )

fun evaluate(fields: List<String>): WorkloadResult {
    if (fields.size != 13) {
        return WorkloadResult(0.0, 0.0, 0.0, false, "expected 13 CSV columns")
    }

    if (!knownTask(fields[2])) {
        return WorkloadResult(0.0, 0.0, 0.0, false, "unsupported task_type")
    }

    if (!knownMedia(fields[12])) {
        return WorkloadResult(0.0, 0.0, 0.0, false, "unsupported media_class")
    }

    val values = try {
        listOf(
            fields[3].toDouble(),
            fields[4].toDouble(),
            fields[5].toDouble(),
            fields[6].toDouble(),
            fields[7].toDouble(),
            fields[8].toDouble(),
            fields[9].toDouble(),
            fields[10].toDouble(),
            fields[11].toDouble()
        )
    } catch (_: NumberFormatException) {
        return WorkloadResult(0.0, 0.0, 0.0, false, "invalid numeric input")
    }

    val massKg = values[0]
    val distanceM = values[1]
    val dutySeconds = values[2]
    val ratedPowerW = values[3]
    val motorEfficiency = values[4]
    val baselineVoltageV = values[5]
    val internalResistanceOhm = values[6]
    val batterySoc = values[7]
    val renewableFraction = values[8]

    if (
        !values.all { it.isFinite() } ||
        massKg <= 0.0 ||
        distanceM < 0.0 ||
        dutySeconds <= 0.0 ||
        ratedPowerW <= 0.0 ||
        motorEfficiency <= 0.0 ||
        motorEfficiency > 1.0 ||
        baselineVoltageV <= 0.0 ||
        internalResistanceOhm < 0.0 ||
        !unitInterval(batterySoc) ||
        !unitInterval(renewableFraction)
    ) {
        return WorkloadResult(
            0.0,
            0.0,
            0.0,
            false,
            "input violates physical or unit-interval bounds"
        )
    }

    val estimatedCurrentA = ratedPowerW / baselineVoltageV
    val deltaVt = estimatedCurrentA * internalResistanceOhm
    val energyreqJ = (ratedPowerW * dutySeconds) / motorEfficiency

    if (
        !estimatedCurrentA.isFinite() ||
        !deltaVt.isFinite() ||
        !energyreqJ.isFinite() ||
        deltaVt < 0.0 ||
        energyreqJ <= 0.0
    ) {
        return WorkloadResult(0.0, 0.0, 0.0, false, "invalid derived value")
    }

    return WorkloadResult(energyreqJ, estimatedCurrentA, deltaVt, true, "valid")
}

fun main() {
    println("workload_id,canal_node_id,energyreqJ,estimated_current_a,deltaVt,status,reason")

    generateSequence(::readLine)
        .drop(1)
        .filter { it.isNotBlank() }
        .forEach { line ->
            val fields = line.split(",", ignoreCase = false, limit = 0)
            val result = evaluate(fields)
            val workloadId = fields.getOrElse(0) { "" }
            val canalNodeId = fields.getOrElse(1) { "" }

            println(
                String.format(
                    Locale.ROOT,
                    "%s,%s,%.6f,%.6f,%.6f,%s,%s",
                    workloadId,
                    canalNodeId,
                    result.energyreqJ,
                    result.estimatedCurrentA,
                    result.deltaVt,
                    if (result.valid) "valid" else "rejected",
                    result.reason
                )
            )
        }
}
