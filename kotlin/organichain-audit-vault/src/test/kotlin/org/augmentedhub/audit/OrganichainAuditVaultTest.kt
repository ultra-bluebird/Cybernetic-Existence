package org.augmentedhub.audit

import java.nio.file.Files
import java.security.KeyPairGenerator
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class OrganichainAuditVaultTest {
    @Test
    fun appendsMinimalSignedReceiptsWithoutRawPayload() {
        val directory = Files.createTempDirectory("organichain-audit-test")
        val logPath = directory.resolve("audit.log")
        val keyPair = KeyPairGenerator.getInstance("Ed25519").generateKeyPair()

        val vault = OrganichainAuditVault(
            logPath = logPath,
            signingKey = keyPair.private
        )

        val first = vault.append(
            sessionCommitmentHex = "11".repeat(32),
            sessionGeneration = 1,
            eventType = AuditEventType.MESSAGE_REJECTED,
            reasonCode = "schema_invalid",
            policyVersion = "v1",
            retentionClass = RetentionClass.LOCAL_RETAINED,
            metadataCommitmentHex = "22".repeat(32)
        )

        val second = vault.append(
            sessionCommitmentHex = "33".repeat(32),
            sessionGeneration = 2,
            eventType = AuditEventType.SESSION_EXPIRED,
            reasonCode = "lease_expired",
            policyVersion = "v1",
            retentionClass = RetentionClass.LOCAL_RETAINED,
            metadataCommitmentHex = "44".repeat(32)
        )

        val content = Files.readString(logPath)

        assertEquals(1L, first.receipt.sequence)
        assertEquals(2L, second.receipt.sequence)
        assertNotEquals(first.headHashHex, second.headHashHex)
        assertEquals(second.headHashHex, vault.currentHead())
        assertTrue(content.contains("reason_code=schema_invalid"))
        assertTrue(content.contains("reason_code=lease_expired"))
        assertFalse(content.contains("raw_payload"))
        assertFalse(content.contains("session_key"))
        assertFalse(content.contains("capability_token"))
    }
}
