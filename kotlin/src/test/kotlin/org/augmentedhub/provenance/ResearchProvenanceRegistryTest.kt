package org.augmentedhub.provenance

import java.security.MessageDigest
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ResearchProvenanceRegistryTest {
    private fun sha384(value: String): String =
        MessageDigest.getInstance("SHA-384")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { byte -> "%02x".format(byte) }

    @Test
    fun appendOnlyRecordsVerify() {
        val registry = ResearchProvenanceRegistry(::sha384)

        registry.append(
            createdAt = Instant.parse("2026-09-06T07:27:00Z"),
            artifactClass = ArtifactClass.FORMAL_SPECIFICATION,
            revision = "1.0.0",
            contentDigest = "a".repeat(96),
            sourceReference = "local:ambient-light-corridor-policy",
            classification = "private-research",
            reviewStatus = ReviewStatus.HOST_REVIEWED,
            purpose = "document advisory shade-routing logic"
        )

        registry.append(
            createdAt = Instant.parse("2026-09-06T07:28:00Z"),
            artifactClass = ArtifactClass.SOFTWARE_TEST,
            revision = "1.0.0",
            contentDigest = "b".repeat(96),
            sourceReference = "local:corridor-validator-test",
            classification = "private-research",
            reviewStatus = ReviewStatus.TECHNICAL_REVIEWED,
            purpose = "verify finite input and range validation"
        )

        assertEquals(emptyList(), registry.verify())
        assertEquals(2, registry.snapshot().size)
        assertTrue(registry.snapshot().last().predecessorDigest != null)
    }
}
