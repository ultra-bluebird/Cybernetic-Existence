use crate::{GatewaySession, SessionState};
use zeroize::Zeroize;

#[derive(Debug)]
pub struct EphemeralSessionStore {
    session: Option<GatewaySession>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct EphemeralStoreSnapshot {
    pub session_present: bool,
    pub session_state: Option<SessionState>,
    pub generation: Option<u64>,
    pub external_authority_active: bool,
}

impl EphemeralSessionStore {
    pub fn empty() -> Self {
        Self {
            session: None,
        }
    }

    pub fn insert(
        &mut self,
        session: GatewaySession,
    ) -> Result<(), GatewaySession> {
        if self.session.is_some() {
            return Err(session);
        }

        self.session = Some(session);
        Ok(())
    }

    pub fn session(
        &self,
    ) -> Option<&GatewaySession> {
        self.session.as_ref()
    }

    pub fn session_mut(
        &mut self,
    ) -> Option<&mut GatewaySession> {
        self.session.as_mut()
    }

    pub fn snapshot(
        &self,
    ) -> EphemeralStoreSnapshot {
        match self.session.as_ref() {
            Some(session) => EphemeralStoreSnapshot {
                session_present: true,
                session_state: Some(session.state()),
                generation: Some(session.generation()),
                external_authority_active: session.has_external_authority(),
            },
            None => EphemeralStoreSnapshot {
                session_present: false,
                session_state: None,
                generation: None,
                external_authority_active: false,
            },
        }
    }

    pub fn discard(
        &mut self,
    ) {
        if let Some(mut session) = self.session.take() {
            session.revoke(crate::TerminationReason::LocalShutdown)
                .ok();
            session.zeroize();
        }
    }

    pub fn is_empty(
        &self,
    ) -> bool {
        self.session.is_none()
    }
}

impl Drop for EphemeralSessionStore {
    fn drop(
        &mut self,
    ) {
        self.discard();
    }
}
