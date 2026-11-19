package org.augmentedhub.accessibility

enum class AssistancePanelState {
    IDLE,
    AWAITING_INPUT,
    PROCESSING,
    OUTPUT_READY,
    OFFLINE_NOTICE
}

enum class InputMode {
    LARGE_TEXT_TOUCH,
    VOICE,
    TACTILE,
    KEYBOARD,
    SWITCH_ACCESS,
    ASSISTIVE_TECHNOLOGY
}

enum class OutputMode {
    LARGE_TEXT_VISUAL,
    HIGH_CONTRAST_VISUAL,
    SPEECH,
    TACTILE,
    EXPORTABLE_TEXT
}

enum class PanelEvent {
    BEGIN_INTERACTION,
    INPUT_RECEIVED,
    PROCESSING_COMPLETED,
    NETWORK_UNAVAILABLE,
    NETWORK_RESTORED,
    RETURN_TO_IDLE,
    REPEAT_OUTPUT,
    REQUEST_HELP
}

data class AccessibilityCapabilities(
    val enabledInputs: Set<InputMode>,
    val enabledOutputs: Set<OutputMode>,
    val localHelpAvailable: Boolean,
    val offlineInformationAvailable: Boolean,
    val correctionPathAvailable: Boolean
) {
    fun validates(): Boolean {
        return enabledInputs.isNotEmpty() &&
            enabledOutputs.isNotEmpty() &&
            localHelpAvailable &&
            offlineInformationAvailable &&
            correctionPathAvailable
    }
}

data class PanelSnapshot(
    val state: AssistancePanelState,
    val networkAvailable: Boolean,
    val accessibility: AccessibilityCapabilities,
    val explanation: String
)

class AssistancePanelStateMachine(
    private val accessibility: AccessibilityCapabilities
) {
    private var state: AssistancePanelState = AssistancePanelState.IDLE
    private var networkAvailable: Boolean = true

    init {
        require(accessibility.validates()) {
            "The assistance panel requires input output help offline and correction capabilities"
        }
    }

    fun snapshot(): PanelSnapshot {
        return PanelSnapshot(
            state = state,
            networkAvailable = networkAvailable,
            accessibility = accessibility,
            explanation = explanationFor(state)
        )
    }

    fun transition(event: PanelEvent): PanelSnapshot {
        state = when (event) {
            PanelEvent.NETWORK_UNAVAILABLE -> {
                networkAvailable = false
                AssistancePanelState.OFFLINE_NOTICE
            }

            PanelEvent.NETWORK_RESTORED -> {
                networkAvailable = true
                AssistancePanelState.IDLE
            }

            PanelEvent.BEGIN_INTERACTION -> {
                if (networkAvailable) AssistancePanelState.AWAITING_INPUT
                else AssistancePanelState.OFFLINE_NOTICE
            }

            PanelEvent.INPUT_RECEIVED -> {
                when (state) {
                    AssistancePanelState.AWAITING_INPUT -> AssistancePanelState.PROCESSING
                    AssistancePanelState.OFFLINE_NOTICE -> AssistancePanelState.OFFLINE_NOTICE
                    else -> state
                }
            }

            PanelEvent.PROCESSING_COMPLETED -> {
                when (state) {
                    AssistancePanelState.PROCESSING -> AssistancePanelState.OUTPUT_READY
                    else -> state
                }
            }

            PanelEvent.REPEAT_OUTPUT -> {
                when (state) {
                    AssistancePanelState.OUTPUT_READY -> AssistancePanelState.OUTPUT_READY
                    else -> state
                }
            }

            PanelEvent.REQUEST_HELP -> {
                if (networkAvailable) AssistancePanelState.AWAITING_INPUT
                else AssistancePanelState.OFFLINE_NOTICE
            }

            PanelEvent.RETURN_TO_IDLE -> AssistancePanelState.IDLE
        }

        return snapshot()
    }

    private fun explanationFor(currentState: AssistancePanelState): String {
        return when (currentState) {
            AssistancePanelState.IDLE ->
                "Ready. You may begin using a supported input method."

            AssistancePanelState.AWAITING_INPUT ->
                "Waiting for input. Voice, tactile, large-text, keyboard, switch, and compatible assistive-technology input may be available."

            AssistancePanelState.PROCESSING ->
                "Processing your request locally when possible. You may request help or return to the start screen."

            AssistancePanelState.OUTPUT_READY ->
                "Your result is ready. You may read it in large text, hear it, access tactile output where available, or export text."

            AssistancePanelState.OFFLINE_NOTICE ->
                "Network service is unavailable. Local information, accessible help, and correction options remain available. No continuous connection is required for basic assistance."
        }
    }
}
