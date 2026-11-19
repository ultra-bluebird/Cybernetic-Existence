use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PortabilityError {
    MissingReference(&'static str),
    UnsupportedProtocol,
    DuplicateProtocolBinding,
    CertificationClaimProhibited,
    MissingConsentScope,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum IdentityProtocol {
    Did,
    AtProtocol,
    Nostr,
    ActivityPub,
    DidComm,
    FutureProtocol(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProtocolBinding {
    pub protocol: IdentityProtocol,
    pub subject_reference: String,
    pub public_key_or_did_reference: String,
    pub provenance_reference: String,
    pub portability_scope: String,
    pub consent_scope_reference: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IdentityPortabilityFunctor {
    pub portable_subject_reference: String,
    pub source_binding: ProtocolBinding,
    pub target_binding: ProtocolBinding,
    pub mapping_reference: String,
    pub policy_bundle_reference: String,
    pub identity_verification_claimed: bool,
    pub identity_adjudication_permitted: bool,
}

impl IdentityPortabilityFunctor {
    pub fn validate(&self) -> Result<(), PortabilityError> {
        require("portable_subject_reference", &self.portable_subject_reference)?;
        require_binding(&self.source_binding)?;
        require_binding(&self.target_binding)?;
        require("mapping_reference", &self.mapping_reference)?;
        require("policy_bundle_reference", &self.policy_bundle_reference)?;

        if self.identity_verification_claimed || self.identity_adjudication_permitted {
            return Err(PortabilityError::CertificationClaimProhibited);
        }

        if self.source_binding.protocol == self.target_binding.protocol
            && self.source_binding.subject_reference == self.target_binding.subject_reference
        {
            return Err(PortabilityError::DuplicateProtocolBinding);
        }

        Ok(())
    }

    pub fn map_public_references(&self) -> BTreeMap<&str, &str> {
        let mut output = BTreeMap::new();
        output.insert("portable_subject", self.portable_subject_reference.as_str());
        output.insert("source_subject", self.source_binding.subject_reference.as_str());
        output.insert("target_subject", self.target_binding.subject_reference.as_str());
        output.insert("policy_bundle", self.policy_bundle_reference.as_str());
        output
    }
}

fn require(field: &'static str, value: &str) -> Result<(), PortabilityError> {
    if value.trim().is_empty() {
        return Err(PortabilityError::MissingReference(field));
    }

    Ok(())
}

fn require_binding(binding: &ProtocolBinding) -> Result<(), PortabilityError> {
    require("subject_reference", &binding.subject_reference)?;
    require("public_key_or_did_reference", &binding.public_key_or_did_reference)?;
    require("provenance_reference", &binding.provenance_reference)?;
    require("portability_scope", &binding.portability_scope)?;

    if binding.consent_scope_reference.trim().is_empty() {
        return Err(PortabilityError::MissingConsentScope);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_did_to_atproto_without_identity_certification() {
        let source = ProtocolBinding {
            protocol: IdentityProtocol::Did,
            subject_reference: "did:example:portable-subject".to_string(),
            public_key_or_did_reference: "did:example:portable-subject#key-1".to_string(),
            provenance_reference: "cid:did-binding-proof".to_string(),
            portability_scope: "public-attribution-only".to_string(),
            consent_scope_reference: "cid:consent-scope".to_string(),
        };

        let target = ProtocolBinding {
            protocol: IdentityProtocol::AtProtocol,
            subject_reference: "did:plc:exampleportable".to_string(),
            public_key_or_did_reference: "did:plc:exampleportable#atproto".to_string(),
            provenance_reference: "cid:atproto-binding-proof".to_string(),
            portability_scope: "public-attribution-only".to_string(),
            consent_scope_reference: "cid:consent-scope".to_string(),
        };

        let mapping = IdentityPortabilityFunctor {
            portable_subject_reference: "subject:portable:001".to_string(),
            source_binding: source,
            target_binding: target,
            mapping_reference: "cid:portability-map".to_string(),
            policy_bundle_reference: "cid:policy-bundle".to_string(),
            identity_verification_claimed: false,
            identity_adjudication_permitted: false,
        };

        assert_eq!(mapping.validate(), Ok(()));
    }
}
