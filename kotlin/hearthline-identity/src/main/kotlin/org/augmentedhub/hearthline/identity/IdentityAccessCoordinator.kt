package org.augmentedhub.hearthline.identity

import java.time.Clock
import java.time.Instant

enum class IdentityAccessState {
    FULL_ACCESS,
    LIMITED_ACCESS,
    READ_ONLY_CONTROLLED,
    PROTECTIVE_ACCESS,
    CONTINUITY_AVAILABLE,
    CONTINUITY_ACTIVE,
    RESTORED
}

enum class IdentityCapability {
    VIEW_OWN_SETTINGS,
    VIEW_AVAILABLE_CONNECTION_HISTORY,
    VIEW_AVAILABLE_MESSAGES,
    PAUSE_ACTIVITY,
    STOP_FUTURE_SHARING,
    BLOCK_CONNECTION,
    SUBMIT_SAFETY_REPORT,
    VIEW_GENERIC_SECURITY_HISTORY,
    VIEW_GENERIC_CONTINUITY_GUIDANCE,
    END_CURRENT_SESSION,
    CLEAR_LOCAL_DATA,
    REQUEST_REVIEW,
    SAVE_LOCAL_DRAFT,
    SEND_MESSAGE,
    EXPRESS_INTEREST,
    EXPAND_DISCLOSURE_SCOPE,
    REVEAL_CONTACT_DETAILS,
    EXPORT_ACCOUNT_DATA,
    LINK_EXTERNAL_PROVIDER,
    ADD_AUTHENTICATOR,
    REMOVE_AUTHENTICATOR,
    CHANGE_SUPPORT_CONTACTS,
    CLOSE_ACCOUNT,
    MODIFY_PROMPT_POLICY,
    VIEW_DEFERRED_ITEMS
}

enum class DeviceSessionKind {
    PERSONAL_BOUND_DEVICE,
    SHARED_OR_TEMPORARY_SESSION,
    UNKNOWN_DEVICE_STATE
}

enum class PromptPace {
    QUIET,
    GENTLE,
    STANDARD,
    FULL,
    MANUAL_ONLY
}

data class PromptLoadView(
    val activePace: PromptPace,
    val quietMode: Boolean,
    val optionalPromptsShownToday: Int,
    val optionalPromptCap: Int,
    val deferredItemCount: Int,
    val recoveryAttributeUsed: Boolean = false,
    val healthAttributeUsed: Boolean = false,
    val behavioralInferenceUsed: Boolean = false,
    val matchingUseAllowed: Boolean = false,
    val rankingUseAllowed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

data class DeviceBindingView(
    val sessionKind: DeviceSessionKind,
    val deviceLabel: String?,
    val bindingActive: Boolean,
    val passiveFingerprintStored: Boolean = false,
    val crossSiteCorrelationAllowed: Boolean = false,
    val recipientVisibilityAllowed: Boolean = false,
    val matchingUseAllowed: Boolean = false,
    val lanternUseAllowed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

data class IdentityAccessRecord(
    val accountRef: String,
    val accessState: IdentityAccessState,
    val deviceRiskReported: Boolean,
    val continuityActive: Boolean,
    val updatedAt: Instant,
    val externalActionAuthorized: Boolean = false
)

data class IdentityAccessView(
    val accountRef: String,
    val accessState: IdentityAccessState,
    val capabilities: Set<IdentityCapability>,
    val userMessage: String,
    val promptPolicyEditable: Boolean,
    val deferredItemsVisible: Boolean,
    val sensitiveContentVisible: Boolean,
    val deviceLabelVisible: Boolean,
    val recoveryAttributeUsed: Boolean = false,
    val healthAttributeUsed: Boolean = false,
    val behavioralInferenceUsed: Boolean = false,
    val matchingUseAllowed: Boolean = false,
    val rankingUseAllowed: Boolean = false,
    val profileVisibilityUseAllowed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

class IdentityAccessCoordinator(
    private val clock: Clock
) {
    fun evaluate(
        identity: IdentityAccessRecord,
        device: DeviceBindingView,
        promptLoad: PromptLoadView,
        now: Instant = clock.instant()
    ): IdentityAccessView {
        require(identity.accountRef.isNotBlank()) {
            "accountRef must not be blank"
        }
        require(!identity.externalActionAuthorized) {
            "Identity access records cannot authorize external actions"
        }
        validateDevice(device)
        validatePromptLoad(promptLoad)

        val effectiveState = effectiveState(identity, device)
        val capabilities = capabilitiesFor(effectiveState, device.sessionKind)
        val sensitiveContentVisible = effectiveState in setOf(
            IdentityAccessState.FULL_ACCESS,
            IdentityAccessState.LIMITED_ACCESS,
            IdentityAccessState.READ_ONLY_CONTROLLED,
            IdentityAccessState.RESTORED
        ) && device.sessionKind == DeviceSessionKind.PERSONAL_BOUND_DEVICE

        val promptPolicyEditable = effectiveState !in setOf(
            IdentityAccessState.CONTINUITY_ACTIVE
        )

        val deferredItemsVisible = promptPolicyEditable
            && device.sessionKind != DeviceSessionKind.SHARED_OR_TEMPORARY_SESSION

        val deviceLabelVisible = device.sessionKind == DeviceSessionKind.PERSONAL_BOUND_DEVICE

        return IdentityAccessView(
            accountRef = identity.accountRef,
            accessState = effectiveState,
            capabilities = capabilities,
            userMessage = messageFor(effectiveState),
            promptPolicyEditable = promptPolicyEditable,
            deferredItemsVisible = deferredItemsVisible,
            sensitiveContentVisible = sensitiveContentVisible,
            deviceLabelVisible = deviceLabelVisible
        )
    }

    private fun effectiveState(
        identity: IdentityAccessRecord,
        device: DeviceBindingView
    ): IdentityAccessState {
        if (identity.deviceRiskReported
            || device.sessionKind == DeviceSessionKind.UNKNOWN_DEVICE_STATE
        ) {
            return IdentityAccessState.PROTECTIVE_ACCESS
        }

        if (identity.continuityActive) {
            return IdentityAccessState.CONTINUITY_ACTIVE
        }

        if (device.sessionKind == DeviceSessionKind.SHARED_OR_TEMPORARY_SESSION
            && identity.accessState == IdentityAccessState.READ_ONLY_CONTROLLED
        ) {
            return IdentityAccessState.PROTECTIVE_ACCESS
        }

        return identity.accessState
    }

    private fun capabilitiesFor(
        state: IdentityAccessState,
        sessionKind: DeviceSessionKind
    ): Set<IdentityCapability> {
        val universal = setOf(
            IdentityCapability.VIEW_OWN_SETTINGS,
            IdentityCapability.PAUSE_ACTIVITY,
            IdentityCapability.STOP_FUTURE_SHARING,
            IdentityCapability.BLOCK_CONNECTION,
            IdentityCapability.SUBMIT_SAFETY_REPORT,
            IdentityCapability.VIEW_GENERIC_SECURITY_HISTORY,
            IdentityCapability.VIEW_GENERIC_CONTINUITY_GUIDANCE,
            IdentityCapability.END_CURRENT_SESSION,
            IdentityCapability.CLEAR_LOCAL_DATA,
            IdentityCapability.REQUEST_REVIEW
        )

        return when (state) {
            IdentityAccessState.FULL_ACCESS,
            IdentityAccessState.RESTORED -> universal + setOf(
                IdentityCapability.VIEW_AVAILABLE_CONNECTION_HISTORY,
                IdentityCapability.VIEW_AVAILABLE_MESSAGES,
                IdentityCapability.SAVE_LOCAL_DRAFT,
                IdentityCapability.SEND_MESSAGE,
                IdentityCapability.EXPRESS_INTEREST,
                IdentityCapability.EXPAND_DISCLOSURE_SCOPE,
                IdentityCapability.REVEAL_CONTACT_DETAILS,
                IdentityCapability.EXPORT_ACCOUNT_DATA,
                IdentityCapability.LINK_EXTERNAL_PROVIDER,
                IdentityCapability.ADD_AUTHENTICATOR,
                IdentityCapability.REMOVE_AUTHENTICATOR,
                IdentityCapability.CHANGE_SUPPORT_CONTACTS,
                IdentityCapability.CLOSE_ACCOUNT,
                IdentityCapability.MODIFY_PROMPT_POLICY,
                IdentityCapability.VIEW_DEFERRED_ITEMS
            )

            IdentityAccessState.LIMITED_ACCESS -> universal + setOf(
                IdentityCapability.VIEW_AVAILABLE_CONNECTION_HISTORY,
                IdentityCapability.VIEW_AVAILABLE_MESSAGES,
                IdentityCapability.SAVE_LOCAL_DRAFT,
                IdentityCapability.MODIFY_PROMPT_POLICY,
                IdentityCapability.VIEW_DEFERRED_ITEMS
            )

            IdentityAccessState.READ_ONLY_CONTROLLED -> {
                if (sessionKind == DeviceSessionKind.PERSONAL_BOUND_DEVICE) {
                    universal + setOf(
                        IdentityCapability.VIEW_AVAILABLE_CONNECTION_HISTORY,
                        IdentityCapability.VIEW_AVAILABLE_MESSAGES,
                        IdentityCapability.SAVE_LOCAL_DRAFT,
                        IdentityCapability.MODIFY_PROMPT_POLICY,
                        IdentityCapability.VIEW_DEFERRED_ITEMS
                    )
                } else {
                    universal + setOf(
                        IdentityCapability.MODIFY_PROMPT_POLICY
                    )
                }
            }

            IdentityAccessState.PROTECTIVE_ACCESS,
            IdentityAccessState.CONTINUITY_AVAILABLE -> universal + setOf(
                IdentityCapability.MODIFY_PROMPT_POLICY
            )

            IdentityAccessState.CONTINUITY_ACTIVE -> universal
        }
    }

    private fun messageFor(state: IdentityAccessState): String {
        return when (state) {
            IdentityAccessState.FULL_ACCESS ->
                "Your account is ready for normal Hearthline use."

            IdentityAccessState.LIMITED_ACCESS ->
                "A secure sign-in check is needed before you can send messages or share anything new. You can still pause, block, review privacy choices, and change future sharing."

            IdentityAccessState.READ_ONLY_CONTROLLED ->
                "This session can be used to review your account and protect your privacy. Sending, sharing, exports, and new connections are paused until you sign in securely again."

            IdentityAccessState.PROTECTIVE_ACCESS ->
                "Because this device may no longer be fully under your control, private content is hidden here. You can still pause activity, change future sharing, block, report, and start account continuity."

            IdentityAccessState.CONTINUITY_AVAILABLE ->
                "Your account is still here. A secure sign-in method needs attention before normal access can continue. You can protect your privacy now and choose a secure way to continue."

            IdentityAccessState.CONTINUITY_ACTIVE ->
                "Your account-continuity steps are in progress. Your privacy, pause, block, report, and account-safety controls remain available."

            IdentityAccessState.RESTORED ->
                "Your secure sign-in method is ready. You are back in control of your Hearthline account."
        }
    }

    private fun validateDevice(device: DeviceBindingView) {
        require(!device.passiveFingerprintStored) {
            "Passive device fingerprint storage is prohibited"
        }
        require(!device.crossSiteCorrelationAllowed) {
            "Cross-site device correlation is prohibited"
        }
        require(!device.recipientVisibilityAllowed) {
            "Recipient visibility of device state is prohibited"
        }
        require(!device.matchingUseAllowed) {
            "Matching use of device state is prohibited"
        }
        require(!device.lanternUseAllowed) {
            "Lantern use of device group state is prohibited"
        }
        require(!device.externalActionAuthorized) {
            "Device binding state cannot authorize external actions"
        }
    }

    private fun validatePromptLoad(promptLoad: PromptLoadView) {
        require(promptLoad.optionalPromptsShownToday >= 0) {
            "optionalPromptsShownToday must be non-negative"
        }
        require(promptLoad.optionalPromptCap in 0..8) {
            "optionalPromptCap must be between 0 and 8"
        }
        require(promptLoad.deferredItemCount >= 0) {
            "deferredItemCount must be non-negative"
        }
        require(!promptLoad.recoveryAttributeUsed) {
            "Prompt policy cannot use recovery attributes"
        }
        require(!promptLoad.healthAttributeUsed) {
            "Prompt policy cannot use health attributes"
        }
        require(!promptLoad.behavioralInferenceUsed) {
            "Prompt policy cannot use behavioral inference"
        }
        require(!promptLoad.matchingUseAllowed) {
            "Prompt policy cannot be used for matching"
        }
        require(!promptLoad.rankingUseAllowed) {
            "Prompt policy cannot be used for ranking"
        }
        require(!promptLoad.externalActionAuthorized) {
            "Prompt policy cannot authorize external actions"
        }
    }
}
