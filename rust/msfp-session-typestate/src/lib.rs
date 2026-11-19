#![forbid(unsafe_code)]

use std::marker::PhantomData;
use thiserror::Error;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum SessionError {
    #[error("request validation failed")]
    ValidationFailed,
    #[error("authentication failed")]
    AuthenticationFailed,
    #[error("policy denied request")]
    PolicyDenied,
    #[error("retry is not authorized")]
    RetryDenied,
    #[error("evidence seal is incomplete")]
    EvidenceNotWritten,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TerminalReason {
    ValidationFailure,
    AuthenticationFailure,
    PolicyDenied,
    Expired,
    UserRevocation,
    IntegrityFailure,
    BudgetExceeded,
    Timeout,
    Restart,
}

pub struct Cold;
pub struct AdmissionRequest;
pub struct IsolatedSession;
pub struct SoftReset;
pub struct Rejected;
pub struct Revoked;
pub struct EvidenceSeal;

#[derive(Debug)]
pub struct Session<State> {
    session_pseudonym: String,
    terminal_reason: Option<TerminalReason>,
    evidence_written: bool,
    marker: PhantomData<State>,
}

impl Session<Cold> {
    pub fn new() -> Self {
        Self {
            session_pseudonym: String::new(),
            terminal_reason: None,
            evidence_written: false,
            marker: PhantomData,
        }
    }

    pub fn begin_admission(self, session_pseudonym: String) -> Session<AdmissionRequest> {
        Session {
            session_pseudonym,
            terminal_reason: None,
            evidence_written: false,
            marker: PhantomData,
        }
    }
}

impl Session<AdmissionRequest> {
    pub fn validate(
        self,
        valid: bool,
    ) -> Result<Session<AdmissionRequest>, Session<Rejected>> {
        if valid {
            Ok(self)
        } else {
            Err(Session {
                session_pseudonym: self.session_pseudonym,
                terminal_reason: Some(TerminalReason::ValidationFailure),
                evidence_written: false,
                marker: PhantomData,
            })
        }
    }

    pub fn authenticate(
        self,
        authenticated: bool,
    ) -> Result<Session<AdmissionRequest>, Session<Rejected>> {
        if authenticated {
            Ok(self)
        } else {
            Err(Session {
                session_pseudonym: self.session_pseudonym,
                terminal_reason: Some(TerminalReason::AuthenticationFailure),
                evidence_written: false,
                marker: PhantomData,
            })
        }
    }

    pub fn permit(
        self,
        permitted: bool,
    ) -> Result<Session<IsolatedSession>, Session<Rejected>> {
        if permitted {
            Ok(Session {
                session_pseudonym: self.session_pseudonym,
                terminal_reason: None,
                evidence_written: false,
                marker: PhantomData,
            })
        } else {
            Err(Session {
                session_pseudonym: self.session_pseudonym,
                terminal_reason: Some(TerminalReason::PolicyDenied),
                evidence_written: false,
                marker: PhantomData,
            })
        }
    }
}

impl Session<IsolatedSession> {
    pub fn transient_fault(self) -> Session<SoftReset> {
        Session {
            session_pseudonym: self.session_pseudonym,
            terminal_reason: None,
            evidence_written: false,
            marker: PhantomData,
        }
    }

    pub fn revoke(self, reason: TerminalReason) -> Session<Revoked> {
        Session {
            session_pseudonym: self.session_pseudonym,
            terminal_reason: Some(reason),
            evidence_written: false,
            marker: PhantomData,
        }
    }
}

impl Session<SoftReset> {
    pub fn retry(
        self,
        retry_authorized: bool,
    ) -> Result<Session<AdmissionRequest>, Session<Revoked>> {
        if retry_authorized {
            Ok(Session {
                session_pseudonym: self.session_pseudonym,
                terminal_reason: None,
                evidence_written: false,
                marker: PhantomData,
            })
        } else {
            Err(Session {
                session_pseudonym: self.session_pseudonym,
                terminal_reason: Some(TerminalReason::Timeout),
                evidence_written: false,
                marker: PhantomData,
            })
        }
    }

    pub fn revoke(self, reason: TerminalReason) -> Session<Revoked> {
        Session {
            session_pseudonym: self.session_pseudonym,
            terminal_reason: Some(reason),
            evidence_written: false,
            marker: PhantomData,
        }
    }
}

impl Session<Rejected> {
    pub fn seal_evidence(mut self) -> Session<EvidenceSeal> {
        self.evidence_written = true;
        Session {
            session_pseudonym: self.session_pseudonym,
            terminal_reason: self.terminal_reason,
            evidence_written: true,
            marker: PhantomData,
        }
    }
}

impl Session<Revoked> {
    pub fn seal_evidence(mut self) -> Session<EvidenceSeal> {
        self.evidence_written = true;
        Session {
            session_pseudonym: self.session_pseudonym,
            terminal_reason: self.terminal_reason,
            evidence_written: true,
            marker: PhantomData,
        }
    }
}

impl Session<EvidenceSeal> {
    pub fn return_to_cold(self) -> Result<Session<Cold>, SessionError> {
        if !self.evidence_written {
            return Err(SessionError::EvidenceNotWritten);
        }

        Ok(Session::new())
    }

    pub fn reason(&self) -> Option<TerminalReason> {
        self.terminal_reason
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejected_session_requires_evidence_before_cold() {
        let admission = Session::<Cold>::new().begin_admission("session-a".to_owned());

        let rejected = admission.validate(false).unwrap_err();
        let sealed = rejected.seal_evidence();
        let cold = sealed.return_to_cold();

        assert!(cold.is_ok());
    }

    #[test]
    fn trusted_session_requires_all_admission_steps() {
        let session = Session::<Cold>::new()
            .begin_admission("session-b".to_owned())
            .validate(true)
            .unwrap()
            .authenticate(true)
            .unwrap()
            .permit(true)
            .unwrap();

        let revoked = session.revoke(TerminalReason::UserRevocation);
        let sealed = revoked.seal_evidence();

        assert_eq!(sealed.reason(), Some(TerminalReason::UserRevocation));
    }

    #[test]
    fn retry_denial_terminates_to_revoked() {
        let soft_reset = Session::<Cold>::new()
            .begin_admission("session-c".to_owned())
            .validate(true)
            .unwrap()
            .authenticate(true)
            .unwrap()
            .permit(true)
            .unwrap()
            .transient_fault();

        let revoked = soft_reset.retry(false).unwrap_err();
        let sealed = revoked.seal_evidence();

        assert_eq!(sealed.reason(), Some(TerminalReason::Timeout));
    }
}
