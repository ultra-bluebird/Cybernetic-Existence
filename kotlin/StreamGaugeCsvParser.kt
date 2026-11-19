package org.augmentedhub.cyboquatic

import java.io.BufferedReader
import java.io.Reader
import java.math.BigDecimal
import java.time.Instant

data class GaugeObservation(
    val gaugeId: String,
    val observedAt: Instant,
    val parameterCode: String,
    val value: BigDecimal,
    val unitCode: String,
    val qualifier: String?
)

sealed interface ParseResult {
    data class Accepted(val observation: GaugeObservation) : ParseResult
    data class Rejected(val lineNumber: Long, val reason: String) : ParseResult
}

object StreamGaugeCsvParser {
    private const val MaxLineLength = 16_384
    private const val RequiredSiteField = "site_no"
    private const val RequiredTimeField = "datetime"
    private const val RequiredParameterSuffix = "_00060"
    private const val RequiredUnitSuffix = "_00060_cd"

    fun parse(reader: Reader): Sequence<ParseResult> = sequence {
        BufferedReader(reader).use { buffered ->
            var lineNumber = 0L
            var header: List<String>? = null

            while (true) {
                val line = buffered.readLine() ?: break
                lineNumber++

                if (line.length > MaxLineLength) {
                    yield(ParseResult.Rejected(lineNumber, "line exceeds maximum length"))
                    continue
                }

                if (line.isBlank() || line.startsWith("#")) {
                    continue
                }

                if (header == null) {
                    val fields = splitCsvLine(line)
                    if (fields.isEmpty() || fields[0] != "agency_cd") {
                        continue
                    }

                    header = fields
                    val missing = listOf(RequiredSiteField, RequiredTimeField)
                        .filterNot { it in header }

                    if (missing.isNotEmpty()) {
                        yield(
                            ParseResult.Rejected(
                                lineNumber,
                                "header is missing required fields: ${missing.joinToString(",")}"
                            )
                        )
                        return@sequence
                    }

                    continue
                }

                val columns = splitCsvLine(line)
                if (columns.size != header.size) {
                    yield(ParseResult.Rejected(lineNumber, "column count does not match header"))
                    continue
                }

                val record = header.zip(columns).toMap()
                val gaugeId = record[RequiredSiteField]?.trim().orEmpty()
                val timestampText = record[RequiredTimeField]?.trim().orEmpty()
                val parameterField = header.firstOrNull {
                    it.endsWith(RequiredParameterSuffix) && !it.endsWith(RequiredUnitSuffix)
                }

                if (gaugeId.isEmpty()) {
                    yield(ParseResult.Rejected(lineNumber, "site_no is empty"))
                    continue
                }

                if (parameterField == null) {
                    yield(
                        ParseResult.Rejected(
                            lineNumber,
                            "no instantaneous discharge parameter ending in _00060 was found"
                        )
                    )
                    continue
                }

                val valueText = record[parameterField]?.trim().orEmpty()
                val unitText = record["${parameterField}_cd"]?.trim().orEmpty()
                val qualifier = record["${parameterField}_cd"]?.trim()?.ifBlank { null }

                val timestamp = runCatching { Instant.parse(timestampText) }.getOrElse {
                    yield(ParseResult.Rejected(lineNumber, "datetime is not an RFC 3339 UTC instant"))
                    continue
                }

                val value = runCatching { BigDecimal(valueText) }.getOrElse {
                    yield(ParseResult.Rejected(lineNumber, "discharge value is not numeric"))
                    continue
                }

                if (value.signum() < 0) {
                    yield(ParseResult.Rejected(lineNumber, "discharge value must be non-negative"))
                    continue
                }

                if (unitText.isEmpty()) {
                    yield(ParseResult.Rejected(lineNumber, "discharge unit code is empty"))
                    continue
                }

                yield(
                    ParseResult.Accepted(
                        GaugeObservation(
                            gaugeId = gaugeId,
                            observedAt = timestamp,
                            parameterCode = parameterField,
                            value = value,
                            unitCode = unitText,
                            qualifier = qualifier
                        )
                    )
                )
            }

            if (header == null) {
                yield(ParseResult.Rejected(lineNumber, "no USGS-style header row was found"))
            }
        }
    }

    private fun splitCsvLine(line: String): List<String> {
        val result = ArrayList<String>()
        val field = StringBuilder()
        var quoted = false
        var index = 0

        while (index < line.length) {
            val character = line[index]
            when {
                character == '"' && quoted && index + 1 < line.length && line[index + 1] == '"' -> {
                    field.append('"')
                    index++
                }
                character == '"' -> quoted = !quoted
                character == ',' && !quoted -> {
                    result.add(field.toString())
                    field.clear()
                }
                else -> field.append(character)
            }
            index++
        }

        if (quoted) {
            return emptyList()
        }

        result.add(field.toString())
        return result
    }
}
