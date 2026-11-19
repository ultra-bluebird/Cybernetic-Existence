// Filename: mk-bluebird/nanorobotics/crates/nanoswarm-telemetry/src/nanoposition_ring.rs
// Destination: mk-bluebird/nanorobotics

#![forbid(unsafe_code)]

use core::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use crate::nanoposition::NanoPosition3;

struct Slot {
    value: NanoPosition3,
    ready: AtomicBool,
}

pub struct NanoPositionRing {
    slots: Box<[Slot]>,
    capacity: usize,
    write_index: AtomicUsize,
    read_index: AtomicUsize,
}

impl NanoPositionRing {
    /// Create a new ring with power-of-two capacity.
    pub fn with_capacity_pow2(capacity_pow2: usize) -> Self {
        assert!(capacity_pow2.is_power_of_two());

        let slots = (0..capacity_pow2)
            .map(|_| Slot {
                value: NanoPosition3 {
                    x: 0.0,
                    y: 0.0,
                    z: 0.0,
                    ts: 0,
                    flags: 0,
                },
                ready: AtomicBool::new(false),
            })
            .collect::<Vec<_>>()
            .into_boxed_slice();

        Self {
            slots,
            capacity: capacity_pow2,
            write_index: AtomicUsize::new(0),
            read_index: AtomicUsize::new(0),
        }
    }

    #[inline]
    fn mask(&self) -> usize {
        self.capacity - 1
    }

    /// Lock-free multi-producer push: writes a full NanoPosition3
    /// into a slot and then marks it ready with Release ordering.
    pub fn push(&self, value: NanoPosition3) {
        let idx = self.write_index.fetch_add(1, Ordering::AcqRel) & self.mask();
        self.slots[idx].value = value;
        self.slots[idx].ready.store(true, Ordering::Release);
    }

    /// Single-consumer pop: reads only when a slot is marked ready
    /// and clears the flag before advancing the read index.
    pub fn pop(&self) -> Option<NanoPosition3> {
        let read = self.read_index.load(Ordering::Acquire);
        if read >= self.write_index.load(Ordering::Acquire) {
            return None;
        }

        let idx = read & self.mask();
        if !self.slots[idx].ready.load(Ordering::Acquire) {
            return None;
        }

        let value = self.slots[idx].value;
        self.slots[idx].ready.store(false, Ordering::Release);
        self.read_index.store(read.wrapping_add(1), Ordering::Release);
        Some(value)
    }

    /// Approximate number of elements currently available to the consumer.
    pub fn len(&self) -> usize {
        let write = self.write_index.load(Ordering::Acquire);
        let read = self.read_index.load(Ordering::Acquire);
        write.saturating_sub(read)
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Total capacity of the ring (power of two).
    pub fn capacity(&self) -> usize {
        self.capacity
    }
}
