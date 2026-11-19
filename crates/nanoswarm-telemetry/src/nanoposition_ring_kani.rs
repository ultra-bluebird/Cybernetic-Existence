// Filename: mk-bluebird/nanorobotics/crates/nanoswarm-telemetry/src/nanoposition_ring_kani.rs
// Destination: github.com/mk-bluebird/nanorobotics

#![forbid(unsafe_code)]

use kani::proof;
use crate::nanoposition::NanoPosition3;
use crate::nanoposition_ring::NanoPositionRing;

fn producer_push(ring: &NanoPositionRing, v: NanoPosition3) {
    ring.push(v);
}

#[proof]
fn no_torn_read_in_ring_buffer_single_producer() {
    let ring = NanoPositionRing::with_capacity_pow2(4);

    let a = NanoPosition3 {
        x: 1.0,
        y: 2.0,
        z: 3.0,
        ts: 1,
        flags: 0,
    };
    let b = NanoPosition3 {
        x: 4.0,
        y: 5.0,
        z: 6.0,
        ts: 2,
        flags: 0,
    };

    ring.push(a);
    ring.push(b);

    let v1 = ring.pop().unwrap();
    assert!(
        v1.x == a.x
            && v1.y == a.y
            && v1.z == a.z
            && v1.ts == a.ts
            && v1.flags == a.flags
    );

    let v2 = ring.pop().unwrap();
    assert!(
        v2.x == b.x
            && v2.y == b.y
            && v2.z == b.z
            && v2.ts == b.ts
            && v2.flags == b.flags
    );
}

#[proof]
fn no_torn_read_with_two_producers() {
    let ring = NanoPositionRing::with_capacity_pow2(4);

    let a = NanoPosition3 {
        x: 1.0,
        y: 2.0,
        z: 3.0,
        ts: 10,
        flags: 0xA1,
    };
    let b = NanoPosition3 {
        x: 4.0,
        y: 5.0,
        z: 6.0,
        ts: 20,
        flags: 0xB2,
    };

    producer_push(&ring, a);
    producer_push(&ring, b);

    let v1 = ring.pop().unwrap();
    let v2 = ring.pop().unwrap();

    let is_a = |v: &NanoPosition3| {
        v.x == a.x
            && v.y == a.y
            && v.z == a.z
            && v.ts == a.ts
            && v.flags == a.flags
    };
    let is_b = |v: &NanoPosition3| {
        v.x == b.x
            && v.y == b.y
            && v.z == b.z
            && v.ts == b.ts
            && v.flags == b.flags
    };

    assert!(is_a(&v1) || is_b(&v1));
    assert!(is_a(&v2) || is_b(&v2));
}
