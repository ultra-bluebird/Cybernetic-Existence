package org.augmentedhub.conformance

import java.io.File
import java.nio.file.Path

/**
 * Result of reading a CSV file with header classification.
 */
data class CsvReadResult(
    val headers: List<String>,
    val rowCount: Int,
    val releaseClass: ReleaseClass,
    val sensitiveColumnsDetected: Set<String>,
    val warnings: List<String>
)

/**
 * Reader for CSV evidence files under docs/.
 * Performs header-only classification for sensitive columns,
 * limits row reads, and enforces privacy-preserving handling.
 */
object CsvEvidenceReader {

    private val SENSITIVE_HEADER_TOKENS = setOf(
        "name", "email", "phone", "address", "identity",
        "biometric", "health", "neural", "assistive", "cybernetic",
        "device_id", "ip", "latitude", "longitude", "location"
    )

    private val PERMITTED_ENVIRONMENTAL_COLUMNS = setOf(
        "timestamp", "unit", "sensor", "weather", "rainfall",
        "shade", "water", "maintenance", "condition", "route",
        "segment", "capacity", "temperature", "energy",
        "calibration", "uncertainty", "habitat", "vegetation",
        "species", "sensitivity", "class", "measurement",
        "value", "quality", "coefficient", "factor", "ratio",
        "index", "score", "margin", "threshold", "limit",
        "duration", "interval", "period", "age", "freshness",
        "completeness", "alignment", "efficiency", "availability",
        "accessibility", "continuity", "safety", "refuge",
        "corridor", "provenance", "evidence", "observation"
    )

    /**
     * Discover all CSV files under the docs directory.
     */
    @JvmStatic
    fun discoverCsvFiles(docsDirectory: File): List<Path> {
        require(docsDirectory.exists() && docsDirectory.isDirectory) {
            "Docs directory must exist: ${docsDirectory.absolutePath}"
        }

        return docsDirectory.walkTopDown()
            .filter { it.isFile && it.name.endsWith(".csv") }
            .map { it.toPath() }
            .toList()
    }

    /**
     * Read only the header row from a CSV file.
     */
    @JvmStatic
    fun readHeader(csvPath: Path): List<String> {
        val file = csvPath.toFile()
        require(file.exists()) { "CSV file must exist: ${csvPath.toAbsolutePath()}" }

        return file.useLines { lines ->
            lines.firstOrNull()?.parseCsvLine() ?: emptyList()
        }
    }

    /**
     * Read CSV rows up to maxRows limit.
     * Does not persist raw contents or print full rows.
     */
    @JvmStatic
    fun readRows(csvPath: Path, maxRows: Int): CsvReadResult {
        val file = csvPath.toFile()
        require(file.exists()) { "CSV file must exist: ${csvPath.toAbsolutePath()}" }
        require(maxRows > 0) { "maxRows must be positive" }

        val headers = readHeader(csvPath)
        val sensitiveColumns = classifyColumns(headers)
        
        var rowCount = 0
        val warnings = mutableListOf<String>()
        var releaseClass = ReleaseClass.PUBLIC

        if (sensitiveColumns.isNotEmpty()) {
            releaseClass = ReleaseClass.LOCAL_ONLY
            warnings.add("CSV contains potentially sensitive columns. Processing is restricted to LOCAL_ONLY. Minimize column usage.")
        }

        // Count rows without storing them
        file.useLines { lines ->
            val dataLines = lines.drop(1).take(maxRows)
            rowCount = dataLines.count()
        }

        if (rowCount == maxRows) {
            warnings.add("Row count limited to $maxRows. Additional rows may exist.")
        }

        return CsvReadResult(
            headers = headers,
            rowCount = rowCount,
            releaseClass = releaseClass,
            sensitiveColumnsDetected = sensitiveColumns,
            warnings = warnings
        )
    }

    /**
     * Classify columns by detecting likely sensitive headers.
     * Returns set of detected sensitive column names.
     */
    @JvmStatic
    fun classifyColumns(headers: List<String>): Set<String> {
        val sensitive = mutableSetOf<String>()

        for (header in headers) {
            val normalized = header.lowercase().trim()
            
            for (token in SENSITIVE_HEADER_TOKENS) {
                if (normalized.contains(token)) {
                    sensitive.add(header)
                    break
                }
            }
        }

        return sensitive
    }

    private fun String.parseCsvLine(): List<String> {
        val result = mutableListOf<String>()
        var current = StringBuilder()
        var inQuotes = false

        for ((i, char) in this.withIndex()) {
            when {
                char == '"' -> {
                    if (inQuotes && i + 1 < length && this[i + 1] == '"') {
                        current.append('"')
                    } else {
                        inQuotes = !inQuotes
                    }
                }
                char == ',' && !inQuotes -> {
                    result.add(current.toString().trim())
                    current = StringBuilder()
                }
                else -> {
                    current.append(char)
                }
            }
        }

        result.add(current.toString().trim())
        return result
    }
}
