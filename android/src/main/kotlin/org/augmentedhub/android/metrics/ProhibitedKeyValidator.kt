package org.augmentedhub.android.metrics

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import org.augmentedhub.metrics.KeyValidationResult
import org.augmentedhub.metrics.ProhibitedKeyViolation

object ProhibitedKeyValidator {
    /*
     * This set must be generated from the canonical shared dispatcher contract.
     * Do not independently edit this Android declaration after generation.
     *
     * The initial list reflects currently available project policy categories.
     * CI must compare generated Android tokens against the canonical contract.
     */
    val prohibitedKeyTokens: Set<String> = setOf(
        "person",
        "individual",
        "household",
        "identity",
        "name",
        "email",
        "phone",
        "address",
        "device",
        "macaddress",
        "bluetooth",
        "wifi",
        "trajectory",
        "locationhistory",
        "image",
        "audio",
        "face",
        "gait",
        "health",
        "medical",
        "neural",
        "biometric",
        "disability",
        "eligib",
    )

    fun validate(value: JsonElement): KeyValidationResult =
        validateNode(value = value, path = "$")

    fun normalizeKey(value: String): String =
        buildString(value.length) {
            value.forEach { character ->
                if (character.isLetterOrDigit()) {
                    append(character.lowercaseChar())
                }
            }
        }

    fun prohibitedKey(key: String): String? {
        val normalizedKey = normalizeKey(key)

        if (normalizedKey.isEmpty()) {
            return "non_string_or_empty_key"
        }

        return prohibitedKeyTokens.firstOrNull { token ->
            val normalizedToken = normalizeKey(token)
            normalizedToken.isNotEmpty() && normalizedKey.contains(normalizedToken)
        }
    }

    private fun validateNode(
        value: JsonElement,
        path: String,
    ): KeyValidationResult =
        when (value) {
            is JsonObject -> validateObject(value, path)
            is JsonArray -> validateArray(value, path)
            else -> KeyValidationResult.Allowed
        }

    private fun validateObject(
        value: JsonObject,
        path: String,
    ): KeyValidationResult {
        value.forEach { (key, nestedValue) ->
            val matchedToken = prohibitedKey(key)

            if (matchedToken != null) {
                return KeyValidationResult.Rejected(
                    ProhibitedKeyViolation(
                        path = "$path.$key",
                        normalizedKey = normalizeKey(key),
                        matchedToken = matchedToken,
                    ),
                )
            }

            when (val nestedResult = validateNode(nestedValue, "$path.$key")) {
                KeyValidationResult.Allowed -> Unit
                is KeyValidationResult.Rejected -> return nestedResult
            }
        }

        return KeyValidationResult.Allowed
    }

    private fun validateArray(
        value: JsonArray,
        path: String,
    ): KeyValidationResult {
        value.forEachIndexed { index, nestedValue ->
            when (val nestedResult = validateNode(nestedValue, "$path[$index]")) {
                KeyValidationResult.Allowed -> Unit
                is KeyValidationResult.Rejected -> return nestedResult
            }
        }

        return KeyValidationResult.Allowed
    }
}
