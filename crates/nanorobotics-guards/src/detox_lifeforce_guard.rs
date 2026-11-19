// crates/nanorobotics-guards/src/detox_lifeforce_guard.rs
#![forbid(unsafe_code)]
#![deny(warnings)]
#![cfg_attr(not(test), no_std)]

use core::fmt;

use serde::{Deserialize, Serialize};

pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS_PRIMARY: &str =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

pub const ROH_CEILING_GLOBAL: f32 = 0.30;
pub const LIFEFORCE_FLOOR_MISSION_DEFAULT: f32 = 0.30;
pub const LIFEFORCE_FLOOR_EPISODE_DEFAULT: f32 = 0.25;

/// Sovereign binding for host-critical detox decisions.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HostSovereigntyBinding {
    pub host_did: heapless::String<64>,
    pub bostrom_address: heapless::String<64>,
    pub aln_clause: heapless::String<64>,
}

impl HostSovereigntyBinding {
    pub fn primary() -> Self {
        let mut did = heapless::String::new();
        did.push_str(HOST_DID).unwrap();
        let mut addr = heapless::String::new();
        addr.push_str(BOSTROM_ADDRESS_PRIMARY).unwrap();
        let mut clause = heapless::String::new();
        clause.push_str(ALN_MIGRATION_CYBERCORE_AUTHORITY_V1)
            .unwrap();
        Self {
            host_did: did,
            bostrom_address: addr,
            aln_clause: clause,
        }
    }

    pub fn is_primary_and_compliant(&self) -> bool {
        self.host_did.as_str() == HOST_DID
            && self.bostrom_address.as_str() == BOSTROM_ADDRESS_PRIMARY
            && self.aln_clause.as_str()
                == ALN_MIGRATION_CYBERCORE_AUTHORITY_V1
    }
}

/// Lifeforce snapshot around a detox session.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LifeforceSessionState {
    /// Lifeforce at session start.
    pub lf_start: f32,
    /// Minimum lifeforce observed during session.
    pub lf_min: f32,
    /// Lifeforce at session end.
    pub lf_end: f32,
}

impl LifeforceSessionState {
    pub fn temporary_drop(&self) -> f32 {
        (self.lf_start - self.lf_min).max(0.0)
    }

    pub fn net_gain(&self) -> f32 {
        self.lf_end - self.lf_start
    }
}

/// Detox mission envelope: RoH usage and time window.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DetoxMissionEnvelope {
    /// Maximum RoH observed or planned during the session.
    pub roh_max: f32,
    /// Session duration in minutes.
    pub duration_minutes: f32,
}

/// Lifeforce floors used by the guard.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LifeforceFloors {
    pub lf_floor_mission: f32,
    pub lf_floor_episode: f32,
}

impl LifeforceFloors {
    pub fn default() -> Self {
        Self {
            lf_floor_mission: LIFEFORCE_FLOOR_MISSION_DEFAULT,
            lf_floor_episode: LIFEFORCE_FLOOR_EPISODE_DEFAULT,
        }
    }
}

/// Bound coefficients f(RoH_max, T) and g(RoH_max, T).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DetoxBoundCoeffs {
    pub alpha: f32,
    pub beta: f32,
    pub gamma: f32,
}

impl DetoxBoundCoeffs {
    pub fn default() -> Self {
        Self {
            alpha: 0.20,
            beta: 0.05,
            gamma: 0.10,
        }
    }

    /// Upper bound on temporary lifeforce drop ΔLF_drop_max.
    pub fn f_lifeforce_drop_max(&self, roh_max: f32, t_minutes: f32) -> f32 {
        if roh_max <= 0.0 || t_minutes <= 0.0 {
            return 0.0;
        }
        let exp_term = (-self.beta * t_minutes).exp();
        self.alpha * roh_max * (1.0 - exp_term)
    }

    /// Lower bound on net lifeforce gain ΔLF_net_min.
    pub fn g_lifeforce_net_min(&self, roh_max: f32, t_minutes: f32) -> f32 {
        if roh_max <= 0.0 || t_minutes <= 0.0 {
            return 0.0;
        }
        self.gamma * roh_max * t_minutes
    }
}

/// Verdicts for detox lifeforce guard.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum DetoxLifeforceVerdict {
    Allow,
    AllowShrunk,
    Deny,
}

#[derive(Debug)]
pub enum DetoxLifeforceGuardError {
    SovereigntyMismatch,
    LifeforceMissionFloorBreach { lf_start: f32, floor: f32 },
    LifeforceEpisodeFloorBreach { lf_min: f32, floor: f32 },
    RoHCeilingExceeded { roh_max: f32 },
}

impl fmt::Display for DetoxLifeforceGuardError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DetoxLifeforceGuardError::SovereigntyMismatch => {
                write!(f, "sovereignty binding mismatch")
            }
            DetoxLifeforceGuardError::LifeforceMissionFloorBreach {
                lf_start,
                floor,
            } => write!(
                f,
                "lifeforce mission floor breach: lf_start={} floor={}",
                lf_start, floor
            ),
            DetoxLifeforceGuardError::LifeforceEpisodeFloorBreach {
                lf_min,
                floor,
            } => write!(
                f,
                "lifeforce episode floor breach: lf_min={} floor={}",
                lf_min, floor
            ),
            DetoxLifeforceGuardError::RoHCeilingExceeded { roh_max } => {
                write!(f, "RoH ceiling exceeded: roh_max={}", roh_max)
            }
        }
    }
}

/// Core guard coupling RoH_max, session duration, and lifeforce floors/net gain.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DetoxLifeforceGuard {
    pub sovereignty: HostSovereigntyBinding,
    pub floors: LifeforceFloors,
    pub coeffs: DetoxBoundCoeffs,
}

impl DetoxLifeforceGuard {
    pub fn new_default() -> Self {
        Self {
            sovereignty: HostSovereigntyBinding::primary(),
            floors: LifeforceFloors::default(),
            coeffs: DetoxBoundCoeffs::default(),
        }
    }

    pub fn validate_binding(&self) -> Result<(), DetoxLifeforceGuardError> {
        if !self.sovereignty.is_primary_and_compliant() {
            return Err(DetoxLifeforceGuardError::SovereigntyMismatch);
        }
        Ok(())
    }

    /// Evaluate a candidate detox mission against lifeforce constraints.
    ///
    /// Does not mutate any external state; intended to be wired into higher-level
    /// nanoswarm planners and BiophysicalLedger / LifeforceKernel integration code.
    pub fn evaluate(
        &self,
        mission: &DetoxMissionEnvelope,
        lf_state: &LifeforceSessionState,
    ) -> Result<DetoxLifeforceVerdict, DetoxLifeforceGuardError> {
        self.validate_binding()?;

        // Floors: mission and episode.
        if lf_state.lf_start < self.floors.lf_floor_mission {
            return Err(DetoxLifeforceGuardError::LifeforceMissionFloorBreach {
                lf_start: lf_state.lf_start,
                floor: self.floors.lf_floor_mission,
            });
        }
        if lf_state.lf_min < self.floors.lf_floor_episode {
            return Err(DetoxLifeforceGuardError::LifeforceEpisodeFloorBreach {
                lf_min: lf_state.lf_min,
                floor: self.floors.lf_floor_episode,
            });
        }

        // Global RoH ceiling.
        if mission.roh_max > ROH_CEILING_GLOBAL + f32::EPSILON {
            return Err(DetoxLifeforceGuardError::RoHCeilingExceeded {
                roh_max: mission.roh_max,
            });
        }

        let drop = lf_state.temporary_drop();
        let drop_max = self
            .coeffs
            .f_lifeforce_drop_max(mission.roh_max, mission.duration_minutes);

        let net_gain = lf_state.net_gain();
        let net_min = self
            .coeffs
            .g_lifeforce_net_min(mission.roh_max, mission.duration_minutes);

        // Decision logic:
        // - Allow if both temporary drop and net gain meet the corridor bounds.
        // - AllowShrunk if RoH_max is within global ceiling but temporary drop exceeds bound;
        //   higher-level planner should shrink mission (RoH or duration) before execution.
        // - Deny if net gain fails corridor or floors are breached.
        if drop <= drop_max + f32::EPSILON && net_gain >= net_min - f32::EPSILON {
            Ok(DetoxLifeforceVerdict::Allow)
        } else if drop > drop_max + f32::EPSILON && net_gain >= net_min - f32::EPSILON {
            Ok(DetoxLifeforceVerdict::AllowShrunk)
        } else {
            Ok(DetoxLifeforceVerdict::Deny)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn allow_when_within_bounds() {
        let guard = DetoxLifeforceGuard::new_default();
        let mission = DetoxMissionEnvelope {
            roh_max: 0.25,
            duration_minutes: 60.0,
        };
        let lf_state = LifeforceSessionState {
            lf_start: 0.80,
            lf_min: 0.70,
            lf_end: 0.90,
        };
        let verdict = guard.evaluate(&mission, &lf_state).unwrap();
        assert_eq!(verdict, DetoxLifeforceVerdict::Allow);
    }

    #[test]
    fn deny_when_episode_floor_breached() {
        let guard = DetoxLifeforceGuard::new_default();
        let mission = DetoxMissionEnvelope {
            roh_max: 0.20,
            duration_minutes: 30.0,
        };
        let lf_state = LifeforceSessionState {
            lf_start: 0.80,
            lf_min: 0.20,
            lf_end: 0.85,
        };
        let err = guard.evaluate(&mission, &lf_state).unwrap_err();
        matches!(err, DetoxLifeforceGuardError::LifeforceEpisodeFloorBreach { .. });
    }

    #[test]
    fn allow_shrunk_when_drop_exceeds_bound_but_gain_ok() {
        let guard = DetoxLifeforceGuard::new_default();
        let mission = DetoxMissionEnvelope {
            roh_max: 0.30,
            duration_minutes: 120.0,
        };
        let lf_state = LifeforceSessionState {
            lf_start: 0.85,
            lf_min: 0.70,
            lf_end: 0.95,
        };
        let verdict = guard.evaluate(&mission, &lf_state).unwrap();
        assert_eq!(verdict, DetoxLifeforceVerdict::AllowShrunk);
    }
}
