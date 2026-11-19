package org.augmentedhub.android.metrics

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive

enum class CoverageStatus {
    Sufficient,
    Insufficient,
    NotReported,
}

@Composable
fun CoverageStatusBanner(
    result: JsonObject,
    modifier: Modifier = Modifier,
) {
    val status = result.coverageStatus()

    val (label, message, color) = when (status) {
        CoverageStatus.Sufficient -> Triple(
            "Sufficient",
            "Coverage is sufficient for the metric's declared reporting threshold.",
            MaterialTheme.colorScheme.primaryContainer,
        )

        CoverageStatus.Insufficient -> Triple(
            "Insufficient",
            "Coverage is insufficient. Interpret this result cautiously and do not use it for ranking or material allocation decisions.",
            MaterialTheme.colorScheme.errorContainer,
        )

        CoverageStatus.NotReported -> Triple(
            "Not Reported",
            "This metric response did not report a coverage status.",
            MaterialTheme.colorScheme.surfaceVariant,
        )
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(color)
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .semantics {
                contentDescription = "Coverage status: $label. $message"
            },
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = "Coverage:",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

private fun JsonObject.coverageStatus(): CoverageStatus {
    val rawStatus = this["coverage_status"]
        ?.jsonPrimitive
        ?.content
        ?.trim()
        ?.lowercase()

    return when (rawStatus) {
        "sufficient" -> CoverageStatus.Sufficient
        "insufficient", "insufficient_coverage" -> CoverageStatus.Insufficient
        else -> CoverageStatus.NotReported
    }
}
