#![forbid(unsafe_code)]
#![deny(warnings)]

use serde::{Deserialize, Serialize};

use nanotree_identity::{HostIdentityStamp, HOSTDID, BOSTROMADDRESS};

/// Eight-axis Tree-of-Life state vector for Reality.os.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct TreeOfLifeAxes {
    pub xblood: f32,
    pub xoxygen: f32,
    pub xmicrovasc: f32,
    pub xthermal: f32,
    pub xfear: f32,
    pub xpain: f32,
    pub ximmune: f32,
    pub xpsych: f32,
}

impl TreeOfLifeAxes {
    pub fn clamped(self) -> Self {
        fn clamp(v: f32) -> f32 {
            if v.is_nan() {
                0.0
            } else if v < 0.0 {
                0.0
            } else if v > 1.0 {
                1.0
            } else {
                v
            }
        }

        Self {
            xblood: clamp(self.xblood),
            xoxygen: clamp(self.xoxygen),
            xmicrovasc: clamp(self.xmicrovasc),
            xthermal: clamp(self.xthermal),
            xfear: clamp(self.xfear),
            xpain: clamp(self.xpain),
            ximmune: clamp(self.ximmune),
            xpsych: clamp(self.xpsych),
        }
    }
}

/// Plane tags for Tree-of-Life dispatch.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum PlaneTag {
    Bioscale,
    Cybernetic,
    OrganicCPU,
    MicroSociety,
}

/// Host-bound Reality.os snapshot.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RealityOsSnapshot {
    pub identity: HostIdentityStamp,
    pub axes: TreeOfLifeAxes,
    pub planes: [PlaneTag; 4],
    pub roh_scalar: RoHScalar,
}

impl RealityOsSnapshot {
    pub fn new(identity: HostIdentityStamp, axes: TreeOfLifeAxes, planes: [PlaneTag; 4]) -> Self {
        let clamped_axes = axes.clamped();
        let roh_scalar = RoHScalar::from_axes(clamped_axes);
        Self {
            identity,
            axes: clamped_axes,
            planes,
            roh_scalar,
        }
    }

    pub fn is_host_bound(&self) -> bool {
        self.identity.hostdid == HOSTDID && self.identity.bostromaddress == BOSTROMADDRESS
    }
}

/// Global Risk-of-Harm scalar.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct RoHScalar {
    pub total: f64,
}

impl RoHScalar {
    pub const CEILING: f64 = 0.30;

    pub fn from_axes(axes: TreeOfLifeAxes) -> Self {
        let a = axes.clamped();

        // Default conservative weights; sum must be <= 0.30.
        let wblood = 0.05_f64;
        let woxygen = 0.05_f64;
        let wmicrovasc = 0.04_f64;
        let wthermal = 0.04_f64;
        let wfear = 0.03_f64;
        let wpain = 0.03_f64;
        let wimmune = 0.03_f64;
        let wpsych = 0.03_f64;

        let mut total = 0.0_f64;

        total += wblood * a.xblood as f64;
        total += woxygen * a.xoxygen as f64;
        total += wmicrovasc * a.xmicrovasc as f64;
        total += wthermal * a.xthermal as f64;
        total += wfear * a.xfear as f64;
        total += wpain * a.xpain as f64;
        total += wimmune * a.ximmune as f64;
        total += wpsych * a.xpsych as f64;

        if total < 0.0 {
            total = 0.0;
        }
        if total > Self::CEILING {
            total = Self::CEILING;
        }

        Self { total }
    }
}

/// Neurorights bitmask shard.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct NeurorightsShard {
    pub identity: HostIdentityStamp,
    pub bits: u32,
}

#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Neuroright {
    MentalPrivacy = 0,
    CognitiveLiberty = 1,
    MentalIntegrity = 2,
    NonPunitiveXR = 3,
    SoulNonAddressability = 4,
    NonCommercialNeuralData = 5,
    FairBenefit = 6,
}

impl NeurorightsShard {
    pub fn validate(&self) -> Result<(), String> {
        if !self.identity.iscanonical() {
            return Err("NeurorightsShard identity mismatch".into());
        }
        let reserved_mask: u32 = !0u32 << 7;
        if self.bits & reserved_mask != 0 {
            return Err("NeurorightsShard reserved bits must be zero".into());
        }
        Ok(())
    }

    pub fn is_active(&self, right: Neuroright) -> bool {
        let bit = right as u8;
        (self.bits & (1u32 << bit)) != 0
    }
}

/// Snapshot-level neurorights validation.
/// This is a structural skeleton; actual field checks are wired in other modules.
pub fn neurorights_ok(snapshot: &RealityOsSnapshot, shard: &NeurorightsShard) -> bool {
    if shard.validate().is_err() {
        return false;
    }

    // Mental privacy: host-bound snapshot required.
    if shard.is_active(Neuroright::MentalPrivacy) {
        if !snapshot.is_host_bound() {
            return false;
        }
    }

    // Cognitive liberty, mental integrity, XR, soul, data, fair benefit
    // will be enforced via additional modules; here we only keep identity binding.
    true
}
