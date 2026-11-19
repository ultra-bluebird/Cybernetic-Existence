package org.augmentedhub.audit

import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardOpenOption
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.Signature
import java.time.Instant

private const val LABEL = "ORGANICHAIN-AUDIT-v1"

enum class AuditEventType {
    SESSION_ADMITTED,
    MESSAGE_ACCEPTED,
    MESSAGE_REJECTED,
    SESSION_REVOKED,
    SESSION_EXPIRED,
    ZEROIZATION_REPORTED,
    RECOVERY_REQUIRED,
    AUDIT_OVERFLOW
}

enum class RetentionClass {
    LOCAL_EPHEMERAL,
    LOCAL_RETAINED,
    HOLDER_EXPORTED
}

data class MinimalAuditReceipt(
    val schemaVersion: Int,
    val sequence: Long,
    val parentHeadHex: String,
    val sessionCommitmentHex: String,
    val sessionGeneration: Long,
    val eventType: AuditEventType,
    val reasonCode: String,
    val policyVersion: String,
    val retentionClass: RetentionClass,
    val recordedAt: Instant,
    val metadataCommitmentHex: String
)

data class SignedAuditReceipt(
    val receipt: MinimalAuditReceipt,
    val receiptHashHex: String,
    val signatureHex: String,
    val headHashHex: String
)

class OrganichainAuditVault(
    private val logPath: Path,
    private val signingKey: PrivateKey
) {
    private var headHash = genesisHead()
    private var nextSequence = 1L

    init {
        require(logPath.parent != null)
        Files.createDirectories(logPath.parent)
    }

    fun append(
        sessionCommitmentHex: String,
        sessionGeneration: Long,
        eventType: AuditEventType,
        reasonCode: String,
        policyVersion: String,
        retentionClass: RetentionClass,
        metadataCommitmentHex: String,
        recordedAt: Instant = Instant.now()
    ): SignedAuditReceipt {
        validateHex(sessionCommitmentHex, 64)
        validateHex(metadataCommitmentHex, 64)
        require(sessionGeneration > 0)
        require(reasonCode.matches(Regex("^[a-z0-9._-]{1,128}$")))
        require(policyVersion.matches(Regex("^[A-Za-z0-9._-]{1,128}$")))

        val receipt = MinimalAuditReceipt(
            schemaVersion = 1,
            sequence = nextSequence,
            parentHeadHex = headHash,
            sessionCommitmentHex = sessionCommitmentHex,
            sessionGeneration = sessionGeneration,
            eventType = eventType,
            reasonCode = reasonCode,
            policyVersion = policyVersion,
            retentionClass = retentionClass,
            recordedAt = recordedAt,
            metadataCommitmentHex = metadataCommitmentHex
        )

        val canonical = canonicalBytes(receipt)
        val receiptHash = sha256(canonical)
        val signature = sign(receiptHash)
        val newHead = sha256(
            bytes(LABEL) +
                hexToBytes(headHash) +
                receiptHash +
                signature
        )

        val signed = SignedAuditReceipt(
            receipt = receipt,
            receiptHashHex = toHex(receiptHash),
            signatureHex = toHex(signature),
            headHashHex = toHex(newHead)
        )

        Files.writeString(
            logPath,
            serializeLine(signed) + "\n",
            UTF_8,
            StandardOpenOption.CREATE,
            StandardOpenOption.APPEND
        )

        headHash = signed.headHashHex
        nextSequence += 1

        return signed
    }

    fun currentHead(): String = headHash

    private fun sign(
        message: ByteArray
    ): ByteArray {
        val signer = Signature.getInstance("Ed25519")
        signer.initSign(signingKey)
        signer.update(message)
        return signer.sign()
    }

    private fun canonicalBytes(
        receipt: MinimalAuditReceipt
    ): ByteArray {
        val text = listOf(
            LABEL,
            receipt.schemaVersion.toString(),
            receipt.sequence.toString(),
            receipt.parentHeadHex,
            receipt.sessionCommitmentHex,
            receipt.sessionGeneration.toString(),
            receipt.eventType.name,
            receipt.reasonCode,
            receipt.policyVersion,
            receipt.retentionClass.name,
            receipt.recordedAt.toString(),
            receipt.metadataCommitmentHex
        ).joinToString("|")

        return bytes(text)
    }

    private fun serializeLine(
        signed: SignedAuditReceipt
    ): String {
        val receipt = signed.receipt

        return listOf(
            "schema_version=${receipt.schemaVersion}",
            "sequence=${receipt.sequence}",
            "parent_head=${receipt.parentHeadHex}",
            "session_commitment=${receipt.sessionCommitmentHex}",
            "session_generation=${receipt.sessionGeneration}",
            "event_type=${receipt.eventType.name}",
            "reason_code=${receipt.reasonCode}",
            "policy_version=${receipt.policyVersion}",
            "retention_class=${receipt.retentionClass.name}",
            "recorded_at=${receipt.recordedAt}",
            "metadata_commitment=${receipt.metadataCommitmentHex}",
            "receipt_hash=${signed.receiptHashHex}",
            "signature=${signed.signatureHex}",
            "head_hash=${signed.headHashHex}"
        ).joinToString("\t")
    }

    private fun genesisHead(): String {
        return toHex(sha256(bytes("$LABEL:GENESIS")))
    }

    private fun validateHex(
        value: String,
        expectedLength: Int
    ) {
        require(value.length == expectedLength)
        require(value.matches(Regex("^[0-9a-f]+$")))
    }

    private fun sha256(
        value: ByteArray
    ): ByteArray {
        return MessageDigest.getInstance("SHA-256").digest(value)
    }

    private fun bytes(
        value: String
    ): ByteArray {
        return value.toByteArray(UTF_8)
    }

    private fun hexToBytes(
        value: String
    ): ByteArray {
        require(value.length % 2 == 0)

        return value.chunked(2)
            .map { it.toInt(16).toByte() }
            .toByteArray()
    }

    private fun toHex(
        value: ByteArray
    ): String {
        return value.joinToString("") { byte ->
            "%02x".format(byte.toInt() and 0xff)
        }
    }
}
