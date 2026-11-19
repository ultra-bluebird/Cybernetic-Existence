package augmentedhub.lighting

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

enum class MotionState {
    NONE,
    COARSE_PRESENCE,
    ACTIVE_APPROACH
}

enum class SensorHealth {
    HEALTHY,
    STALE,
    FAULT
}

enum class EcologicalMode {
    ROUTINE,
    ECOLOGICAL_SENSITIVITY,
    WEATHER_VISIBILITY,
    EMERGENCY_SAFETY
}

data class LightingZonePolicy(
    val accessibilityIlluminanceFloorLux: Double,
    val safetyIlluminanceFloorLux: Double,
    val maximumIlluminanceLux: Double,
    val maximumFadeRateLuxPerSecond: Double,
    val maximumCctRateKelvinPerSecond: Double,
    val ecologicalMinimumCctKelvin: Double,
    val ecologicalMaximumCctKelvin: Double,
    val sensorFaultUsesSafeBaseline: Boolean,
    val cameraCaptureEnabled: Boolean,
    val persistentDeviceIdentifierStored: Boolean,
    val motionTrajectoryStored: Boolean,
    val gaitOrIdentityInferenceEnabled: Boolean
) {
    fun validate(): LightingZonePolicy {
        require(accessibilityIlluminanceFloorLux > 0.0) {
            "Accessibility illuminance floor must be positive."
        }
        require(safetyIlluminanceFloorLux > 0.0) {
            "Safety illuminance floor must be positive."
        }
        require(maximumIlluminanceLux >= max(accessibilityIlluminanceFloorLux, safetyIlluminanceFloorLux)) {
            "Maximum illuminance must not be below the required floor."
        }
        require(maximumFadeRateLuxPerSecond > 0.0) {
            "Maximum fade rate must be positive."
        }
        require(maximumCctRateKelvinPerSecond > 0.0) {
            "Maximum CCT rate must be positive."
        }
        require(ecologicalMinimumCctKelvin in 1000.0..6500.0) {
            "Ecological minimum CCT must be within supported range."
        }
        require(ecologicalMaximumCctKelvin in ecologicalMinimumCctKelvin..6500.0) {
            "Ecological maximum CCT must be within supported range."
        }
        require(sensorFaultUsesSafeBaseline) {
            "Sensor faults must use a safe baseline."
        }
        require(!cameraCaptureEnabled) {
            "Camera capture is prohibited."
        }
        require(!persistentDeviceIdentifierStored) {
            "Persistent device identifiers are prohibited."
        }
        require(!motionTrajectoryStored) {
            "Motion trajectories are prohibited."
        }
        require(!gaitOrIdentityInferenceEnabled) {
            "Gait and identity inference are prohibited."
        }
        return this
    }
}

data class LightingInput(
    val currentIlluminanceLux: Double,
    val currentCctKelvin: Double,
    val scheduledIlluminanceLux: Double,
    val scheduledCctKelvin: Double,
    val motionState: MotionState,
    val motionBoostLux: Double,
    val ecologicalReductionLux: Double,
    val ecologicalCctKelvin: Double,
    val sensorHealth: SensorHealth,
    val ecologicalMode: EcologicalMode,
    val deltaSeconds: Double
)

data class LightingCommand(
    val targetIlluminanceLux: Double,
    val nextIlluminanceLux: Double,
    val nextCctKelvin: Double,
    val routeSafetyPreserved: Boolean,
    val sensorFallbackActive: Boolean,
    val identityDataStored: Boolean,
    val motionTrajectoryStored: Boolean,
    val automaticEnforcementAuthorized: Boolean,
    val explanation: String
)

object AdaptiveLightingZoneController {
    fun calculate(
        policy: LightingZonePolicy,
        input: LightingInput
    ): LightingCommand {
        policy.validate()
        validateInput(input)

        val requiredFloor = max(
            policy.accessibilityIlluminanceFloorLux,
            policy.safetyIlluminanceFloorLux
        )

        val sensorFallback = input.sensorHealth != SensorHealth.HEALTHY

        val requestedIlluminance = if (sensorFallback) {
            max(requiredFloor, input.scheduledIlluminanceLux)
        } else {
            input.scheduledIlluminanceLux +
                motionBoost(input.motionState, input.motionBoostLux) -
                input.ecologicalReductionLux
        }

        val targetIlluminance = requestedIlluminance.coerceIn(
            requiredFloor,
            policy.maximumIlluminanceLux
        )

        val maxIlluminanceStep =
            policy.maximumFadeRateLuxPerSecond * input.deltaSeconds

        val nextIlluminance = ramp(
            input.currentIlluminanceLux,
            targetIlluminance,
            maxIlluminanceStep
        )

        val requestedCct = when {
            input.ecologicalMode == EcologicalMode.ECOLOGICAL_SENSITIVITY ->
                input.ecologicalCctKelvin.coerceIn(
                    policy.ecologicalMinimumCctKelvin,
                    policy.ecologicalMaximumCctKelvin
                )
            else -> input.scheduledCctKelvin
        }

        val maxCctStep = policy.maximumCctRateKelvinPerSecond * input.deltaSeconds
        val nextCct = ramp(
            input.currentCctKelvin,
            requestedCct,
            maxCctStep
        )

        val explanation = when {
            sensorFallback ->
                "Sensor health is degraded; the controller uses the approved safe baseline without ecological dimming."
            input.ecologicalMode == EcologicalMode.ECOLOGICAL_SENSITIVITY ->
                "Ecological spectral and illuminance preferences were applied without reducing below the required public-route floor."
            input.motionState != MotionState.NONE ->
                "A coarse non-identifying motion state triggered a bounded, rate-limited route illumination boost."
            else ->
                "Scheduled lighting was applied within approved safety, accessibility, and transition bounds."
        }

        return LightingCommand(
            targetIlluminanceLux = targetIlluminance,
            nextIlluminanceLux = nextIlluminance,
            nextCctKelvin = nextCct,
            routeSafetyPreserved = nextIlluminance >= requiredFloor,
            sensorFallbackActive = sensorFallback,
            identityDataStored = false,
            motionTrajectoryStored = false,
            automaticEnforcementAuthorized = false,
            explanation = explanation
        )
    }

    private fun motionBoost(
        motionState: MotionState,
        configuredBoostLux: Double
    ): Double {
        return when (motionState) {
            MotionState.NONE -> 0.0
            MotionState.COARSE_PRESENCE -> configuredBoostLux * 0.5
            MotionState.ACTIVE_APPROACH -> configuredBoostLux
        }
    }

    private fun ramp(
        current: Double,
        target: Double,
        maximumStep: Double
    ): Double {
        val difference = target - current
        val boundedDifference = difference.coerceIn(-maximumStep, maximumStep)
        return current + boundedDifference
    }

    private fun validateInput(input: LightingInput) {
        require(input.currentIlluminanceLux >= 0.0 && input.currentIlluminanceLux.isFinite()) {
            "currentIlluminanceLux must be finite and non-negative."
        }
        require(input.currentCctKelvin in 1000.0..6500.0) {
            "currentCctKelvin must be within supported range."
        }
        require(input.scheduledIlluminanceLux >= 0.0 && input.scheduledIlluminanceLux.isFinite()) {
            "scheduledIlluminanceLux must be finite and non-negative."
        }
        require(input.scheduledCctKelvin in 1000.0..6500.0) {
            "scheduledCctKelvin must be within supported range."
        }
        require(input.motionBoostLux >= 0.0 && input.motionBoostLux.isFinite()) {
            "motionBoostLux must be finite and non-negative."
        }
        require(input.ecologicalReductionLux >= 0.0 && input.ecologicalReductionLux.isFinite()) {
            "ecologicalReductionLux must be finite and non-negative."
        }
        require(input.ecologicalCctKelvin in 1000.0..6500.0) {
            "ecologicalCctKelvin must be within supported range."
        }
        require(input.deltaSeconds > 0.0 && input.deltaSeconds <= 3600.0) {
            "deltaSeconds must be greater than zero and no greater than one hour."
        }
    }
}
