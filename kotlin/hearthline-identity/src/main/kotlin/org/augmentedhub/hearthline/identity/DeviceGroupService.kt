package org.augmentedhub.hearthline.identity

import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.UUID

enum class DeviceBindingState {
    BINDING_AVAILABLE,
    PAIRING_REQUESTED,
    PAIRING_CONFIRMED,
    DEVICE_ACTIVE,
    DEVICE_SIGNED_OUT,
    DEVICE_REVOKED,
    DEVICE_EXPIRED
}

data class DevicePairingRequest(
    val pairingRef: String,
    val accountRef: String,
    val expiresAt: Instant,
    val usedAt: Instant? = null,
    val externalActionAuthorized: Boolean = false
)

data class DeviceBinding(
    val deviceBindingRef: String,
    val accountRef: String,
    val deviceGroupRef: String,
    val userEditableLabel: String,
    val state: DeviceBindingState,
    val createdAt: Instant,
    val updatedAt: Instant,
    val lastAuthenticatedAt: Instant? = null,
    val sessionRevokedAt: Instant? = null,
    val expiresAt: Instant? = null,
    val passiveFingerprintStored: Boolean = false,
    val crossSiteCorrelationAllowed: Boolean = false,
    val recipientVisibilityAllowed: Boolean = false,
    val matchingUseAllowed: Boolean = false,
    val lanternUseAllowed: Boolean = false,
    val analyticsPersonLevelUseAllowed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

class DeviceGroupService(
    private val clock: Clock,
    private val pairingLifetime: Duration = Duration.ofMinutes(5)
) {
    fun beginPairing(
        accountRef: String,
        now: Instant = clock.instant()
    ): DevicePairingRequest {
        require(accountRef.isNotBlank()) {
            "accountRef must not be blank"
        }
        require(!pairingLifetime.isNegative && !pairingLifetime.isZero) {
            "pairingLifetime must be positive"
        }

        return DevicePairingRequest(
            pairingRef = opaqueReference(),
            accountRef = accountRef,
            expiresAt = now.plus(pairingLifetime)
        )
    }

    fun confirmPairing(
        pairing: DevicePairingRequest,
        accountRef: String,
        now: Instant = clock.instant()
    ): DevicePairingRequest {
        require(pairing.accountRef == accountRef) {
            "Pairing request does not belong to account"
        }
        require(pairing.usedAt == null) {
            "Pairing request has already been used"
        }
        require(pairing.expiresAt.isAfter(now)) {
            "Pairing request has expired"
        }

        return pairing.copy(usedAt = now)
    }

    fun activateBinding(
        accountRef: String,
        deviceGroupRef: String,
        userEditableLabel: String,
        now: Instant = clock.instant()
    ): DeviceBinding {
        require(accountRef.isNotBlank()) {
            "accountRef must not be blank"
        }
        require(deviceGroupRef.isNotBlank()) {
            "deviceGroupRef must not be blank"
        }
        require(userEditableLabel.isNotBlank()) {
            "userEditableLabel must not be blank"
        }
        require(userEditableLabel.length <= 64) {
            "userEditableLabel must not exceed 64 characters"
        }

        return DeviceBinding(
            deviceBindingRef = opaqueReference(),
            accountRef = accountRef,
            deviceGroupRef = deviceGroupRef,
            userEditableLabel = userEditableLabel.trim(),
            state = DeviceBindingState.DEVICE_ACTIVE,
            createdAt = now,
            updatedAt = now,
            lastAuthenticatedAt = now
        )
    }

    fun signOutDevice(
        binding: DeviceBinding,
        accountRef: String,
        now: Instant = clock.instant()
    ): DeviceBinding {
        require(binding.accountRef == accountRef) {
            "Device binding does not belong to account"
        }

        return binding.copy(
            state = DeviceBindingState.DEVICE_SIGNED_OUT,
            updatedAt = now,
            sessionRevokedAt = now
        )
    }

    fun revokeDevice(
        binding: DeviceBinding,
        accountRef: String,
        now: Instant = clock.instant()
    ): DeviceBinding {
        require(binding.accountRef == accountRef) {
            "Device binding does not belong to account"
        }

        return binding.copy(
            state = DeviceBindingState.DEVICE_REVOKED,
            updatedAt = now,
            sessionRevokedAt = now
        )
    }

    fun validateBinding(binding: DeviceBinding) {
        require(!binding.passiveFingerprintStored) {
            "Passive device fingerprint storage is prohibited"
        }
        require(!binding.crossSiteCorrelationAllowed) {
            "Cross-site correlation is prohibited"
        }
        require(!binding.recipientVisibilityAllowed) {
            "Recipient visibility is prohibited"
        }
        require(!binding.matchingUseAllowed) {
            "Matching use is prohibited"
        }
        require(!binding.lanternUseAllowed) {
            "Lantern use is prohibited"
        }
        require(!binding.analyticsPersonLevelUseAllowed) {
            "Person-level analytics use is prohibited"
        }
        require(!binding.externalActionAuthorized) {
            "Device binding cannot authorize external actions"
        }
    }

    private fun opaqueReference(): String {
        return UUID.randomUUID().toString().replace("-", "")
    }
}
