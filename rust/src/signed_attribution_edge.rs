use std::collections::BTreeSet;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AttributionError {
    EmptyField(&'static str),
    DuplicateReference(&'static str),
    MissingWitness,
    UnsupportedRelationship,
    InvalidCertificationClaim,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AttributionRelationship {
    DerivedFrom,
    ForkedFrom,
    RemixedFrom,
    Cites,
    Translates,
    Adapts,
    Aggregates,
    MigratedFrom,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AttributionScope {
    WholeWork,
    NamedComponent(String),
    Excerpt(String),
    DatasetSlice(String),
    Method(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AttributionWitness {
    pub witness_reference: String,
    pub signature_reference: String,
    pub signed_at_rfc3339: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SignedAttributionEdge {
    pub edge_id: String,
    pub parent_references: Vec<String>,
    pub child_references: Vec<String>,
    pub relationship: AttributionRelationship,
    pub scope: AttributionScope,
    pub inheritance_rules: Vec<String>,
    pub created_at_rfc3339: String,
    pub witnesses: Vec<AttributionWitness>,
    pub signature_reference: String,
    pub identity_certification_claimed: bool,
}

impl SignedAttributionEdge {
    pub fn validate(&self) -> Result<(), AttributionError> {
        require_non_empty("edge_id", &self.edge_id)?;
        require_non_empty("created_at_rfc3339", &self.created_at_rfc3339)?;
        require_non_empty("signature_reference", &self.signature_reference)?;

        if self.parent_references.is_empty() {
            return Err(AttributionError::EmptyField("parent_references"));
        }

        if self.child_references.is_empty() {
            return Err(AttributionError::EmptyField("child_references"));
        }

        if self.witnesses.is_empty() {
            return Err(AttributionError::MissingWitness);
        }

        validate_unique("parent_references", &self.parent_references)?;
        validate_unique("child_references", &self.child_references)?;

        for parent in &self.parent_references {
            require_non_empty("parent_reference", parent)?;
        }

        for child in &self.child_references {
            require_non_empty("child_reference", child)?;
        }

        for rule in &self.inheritance_rules {
            require_non_empty("inheritance_rule", rule)?;
        }

        for witness in &self.witnesses {
            require_non_empty("witness_reference", &witness.witness_reference)?;
            require_non_empty("signature_reference", &witness.signature_reference)?;
        }

        if self.identity_certification_claimed {
            return Err(AttributionError::InvalidCertificationClaim);
        }

        Ok(())
    }

    pub fn attribution_obligations(&self) -> Vec<&str> {
        self.inheritance_rules
            .iter()
            .map(String::as_str)
            .collect()
    }
}

fn require_non_empty(field: &'static str, value: &str) -> Result<(), AttributionError> {
    if value.trim().is_empty() {
        return Err(AttributionError::EmptyField(field));
    }

    Ok(())
}

fn validate_unique(
    field: &'static str,
    values: &[String],
) -> Result<(), AttributionError> {
    let unique_values: BTreeSet<&String> = values.iter().collect();

    if unique_values.len() != values.len() {
        return Err(AttributionError::DuplicateReference(field));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_signed_remix_with_scope_and_witness() {
        let edge = SignedAttributionEdge {
            edge_id: "edge:remix:001".to_string(),
            parent_references: vec!["cid:parent-work".to_string()],
            child_references: vec!["cid:child-work".to_string()],
            relationship: AttributionRelationship::RemixedFrom,
            scope: AttributionScope::NamedComponent("evaluation-method".to_string()),
            inheritance_rules: vec![
                "attribution_required".to_string(),
                "human_review_required".to_string(),
            ],
            created_at_rfc3339: "2026-09-26T07:06:00Z".to_string(),
            witnesses: vec![AttributionWitness {
                witness_reference: "did:example:reviewer-1".to_string(),
                signature_reference: "cid:witness-signature".to_string(),
                signed_at_rfc3339: "2026-09-26T07:06:00Z".to_string(),
            }],
            signature_reference: "cid:edge-signature".to_string(),
            identity_certification_claimed: false,
        };

        assert_eq!(edge.validate(), Ok(()));
    }
}
