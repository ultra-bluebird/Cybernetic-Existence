use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

/// DutyCycleConfig: Configuration for nanoswarm duty-cycle scheduling.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DutyCycleConfig {
    /// Maximum continuous duty duration in seconds.
    pub max_continuous_seconds: u64,
    /// Minimum cooldown duration in seconds between duty periods.
    pub min_cooldown_seconds: u64,
    /// Maximum duty fraction [0.0, 1.0] for any rolling time window.
    pub max_duty_fraction: f32,
    /// Rolling window duration for duty fraction calculation in seconds.
    pub rolling_window_seconds: u64,
}

/// DutyCycleState: Tracks current and historical duty-cycle metrics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DutyCycleState {
    /// Timestamp of last state update.
    pub last_updated: DateTime<Utc>,
    /// Current duty state: active or cooling.
    pub is_active: bool,
    /// Seconds of continuous duty in current active period.
    pub continuous_active_seconds: u64,
    /// Seconds of cooldown in current inactive period.
    pub continuous_cooldown_seconds: u64,
    /// Duty fraction over the rolling window [0.0, 1.0].
    pub rolling_duty_fraction: f32,
    /// Total duty seconds in the current rolling window.
    pub duty_seconds_in_window: u64,
}

/// DutyScheduler: Enforces duty-cycle constraints for nanoswarm operations.
pub struct DutyScheduler {
    config: DutyCycleConfig,
    state: DutyCycleState,
}

impl DutyScheduler {
    /// Create a new scheduler with the given configuration and initial state.
    pub fn new(config: DutyCycleConfig, initial_state: DutyCycleState) -> Self {
        Self {
            config,
            state: initial_state,
        }
    }

    /// Check if a new duty period can be started given current state.
    pub fn can_start_duty(&self) -> bool {
        if self.state.is_active {
            return false;
        }
        if self.state.continuous_cooldown_seconds < self.config.min_cooldown_seconds {
            return false;
        }
        if self.state.rolling_duty_fraction >= self.config.max_duty_fraction {
            return false;
        }
        true
    }

    /// Check if an active duty period must be paused given current state.
    pub fn must_pause_duty(&self) -> bool {
        if !self.state.is_active {
            return false;
        }
        if self.state.continuous_active_seconds >= self.config.max_continuous_seconds {
            return true;
        }
        if self.state.rolling_duty_fraction >= self.config.max_duty_fraction {
            return true;
        }
        false
    }

    /// Update the scheduler state with a new timestamp and duty activity.
    pub fn update(&mut self, now: DateTime<Utc>, was_active: bool) {
        let elapsed = (now - self.state.last_updated).num_seconds().max(0) as u64;
        
        if was_active {
            if self.state.is_active {
                self.state.continuous_active_seconds += elapsed;
                self.state.duty_seconds_in_window += elapsed;
            } else {
                self.state.is_active = true;
                self.state.continuous_active_seconds = elapsed;
                self.state.continuous_cooldown_seconds = 0;
                self.state.duty_seconds_in_window += elapsed;
            }
        } else {
            if !self.state.is_active {
                self.state.continuous_cooldown_seconds += elapsed;
            } else {
                self.state.is_active = false;
                self.state.continuous_cooldown_seconds = elapsed;
                self.state.continuous_active_seconds = 0;
            }
        }

        // Update rolling window duty fraction
        let window_seconds = self.config.rolling_window_seconds;
        let effective_window = self.state.duty_seconds_in_window.min(window_seconds);
        self.state.rolling_duty_fraction = effective_window as f32 / window_seconds as f32;
        
        // Decay duty seconds in window if beyond rolling window
        if self.state.duty_seconds_in_window > window_seconds {
            self.state.duty_seconds_in_window = window_seconds;
        }

        self.state.last_updated = now;
    }

    /// Get the current duty-cycle state.
    pub fn state(&self) -> &DutyCycleState {
        &self.state
    }

    /// Get the duty-cycle configuration.
    pub fn config(&self) -> &DutyCycleConfig {
        &self.config
    }
}
