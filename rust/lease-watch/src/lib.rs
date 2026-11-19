#![forbid(unsafe_code)]

use serde::Serialize;
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LeaseState {
    pub session_pseudonym: String,
    pub expires_at_unix_s: u64,
    pub revoked: bool,
    pub integrity_ok: bool,
    pub remaining_releases: u32,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct LeaseReceipt {
    pub event_type: String,
    pub event_time_unix_s: u64,
    pub session_pseudonym: String,
    pub outcome: String,
    pub reason_code: String,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum LeaseError {
    #[error("lease has terminated")]
    Terminated,
    #[error("release budget exhausted")]
    BudgetExceeded,
}

impl LeaseState {
    pub fn terminated(&self, now_unix_s: u64) -> bool {
        now_unix_s >= self.expires_at_unix_s
            || self.revoked
            || !self.integrity_ok
            || self.remaining_releases == 0
    }

    pub fn terminate_reason(&self, now_unix_s: u64) -> &'static str {
        if now_unix_s >= self.expires_at_unix_s {
            "LEASE_EXPIRED"
        } else if self.revoked {
            "LEASE_REVOKED"
        } else if !self.integrity_ok {
            "INTEGRITY_FAILURE"
        } else if self.remaining_releases == 0 {
            "BUDGET_EXCEEDED"
        } else {
            "ACTIVE"
        }
    }

    pub fn consume_release(&mut self, now_unix_s: u64) -> Result<LeaseReceipt, LeaseError> {
        if self.terminated(now_unix_s) {
            return Err(if self.remaining_releases == 0 {
                LeaseError::BudgetExceeded
            } else {
                LeaseError::Terminated
            });
        }

        self.remaining_releases -= 1;

        Ok(LeaseReceipt {
            event_type: "LEASE_RELEASE_CONSUMED".to_owned(),
            event_time_unix_s: now_unix_s,
            session_pseudonym: self.session_pseudonym.clone(),
            outcome: "ALLOWED".to_owned(),
            reason_code: if self.remaining_releases == 0 {
                "FINAL_BUDGET_UNIT_CONSUMED".to_owned()
            } else {
                "LEASE_ACTIVE".to_owned()
            },
        })
    }

    pub fn revoke(&mut self, now_unix_s: u64) -> LeaseReceipt {
        self.revoked = true;
        LeaseReceipt {
            event_type: "LEASE_REVOKED".to_owned(),
            event_time_unix_s: now_unix_s,
            session_pseudonym: self.session_pseudonym.clone(),
            outcome: "BLOCKED".to_owned(),
            reason_code: "LEASE_REVOKED".to_owned(),
        }
    }

    pub fn restart_boundary(&mut self) {
        self.revoked = true;
        self.integrity_ok = false;
        self.remaining_releases = 0;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn active_lease() -> LeaseState {
        LeaseState {
            session_pseudonym: "session-pseudo-1".to_owned(),
            expires_at_unix_s: 100,
            revoked: false,
            integrity_ok: true,
            remaining_releases: 1,
        }
    }

    #[test]
    fn expiration_terminates() {
        let lease = active_lease();
        assert!(lease.terminated(100));
        assert_eq!(lease.terminate_reason(100), "LEASE_EXPIRED");
    }

    #[test]
    fn revocation_blocks_future_release() {
        let mut lease = active_lease();
        lease.revoke(50);
        assert_eq!(lease.consume_release(51), Err(LeaseError::Terminated));
    }

    #[test]
    fn restart_cannot_resurrect_session() {
        let mut lease = active_lease();
        lease.restart_boundary();
        assert!(lease.terminated(1));
        assert_eq!(lease.consume_release(1), Err(LeaseError::BudgetExceeded));
    }

    #[test]
    fn final_budget_unit_is_one_way() {
        let mut lease = active_lease();
        assert!(lease.consume_release(50).is_ok());
        assert_eq!(lease.consume_release(51), Err(LeaseError::BudgetExceeded));
    }
}
