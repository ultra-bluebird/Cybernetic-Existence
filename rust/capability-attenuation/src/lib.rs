#![forbid(unsafe_code)]

use std::collections::BTreeSet;
use std::marker::PhantomData;
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CapabilityScope {
    pub operations: BTreeSet<String>,
    pub resources: BTreeSet<String>,
    pub purposes: BTreeSet<String>,
    pub data_categories: BTreeSet<String>,
    pub audience: BTreeSet<String>,
    pub expires_at_unix_s: u64,
    pub release_budget: u32,
    pub policy_version: String,
}

impl CapabilityScope {
    pub fn is_attenuation_of(&self, parent: &Self) -> bool {
        self.operations.is_subset(&parent.operations)
            && self.resources.is_subset(&parent.resources)
            && self.purposes.is_subset(&parent.purposes)
            && self.data_categories.is_subset(&parent.data_categories)
            && self.audience.is_subset(&parent.audience)
            && self.expires_at_unix_s <= parent.expires_at_unix_s
            && self.release_budget <= parent.release_budget
            && self.policy_version == parent.policy_version
    }
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum CapabilityError {
    #[error("child capability expands authority")]
    AuthorityExpansion,
    #[error("capability has expired")]
    Expired,
    #[error("capability has been revoked")]
    Revoked,
    #[error("capability budget is exhausted")]
    BudgetExhausted,
    #[error("policy denied requested capability")]
    PolicyDenied,
}

pub struct Requested;
pub struct DeckRestricted;
pub struct GatewayValidated;
pub struct PolicyPermitted;
pub struct Final;

#[derive(Debug, Clone)]
pub struct Capability<State> {
    scope: CapabilityScope,
    revoked: bool,
    marker: PhantomData<State>,
}

impl Capability<Requested> {
    pub fn new(scope: CapabilityScope) -> Self {
        Self {
            scope,
            revoked: false,
            marker: PhantomData,
        }
    }

    pub fn restrict(
        self,
        child_scope: CapabilityScope,
    ) -> Result<Capability<DeckRestricted>, CapabilityError> {
        if !child_scope.is_attenuation_of(&self.scope) {
            return Err(CapabilityError::AuthorityExpansion);
        }

        Ok(Capability {
            scope: child_scope,
            revoked: self.revoked,
            marker: PhantomData,
        })
    }
}

impl Capability<DeckRestricted> {
    pub fn gateway_validate(
        self,
        validated_scope: CapabilityScope,
    ) -> Result<Capability<GatewayValidated>, CapabilityError> {
        if !validated_scope.is_attenuation_of(&self.scope) {
            return Err(CapabilityError::AuthorityExpansion);
        }

        Ok(Capability {
            scope: validated_scope,
            revoked: self.revoked,
            marker: PhantomData,
        })
    }
}

impl Capability<GatewayValidated> {
    pub fn policy_permit(
        self,
        permitted_scope: CapabilityScope,
    ) -> Result<Capability<PolicyPermitted>, CapabilityError> {
        if !permitted_scope.is_attenuation_of(&self.scope) {
            return Err(CapabilityError::AuthorityExpansion);
        }

        if permitted_scope.operations.is_empty()
            || permitted_scope.resources.is_empty()
            || permitted_scope.purposes.is_empty()
        {
            return Err(CapabilityError::PolicyDenied);
        }

        Ok(Capability {
            scope: permitted_scope,
            revoked: self.revoked,
            marker: PhantomData,
        })
    }
}

impl Capability<PolicyPermitted> {
    pub fn finalize(
        self,
        now_unix_s: u64,
    ) -> Result<Capability<Final>, CapabilityError> {
        if self.revoked {
            return Err(CapabilityError::Revoked);
        }

        if now_unix_s >= self.scope.expires_at_unix_s {
            return Err(CapabilityError::Expired);
        }

        if self.scope.release_budget == 0 {
            return Err(CapabilityError::BudgetExhausted);
        }

        Ok(Capability {
            scope: self.scope,
            revoked: false,
            marker: PhantomData,
        })
    }
}

impl Capability<Final> {
    pub fn scope(&self) -> &CapabilityScope {
        &self.scope
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn requested_scope() -> CapabilityScope {
        CapabilityScope {
            operations: ["read".to_owned(), "export".to_owned()]
                .into_iter()
                .collect(),
            resources: ["consent_state".to_owned(), "audit_receipt".to_owned()]
                .into_iter()
                .collect(),
            purposes: ["local_review".to_owned()].into_iter().collect(),
            data_categories: ["consent_state".to_owned(), "reason_code".to_owned()]
                .into_iter()
                .collect(),
            audience: ["local_user".to_owned()].into_iter().collect(),
            expires_at_unix_s: 100,
            release_budget: 2,
            policy_version: "policy-2026-09".to_owned(),
        }
    }

    fn restricted_scope() -> CapabilityScope {
        CapabilityScope {
            operations: ["read".to_owned()].into_iter().collect(),
            resources: ["consent_state".to_owned()].into_iter().collect(),
            purposes: ["local_review".to_owned()].into_iter().collect(),
            data_categories: ["consent_state".to_owned()].into_iter().collect(),
            audience: ["local_user".to_owned()].into_iter().collect(),
            expires_at_unix_s: 90,
            release_budget: 1,
            policy_version: "policy-2026-09".to_owned(),
        }
    }

    #[test]
    fn permits_monotonic_attenuation() {
        let final_capability = Capability::<Requested>::new(requested_scope())
            .restrict(restricted_scope())
            .unwrap()
            .gateway_validate(restricted_scope())
            .unwrap()
            .policy_permit(restricted_scope())
            .unwrap()
            .finalize(10)
            .unwrap();

        assert_eq!(
            final_capability.scope().operations,
            ["read".to_owned()].into_iter().collect()
        );
    }

    #[test]
    fn rejects_capability_expansion() {
        let mut expanded = restricted_scope();
        expanded.operations.insert("firmware.update".to_owned());

        let result = Capability::<Requested>::new(requested_scope()).restrict(expanded);
        assert_eq!(result, Err(CapabilityError::AuthorityExpansion));
    }

    #[test]
    fn rejects_expired_finalization() {
        let result = Capability::<Requested>::new(requested_scope())
            .restrict(restricted_scope())
            .unwrap()
            .gateway_validate(restricted_scope())
            .unwrap()
            .policy_permit(restricted_scope())
            .unwrap()
            .finalize(90);

        assert_eq!(result, Err(CapabilityError::Expired));
    }
}
