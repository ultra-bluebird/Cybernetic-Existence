package org.augmentedhub.android.metrics

import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import org.augmentedhub.metrics.KeyValidationResult
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class ProhibitedKeyValidatorTest {
    @Test
    fun normalizesCaseAndPunctuationBeforeMatching() {
        assertEquals(
            "medicalhistory",
            ProhibitedKeyValidator.normalizeKey("Medical_History"),
        )
    }

    @Test
    fun rejectsNestedMedicalKey() {
        val payload = buildJsonObject {
            putJsonObject("environment") {
                put("medical_history", "not permitted")
            }
        }

        val result = ProhibitedKeyValidator.validate(payload)

        val rejected = assertIs<KeyValidationResult.Rejected>(result)
        assertEquals("$.environment.medical_history", rejected.violation.path)
    }

    @Test
    fun permitsAggregateEnvironmentalFields() {
        val payload = buildJsonObject {
            put("air_temperature_c", 43.0)
            put("solar_radiation_w_m2", 950.0)
            put("observation_coverage", 0.95)
        }

        val result = ProhibitedKeyValidator.validate(payload)

        assertEquals(KeyValidationResult.Allowed, result)
    }
}
