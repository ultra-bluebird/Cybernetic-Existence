#![forbid(unsafe_code)]
#![cfg(feature = "kani")]

extern crate alloc;

use alloc::vec;
use kani::proof;

use crate::{StlMissionFuture, StlMissionSpec, StlSignalSpec, StlAtomSpec, StlNode,
            StlNodeKind, AtomOp, SensorSample, MissionVerdict};
use cybernano_physio::PhysioState;
use cybercore_brain::NanoswarmCareEnvelope;

fn dummy_care_envelope() -> NanoswarmCareEnvelope {
    // Assume existing constructor produces envelope with RoH ceiling 0.30
    NanoswarmCareEnvelope::for_kani_default_host()
}

fn dummy_spec() -> StlMissionSpec {
    StlMissionSpec {
        mission_id: "mission.stl.demo.v1".into(),
        host_did: crate::HOST_DID.into(),
        bostrom_address: crate::BOSTROM_ADDRESS.into(),
        authority_clause: crate::ALN_MIGRATION_CYBERCORE_AUTHORITY_V1.into(),
        roh_ceiling_global: 0.30,
        pain_index_ceiling: 0.73,
        fear_index_min: 0.31,
        fear_index_max: 0.68,
        signals: vec![StlSignalSpec {
            id: "coretemp_delta".into(),
            roh_slice_max: 0.30,
        }],
        atoms: vec![StlAtomSpec {
            id: "coretemp_delta_lt_0_8".into(),
            signal_id: "coretemp_delta".into(),
            op: AtomOp::Le,
            threshold: 0.8,
            roh_weight: 1.0,
            pain_weight: 0.0,
            fear_weight: 0.0,
        }],
        formula_nodes: vec![StlNode {
            node_id: "root".into(),
            kind: StlNodeKind::Always,
            atom_id: Some("coretemp_delta_lt_0_8".into()),
            left: Some("root_atom".into()),
            right: None,
            t_start: 0.0,
            t_end: 60.0,
        }],
    }
}

fn physio_sample(delta: f32, t: f32) -> SensorSample {
    let mut state = PhysioState::any();
    state.tempdevnorm = delta;
    SensorSample {
        t_seconds: t,
        physio: state,
    }
}

/// If any sample violates RoH ceiling or STL robustness,
/// the mission future must eventually yield Violated.
#[proof]
fn stl_future_veto_is_bounded() {
    let spec = dummy_spec();
    let env = dummy_care_envelope();
    let mut fut = StlMissionFuture::new(spec, &env, 60.0);

    // Admissible physio state before violation.
    let s0 = physio_sample(0.3, 1.0);
    fut.push_sample(s0);
    // Violating sample with large core-temp delta.
    let s1 = physio_sample(2.0, 5.0);
    fut.push_sample(s1);

    // Poll until resolution; Kani unrolls finite steps.
    use core::task::{Context, Poll, RawWaker, RawWakerVTable, Waker};

    fn dummy_raw_waker() -> RawWaker {
        fn no_op(_: *const ()) {}
        fn clone(_: *const ()) -> RawWaker { dummy_raw_waker() }
        static VTABLE: RawWakerVTable = RawWakerVTable::new(clone, no_op, no_op, no_op);
        RawWaker::new(core::ptr::null(), &VTABLE)
    }

    let waker = unsafe { Waker::from_raw(dummy_raw_waker()) };
    let mut cx = Context::from_waker(&waker);

    let mut pinned = core::pin::Pin::new(&mut fut);
    let mut verdict = None;

    for _ in 0..10 {
        if let Poll::Ready(v) = pinned.as_mut().poll(&mut cx) {
            verdict = Some(v);
            break;
        }
    }

    assert!(verdict.is_some());
    assert_eq!(verdict.unwrap(), MissionVerdict::Violated);
}
