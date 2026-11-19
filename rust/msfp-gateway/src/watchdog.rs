use std::sync::atomic::{AtomicBool, AtomicU8, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum WatchdogTerminationReason {
    LeaseExpired,
    ExplicitRevocation,
    IntegrityFailure,
    WatchdogFailure,
}

impl WatchdogTerminationReason {
    fn code(self) -> u8 {
        match self {
            Self::LeaseExpired => 1,
            Self::ExplicitRevocation => 2,
            Self::IntegrityFailure => 3,
            Self::WatchdogFailure => 4,
        }
    }

    fn from_code(code: u8) -> Option<Self> {
        match code {
            1 => Some(Self::LeaseExpired),
            2 => Some(Self::ExplicitRevocation),
            3 => Some(Self::IntegrityFailure),
            4 => Some(Self::WatchdogFailure),
            _ => None,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct LeaseSnapshot {
    pub generation: u64,
    pub remaining: Duration,
    pub terminated: bool,
    pub reason: Option<WatchdogTerminationReason>,
}

pub trait AuthorityGate: Send + Sync + 'static {
    fn revoke(
        &self,
        generation: u64,
        reason: WatchdogTerminationReason,
    );

    fn authority_is_active(&self, generation: u64) -> bool;
}

pub struct MonotonicLease {
    generation: u64,
    started_at: Instant,
    duration: Duration,
    terminated: AtomicBool,
    termination_reason: AtomicU8,
}

impl MonotonicLease {
    pub fn new(generation: u64, duration: Duration) -> Self {
        Self {
            generation,
            started_at: Instant::now(),
            duration,
            terminated: AtomicBool::new(false),
            termination_reason: AtomicU8::new(0),
        }
    }

    pub fn generation(&self) -> u64 {
        self.generation
    }

    pub fn is_expired(&self) -> bool {
        self.started_at.elapsed() >= self.duration
    }

    pub fn remaining(&self) -> Duration {
        self.duration.saturating_sub(self.started_at.elapsed())
    }

    pub fn is_terminated(&self) -> bool {
        self.terminated.load(Ordering::Acquire)
    }

    pub fn snapshot(&self) -> LeaseSnapshot {
        LeaseSnapshot {
            generation: self.generation,
            remaining: self.remaining(),
            terminated: self.is_terminated(),
            reason: WatchdogTerminationReason::from_code(
                self.termination_reason.load(Ordering::Acquire),
            ),
        }
    }

    pub fn terminate_once(
        &self,
        reason: WatchdogTerminationReason,
    ) -> bool {
        let changed = self
            .terminated
            .compare_exchange(
                false,
                true,
                Ordering::AcqRel,
                Ordering::Acquire,
            )
            .is_ok();

        if changed {
            self.termination_reason
                .store(reason.code(), Ordering::Release);
        }

        changed
    }
}

pub struct LeaseWatchdog<G: AuthorityGate> {
    lease: Arc<MonotonicLease>,
    gate: Arc<G>,
    poll_interval: Duration,
}

impl<G: AuthorityGate> LeaseWatchdog<G> {
    pub fn new(
        lease: Arc<MonotonicLease>,
        gate: Arc<G>,
        poll_interval: Duration,
    ) -> Self {
        Self {
            lease,
            gate,
            poll_interval: poll_interval.max(Duration::from_millis(1)),
        }
    }

    pub fn run_until_terminated(&self) {
        loop {
            if self.lease.is_terminated() {
                return;
            }

            if self.lease.is_expired() {
                self.terminate_now(WatchdogTerminationReason::LeaseExpired);
                return;
            }

            thread::sleep(self.poll_interval);
        }
    }

    pub fn terminate_now(
        &self,
        reason: WatchdogTerminationReason,
    ) {
        if self.lease.terminate_once(reason) {
            self.gate.revoke(self.lease.generation(), reason);
        }
    }
}
