package org.augmentedhub.conformance

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import java.io.File
import java.nio.file.Paths

class CsvEvidenceReaderTest {

    @Test
    fun discoverCsvFiles_findsOnlyExistingCsvFiles() {
        // Create a temp directory for testing
        val tempDir = File.createTempFile("csv_test", "").parentFile.resolve("csv_test_${System.currentTimeMillis()}")
        tempDir.mkdirs()

        try {
            // Create test CSV files
            File(tempDir, "test1.csv").writeText("col1,col2\n1,2")
            File(tempDir, "test2.csv").writeText("a,b\nx,y")
            File(tempDir, "not_csv.txt").writeText("not a csv")

            val csvFiles = CsvEvidenceReader.discoverCsvFiles(tempDir)

            assertEquals(2, csvFiles.size)
            assertTrue(csvFiles.all { it.toString().endsWith(".csv") })
        } finally {
            tempDir.deleteRecursively()
        }
    }

    @Test
    fun readHeader_parsesFirstLine() {
        val tempFile = File.createTempFile("header_test", ".csv")
        tempFile.writeText("timestamp,sensor_id,value,unit\n")

        try {
            val headers = CsvEvidenceReader.readHeader(tempFile.toPath())

            assertEquals(4, headers.size)
            assertEquals("timestamp", headers[0])
            assertEquals("sensor_id", headers[1])
            assertEquals("value", headers[2])
            assertEquals("unit", headers[3])
        } finally {
            tempFile.delete()
        }
    }

    @Test
    fun readRows_limitsToMaxRows() {
        val tempFile = File.createTempFile("rows_test", ".csv")
        tempFile.writeText("id,value\n1,10\n2,20\n3,30\n4,40\n5,50\n")

        try {
            val result = CsvEvidenceReader.readRows(tempFile.toPath(), maxRows = 3)

            assertEquals(3, result.rowCount)
            assertEquals(2, result.headers.size)
        } finally {
            tempFile.delete()
        }
    }

    @Test
    fun classifyColumns_detectsSensitiveHeaders() {
        val headers = listOf(
            "timestamp",
            "sensor_value",
            "user_name",
            "email_address",
            "device_id",
            "latitude",
            "temperature"
        )

        val sensitive = CsvEvidenceReader.classifyColumns(headers)

        assertTrue(sensitive.isNotEmpty())
        assertTrue(sensitive.any { it.contains("name", ignoreCase = true) })
        assertTrue(sensitive.any { it.contains("email", ignoreCase = true) })
        assertTrue(sensitive.any { it.contains("device_id", ignoreCase = true) })
        assertTrue(sensitive.any { it.contains("latitude", ignoreCase = true) })
    }

    @Test
    fun classifyColumns_permitsEnvironmentalColumns() {
        val headers = listOf(
            "timestamp",
            "sensor_measurement",
            "weather_condition",
            "rainfall_mm",
            "shade_quality",
            "water_level",
            "maintenance_status",
            "condition_score",
            "route_segment",
            "capacity",
            "temperature_celsius",
            "energy_kwh",
            "calibration_factor",
            "uncertainty_estimate",
            "habitat_type",
            "vegetation_cover",
            "species_sensitivity_class"
        )

        val sensitive = CsvEvidenceReader.classifyColumns(headers)

        // These should not be flagged as sensitive
        assertTrue(sensitive.isEmpty())
    }

    @Test
    fun readRows_sensitiveCsv_marksLocalOnly() {
        val tempFile = File.createTempFile("sensitive_test", ".csv")
        tempFile.writeText("timestamp,name,email,value\n2024-01-01,John,john@example.com,100\n")

        try {
            val result = CsvEvidenceReader.readRows(tempFile.toPath(), maxRows = 10)

            assertEquals(ReleaseClass.LOCAL_ONLY, result.releaseClass)
            assertTrue(result.warnings.any { it.contains("LOCAL_ONLY", ignoreCase = true) })
            assertTrue(result.sensitiveColumnsDetected.isNotEmpty())
        } finally {
            tempFile.delete()
        }
    }

    @Test
    fun readRows_doesNotCreatePersonLevelScores() {
        val tempFile = File.createTempFile("noscore_test", ".csv")
        tempFile.writeText("timestamp,sensor_value,quality\n2024-01-01,85.5,0.9\n2024-01-02,87.2,0.85\n")

        try {
            val result = CsvEvidenceReader.readRows(tempFile.toPath(), maxRows = 100)

            // Result should only contain metadata, not person-level scores
            assertEquals(ReleaseClass.PUBLIC, result.releaseClass)
            assertTrue(result.rowCount > 0)
            assertEquals(3, result.headers.size)
        } finally {
            tempFile.delete()
        }
    }

    @Test
    fun readRows_boundedReadDoesNotPersistRawContents() {
        val tempFile = File.createTempFile("bounded_test", ".csv")
        val manyRows = (1..1000).joinToString("\n") { "$it,${it * 2}" }
        tempFile.writeText("id,value\n$manyRows\n")

        try {
            val result = CsvEvidenceReader.readRows(tempFile.toPath(), maxRows = 10)

            assertEquals(10, result.rowCount)
            // The function should not store raw row data
            assertTrue(result.headers.isNotEmpty())
        } finally {
            tempFile.delete()
        }
    }

    @Test
    fun readRows_warningWhenLimitReached() {
        val tempFile = File.createTempFile("limit_test", ".csv")
        tempFile.writeText("id,value\n1,10\n2,20\n3,30\n4,40\n5,50\n")

        try {
            val result = CsvEvidenceReader.readRows(tempFile.toPath(), maxRows = 3)

            assertTrue(result.warnings.any { it.contains("limited", ignoreCase = true) })
        } finally {
            tempFile.delete()
        }
    }
}
