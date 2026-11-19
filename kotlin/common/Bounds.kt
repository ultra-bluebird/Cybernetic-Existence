package augmentedhub.common

import java.util.ArrayDeque
import java.util.IdentityHashMap

/**
 * Proposed default payload limits.
 *
 * These bounds apply to supplied data, not total JVM memory usage.
 * Validate before copying, encoding, sorting, or recursive processing.
 *
 * Root depth is zero. Each nested container edge adds one.
 */
object Bounds {
    const val MAX_STRING_UTF16_UNITS = 4096
    const val MAX_COLLECTION_ELEMENTS = 256
    const val MAX_BYTE_ARRAY_BYTES = 16 * 1024 * 1024
    const val MAX_NESTING_DEPTH = 8

    const val MAX_VISITED_NODES = 4096
    const val MAX_TOTAL_UTF16_UNITS = 65_536L
    const val MAX_TOTAL_CONTENT_BYTES = 16L * 1024L * 1024L

    const val PROFILE_VERSION = "1"

    private class Budget {
        var nodes = 0
        var utf16Units = 0L
        var contentBytes = 0L
    }

    private sealed class Work {
        class Visit(val value: Any?, val depth: Int) : Work()
        class Leave(val container: Any) : Work()
    }

    private fun rejected(
        summary: String
    ): CommonResult<Unit> = CommonResult(
        ResultState.INVALID_INPUT,
        CommonCode.INPUT_CONTRACT_VIOLATION,
        summary
    )

    private fun accepted(): CommonResult<Unit> = CommonResult(
        ResultState.DECLARED_CHECKS_MET,
        CommonCode.DECLARED_LOCAL_CHECKS,
        "The supplied data meets the default bounds profile."
    )

    /**
     * Counts strict UTF-8 length without allocating encoded bytes.
     * Rejects malformed UTF-16; does not normalize or strip valid text.
     */
    private fun utf8Length(
        length: Int,
        charAt: (Int) -> Char
    ): Long? {
        var index = 0
        var bytes = 0L

        while (index < length) {
            val c = charAt(index)
            when {
                c.code <= 0x7f -> {
                    bytes += 1
                    index++
                }
                c.code <= 0x7ff -> {
                    bytes += 2
                    index++
                }
                Character.isHighSurrogate(c) -> {
                    if (index + 1 >= length ||
                        !Character.isLowSurrogate(charAt(index + 1))
                    ) return null
                    bytes += 4
                    index += 2
                }
                Character.isLowSurrogate(c) -> return null
                else -> {
                    bytes += 3
                    index++
                }
            }
        }

        return bytes
    }

    private fun addText(
        length: Int,
        charAt: (Int) -> Char,
        budget: Budget
    ): Boolean {
        if (length > MAX_STRING_UTF16_UNITS) return false
        val bytes = utf8Length(length, charAt) ?: return false

        if (length.toLong() >
            MAX_TOTAL_UTF16_UNITS - budget.utf16Units
        ) return false

        if (bytes > MAX_TOTAL_CONTENT_BYTES - budget.contentBytes) {
            return false
        }

        budget.utf16Units += length
        budget.contentBytes += bytes
        return true
    }

    fun checkString(value: String): CommonResult<Unit> {
        val budget = Budget()
        return if (addText(value.length, { value[it] }, budget))
            accepted()
        else rejected(
            "The text exceeds a bound or contains malformed UTF-16."
        )
    }

    fun checkByteArray(value: ByteArray): CommonResult<Unit> =
        if (value.size <= MAX_BYTE_ARRAY_BYTES) accepted()
        else rejected("The byte array exceeds the default bound.")

    /**
     * Supported payload types:
     * null, Boolean, Byte, Short, Int, Long, finite Float/Double,
     * String, CharArray, ByteArray, List, Map<String, *>, Array<*>.
     *
     * Custom models should expose a bounded validation projection.
     * Arbitrary object reflection or executable deserialization is not used.
     *
     * Caller must not mutate the payload during validation. Use ordinary
     * local containers, not hostile custom collection implementations.
     */
    fun checkPayload(root: Any?): CommonResult<Unit> {
        val budget = Budget()
        val work = ArrayDeque<Work>()
        val activeContainers = IdentityHashMap<Any, Boolean>()
        work.addLast(Work.Visit(root, 0))

        try {
            while (work.isNotEmpty()) {
                when (val item = work.removeLast()) {
                    is Work.Leave -> {
                        activeContainers.remove(item.container)
                    }

                    is Work.Visit -> {
                        budget.nodes++
                        if (budget.nodes > MAX_VISITED_NODES ||
                            item.depth > MAX_NESTING_DEPTH
                        ) {
                            return rejected(
                                "The payload exceeds node or nesting limits."
                            )
                        }

                        val value = item.value
                        when (value) {
                            null, is Boolean, is Byte, is Short,
                            is Int, is Long -> Unit

                            is Float -> if (!value.isFinite()) {
                                return rejected(
                                    "The payload contains a nonfinite number."
                                )
                            }

                            is Double -> if (!value.isFinite()) {
                                return rejected(
                                    "The payload contains a nonfinite number."
                                )
                            }

                            is String -> if (!addText(
                                value.length, { value[it] }, budget
                            )) {
                                return rejected(
                                    "The payload exceeds a text bound or " +
                                        "contains malformed UTF-16."
                                )
                            }

                            is CharArray -> if (!addText(
                                value.size, { value[it] }, budget
                            )) {
                                return rejected(
                                    "The character buffer violates text bounds."
                                )
                            }

                            is ByteArray -> {
                                if (value.size > MAX_BYTE_ARRAY_BYTES ||
                                    value.size.toLong() >
                                        MAX_TOTAL_CONTENT_BYTES -
                                            budget.contentBytes
                                ) {
                                    return rejected(
                                        "The payload exceeds byte-content bounds."
                                    )
                                }
                                budget.contentBytes += value.size
                            }

                            is List<*> -> {
                                if (value.size > MAX_COLLECTION_ELEMENTS) {
                                    return rejected(
                                        "A list exceeds the element bound."
                                    )
                                }
                                if (activeContainers.containsKey(value)) {
                                    return rejected(
                                        "A cyclic container is not supported."
                                    )
                                }
                                activeContainers[value] = true
                                work.addLast(Work.Leave(value))
                                for (index in value.indices.reversed()) {
                                    work.addLast(
                                        Work.Visit(value[index], item.depth + 1)
                                    )
                                }
                            }

                            is Array<*> -> {
                                if (value.size > MAX_COLLECTION_ELEMENTS) {
                                    return rejected(
                                        "An array exceeds the element bound."
                                    )
                                }
                                if (activeContainers.containsKey(value)) {
                                    return rejected(
                                        "A cyclic container is not supported."
                                    )
                                }
                                activeContainers[value] = true
                                work.addLast(Work.Leave(value))
                                for (index in value.indices.reversed()) {
                                    work.addLast(
                                        Work.Visit(value[index], item.depth + 1)
                                    )
                                }
                            }

                            is Map<*, *> -> {
                                if (value.size > MAX_COLLECTION_ELEMENTS) {
                                    return rejected(
                                        "A map exceeds the entry bound."
                                    )
                                }
                                if (activeContainers.containsKey(value)) {
                                    return rejected(
                                        "A cyclic container is not supported."
                                    )
                                }

                                activeContainers[value] = true
                                work.addLast(Work.Leave(value))

                                for ((key, child) in value) {
                                    if (key !is String) {
                                        return rejected(
                                            "Map keys must be strings."
                                        )
                                    }
                                    work.addLast(
                                        Work.Visit(child, item.depth + 1)
                                    )
                                    work.addLast(
                                        Work.Visit(key, item.depth + 1)
                                    )
                                }
                            }

                            else -> return rejected(
                                "The payload contains an unsupported type."
                            )
                        }
                    }
                }
            }
        } catch (_: Exception) {
            return CommonResult(
                ResultState.NOT_ESTABLISHED,
                CommonCode.EVIDENCE_UNAVAILABLE,
                "The payload could not be safely traversed."
            )
        }

        return accepted()
    }
}
