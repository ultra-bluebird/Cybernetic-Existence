// crates/nanoswarm-stl-futures/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

extern crate alloc;

use alloc::vec::Vec;
use alloc::string::String;
use core::pin::Pin;
use core::task::{Context, Poll};
use serde::{Deserialize, Serialize};

// Cybercore / physio integrations (existing crates).
use cybernano_physio::{PhysioState, PhysioCaps};
use cybercore_brain::NanoswarmCareEnvelope;
use safety_core::GuardVerdict;

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCOREAUTHORITY.v1";

pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum MissionVerdict {
    Satisfied,
    Violated,
    Timeout,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct StlSignalSpec {
    pub id: String,
    pub roh_slice_max: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct StlAtomSpec {
    pub id: String,
    pub signal_id: String,
    pub op: AtomOp,
    pub threshold: f32,
    pub roh_weight: f32,
    pub pain_weight: f32,
    pub fear_weight: f32,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum AtomOp {
    Lt,
    Le,
    Gt,
    Ge,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum StlNodeKind {
    Atom,
    Not,
    And,
    Or,
    Always,     // G_[a,b]
    Eventually, // F_[a,b]
    Until,      // U_[a,b]
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct StlNode {
    pub node_id: String,
    pub kind: StlNodeKind,
    pub atom_id: Option<String>,
    pub left: Option<String>,
    pub right: Option<String>,
    pub t_start: f32,
    pub t_end: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct StlMissionSpec {
    pub mission_id: String,
    pub host_did: String,
    pub bostrom_address: String,
    pub authority_clause: String,
    pub roh_ceiling_global: f32,
    pub pain_index_ceiling: f32,
    pub fear_index_min: f32,
    pub fear_index_max: f32,
    pub signals: Vec<StlSignalSpec>,
    pub atoms: Vec<StlAtomSpec>,
    pub formula_nodes: Vec<StlNode>,
}

impl StlMissionSpec {
    pub fn validate(&self) -> bool {
        if self.host_did != HOST_DID {
            return false;
        }
        if self.bostrom_address != BOSTROM_ADDRESS {
            return false;
        }
        if self.authority_clause != ALN_MIGRATION_CYBERCORE_AUTHORITY_V1 {
            return false;
        }
        if !(0.0..=0.30).contains(&self.roh_ceiling_global) {
            return false;
        }
        if !(0.0..=0.73).contains(&self.pain_index_ceiling) {
            return false;
        }
        if !(0.31..=0.68).contains(&self.fear_index_min) {
            return false;
        }
        if !(self.fear_index_min..=0.68).contains(&self.fear_index_max) {
            return false;
        }
        true
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SensorSample {
    pub t_seconds: f32,
    pub physio: PhysioState,
}

#[derive(Clone, Debug)]
pub struct StlMonitorState {
    pub last_t: f32,
    pub robustness_root: f32,
    pub roh_accum: f32,
    pub pain_index: f32,
    pub fear_index: f32,
}

impl StlMonitorState {
    pub fn new() -> Self {
        Self {
            last_t: 0.0,
            robustness_root: 0.0,
            roh_accum: 0.0,
            pain_index: 0.0,
            fear_index: 0.0,
        }
    }
}

/// Continuous-time STL monitor compiled into a Rust future.
/// Evaluates robustness over incoming sensor samples and
/// produces a mission verdict with bounded time-to-veto.
pub struct StlMissionFuture<'a> {
    spec: StlMissionSpec,
    care_envelope: &'a NanoswarmCareEnvelope,
    state: StlMonitorState,
    horizon_seconds: f32,
    samples: Vec<SensorSample>,
    resolved: Option<MissionVerdict>,
}

impl<'a> StlMissionFuture<'a> {
    pub fn new(
        spec: StlMissionSpec,
        care_envelope: &'a NanoswarmCareEnvelope,
        horizon_seconds: f32,
    ) -> Self {
        let mut s = spec.clone();
        assert!(s.validate());
        Self {
            spec: s,
            care_envelope,
            state: StlMonitorState::new(),
            horizon_seconds,
            samples: Vec::new(),
            resolved: None,
        }
    }

    pub fn push_sample(&mut self, sample: SensorSample) {
        self.samples.push(sample);
    }

    fn eval_atom(&self, atom: &StlAtomSpec, physio: &PhysioState) -> f32 {
        let value = match atom.signal_id.as_str() {
            "coretemp_delta" => physio.tempdevnorm,
            "pain_vas" => physio.pain_vas,
            "fear_vas" => physio.fear_vas,
            "hrv_sdnn" => physio.hrv_sdnn_ms,
            _ => 0.0,
        };
        let margin = match atom.op {
            AtomOp::Lt | AtomOp::Le => atom.threshold - value,
            AtomOp::Gt | AtomOp::Ge => value - atom.threshold,
        };
        margin
    }

    fn eval_node(&self, node_id: &str, physio: &PhysioState, t: f32) -> f32 {
        let node = self
            .spec
            .formula_nodes
            .iter()
            .find(|n| n.node_id == node_id)
            .expect("node");

        match node.kind {
            StlNodeKind::Atom => {
                let atom_id = node.atom_id.as_ref().expect("atom_id");
                let atom = self
                    .spec
                    .atoms
                    .iter()
                    .find(|a| a.id == *atom_id)
                    .expect("atom");
                self.eval_atom(atom, physio)
            }
            StlNodeKind::Not => {
                let child_id = node.left.as_ref().expect("left");
                -self.eval_node(child_id, physio, t)
            }
            StlNodeKind::And => {
                let l = node.left.as_ref().expect("left");
                let r = node.right.as_ref().expect("right");
                let rl = self.eval_node(l, physio, t);
                let rr = self.eval_node(r, physio, t);
                rl.min(rr)
            }
            StlNodeKind::Or => {
                let l = node.left.as_ref().expect("left");
                let r = node.right.as_ref().expect("right");
                let rl = self.eval_node(l, physio, t);
                let rr = self.eval_node(r, physio, t);
                rl.max(rr)
            }
            StlNodeKind::Always => {
                // Approximate G_[a,b] by running min robustness over window [a,b].
                // Here we just enforce local margin; full window is handled in poll.
                let a = node.t_start;
                let b = node.t_end;
                if t < a || t > b {
                    0.0
                } else {
                    let child_id = node.left.as_ref().expect("left");
                    self.eval_node(child_id, physio, t)
                }
            }
            StlNodeKind::Eventually => {
                // Local robustness; global F_[a,b] handled by window union.
                let a = node.t_start;
                let b = node.t_end;
                if t < a || t > b {
                    -1.0
                } else {
                    let child_id = node.left.as_ref().expect("left");
                    self.eval_node(child_id, physio, t)
                }
            }
            StlNodeKind::Until => {
                // Simplified U_[a,b]: robustness of right if within [a,b],
                // otherwise robustness of left.
                let a = node.t_start;
                let b = node.t_end;
                let l = node.left.as_ref().expect("left");
                let r = node.right.as_ref().expect("right");
                if (a..=b).contains(&t) {
                    self.eval_node(r, physio, t)
                } else {
                    self.eval_node(l, physio, t)
                }
            }
        }
    }

    fn update_state(&mut self) {
        for sample in self.samples.iter() {
            let t = sample.t_seconds;
            let physio = &sample.physio;
            self.state.last_t = t;

            // Root formula is first node.
            if let Some(root) = self.spec.formula_nodes.first() {
                let r = self.eval_node(&root.node_id, physio, t);
                // Accumulate min robustness for G operators, max for F; we approximate with min.
                if self.state.robustness_root == 0.0 {
                    self.state.robustness_root = r;
                } else {
                    self.state.robustness_root = self.state.robustness_root.min(r);
                }
            }

            // Update RoH, pain, fear indices via care envelope.
            let roh = self.care_envelope.compute_roh(physio);
            self.state.roh_accum = roh;

            self.state.pain_index = self.care_envelope.compute_pain_index(physio);
            self.state.fear_index = self.care_envelope.compute_fear_index(physio);
        }

        self.samples.clear();
    }

    fn guard_verdict(&self) -> GuardVerdict {
        // Hard veto if robustness ≤ 0 or RoH / pain / fear exceed envelopes.
        if self.state.robustness_root <= 0.0 {
            GuardVerdict::Deny
        } else if self.state.roh_accum > self.spec.roh_ceiling_global
            || self.state.pain_index > self.spec.pain_index_ceiling
            || self.state.fear_index < self.spec.fear_index_min
            || self.state.fear_index > self.spec.fear_index_max
        {
            GuardVerdict::Deny
        } else if self.state.robustness_root < 0.1 {
            GuardVerdict::AllowWithBrake
        } else {
            GuardVerdict::Allow
        }
    }
}

impl<'a> core::future::Future for StlMissionFuture<'a> {
    type Output = MissionVerdict;

    fn poll(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Self::Output> {
        let this = self.get_mut();

        if this.resolved.is_some() {
            return Poll::Ready(this.resolved.unwrap());
        }

        this.update_state();

        // Bound time-to-veto: once we pass horizon_seconds, either satisfied or violated.
        if this.state.last_t >= this.horizon_seconds {
            let gv = this.guard_verdict();
            let verdict = match gv {
                GuardVerdict::Deny => MissionVerdict::Violated,
                GuardVerdict::AllowWithBrake => MissionVerdict::Satisfied,
                GuardVerdict::Allow => {
                    if this.state.robustness_root > 0.0 {
                        MissionVerdict::Satisfied
                    } else {
                        MissionVerdict::Violated
                    }
                }
            };
            this.resolved = Some(verdict);
            return Poll::Ready(verdict);
        }

        // Not yet at horizon, but robustness or RoH could already veto.
        let gv = this.guard_verdict();
        match gv {
            GuardVerdict::Deny => {
                this.resolved = Some(MissionVerdict::Violated);
                Poll::Ready(MissionVerdict::Violated)
            }
            _ => Poll::Pending,
        }
    }
}
