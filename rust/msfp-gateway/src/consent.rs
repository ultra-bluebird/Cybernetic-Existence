use std::collections::BTreeSet;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ConsentScope {
    pub purpose: String,
    pub operations: BTreeSet<String>,
    pub data_categories: BTreeSet<String>,
    pub audiences: BTreeSet<String>,
    pub expires_at_ms: u64,
    pub session_generation: u64,
    pub policy_version: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ScopeDiff {
    pub added_operations: BTreeSet<String>,
    pub removed_operations: BTreeSet<String>,
    pub added_data_categories: BTreeSet<String>,
    pub removed_data_categories: BTreeSet<String>,
    pub added_audiences: BTreeSet<String>,
    pub removed_audiences: BTreeSet<String>,
    pub purpose_changed: bool,
    pub expiry_extended: bool,
    pub policy_version_changed: bool,
    pub generation_changed: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ScopeChange {
    NoChange,
    Attenuation(ScopeDiff),
    Expansion(ScopeDiff),
    Incompatible(ScopeDiff),
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct HolderAuthorization {
    pub approved: bool,
    pub reviewed_generation: u64,
    pub proposed_generation: u64,
    pub scope_digest: [u8; 32],
    pub local_confirmation: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ConsentDecision {
    Unchanged,
    Narrowed(ConsentScope),
    ExpansionRequiresFreshAdmission,
    Denied,
}

pub fn compare_scope(
    current: &ConsentScope,
    proposed: &ConsentScope,
) -> ScopeChange {
    let added_operations = difference(
        &proposed.operations,
        &current.operations,
    );
    let removed_operations = difference(
        &current.operations,
        &proposed.operations,
    );
    let added_data_categories = difference(
        &proposed.data_categories,
        &current.data_categories,
    );
    let removed_data_categories = difference(
        &current.data_categories,
        &proposed.data_categories,
    );
    let added_audiences = difference(
        &proposed.audiences,
        &current.audiences,
    );
    let removed_audiences = difference(
        &current.audiences,
        &proposed.audiences,
    );

    let diff = ScopeDiff {
        added_operations,
        removed_operations,
        added_data_categories,
        removed_data_categories,
        added_audiences,
        removed_audiences,
        purpose_changed: current.purpose != proposed.purpose,
        expiry_extended: proposed.expires_at_ms > current.expires_at_ms,
        policy_version_changed: current.policy_version != proposed.policy_version,
        generation_changed: current.session_generation != proposed.session_generation,
    };

    if diff.added_operations.is_empty()
        && diff.removed_operations.is_empty()
        && diff.added_data_categories.is_empty()
        && diff.removed_data_categories.is_empty()
        && diff.added_audiences.is_empty()
        && diff.removed_audiences.is_empty()
        && !diff.purpose_changed
        && !diff.expiry_extended
        && !diff.policy_version_changed
        && !diff.generation_changed
    {
        return ScopeChange::NoChange;
    }

    if !diff.added_operations.is_empty()
        || !diff.added_data_categories.is_empty()
        || !diff.added_audiences.is_empty()
        || diff.expiry_extended
    {
        return ScopeChange::Expansion(diff);
    }

    if diff.purpose_changed
        || diff.policy_version_changed
        || diff.generation_changed
    {
        return ScopeChange::Incompatible(diff);
    }

    ScopeChange::Attenuation(diff)
}

pub fn apply_active_session_change(
    current: &ConsentScope,
    proposed: &ConsentScope,
) -> ConsentDecision {
    match compare_scope(current, proposed) {
        ScopeChange::NoChange => ConsentDecision::Unchanged,
        ScopeChange::Attenuation(_) => ConsentDecision::Narrowed(proposed.clone()),
        ScopeChange::Expansion(_) | ScopeChange::Incompatible(_) => {
            ConsentDecision::ExpansionRequiresFreshAdmission
        }
    }
}

pub fn authorize_fresh_expansion(
    current: &ConsentScope,
    proposed: &ConsentScope,
    authorization: &HolderAuthorization,
    expected_scope_digest: [u8; 32],
) -> ConsentDecision {
    let change = compare_scope(current, proposed);

    if !matches!(change, ScopeChange::Expansion(_)) {
        return ConsentDecision::Denied;
    }

    if !authorization.approved
        || !authorization.local_confirmation
        || authorization.reviewed_generation != current.session_generation
        || authorization.proposed_generation <= current.session_generation
        || authorization.proposed_generation != proposed.session_generation
        || authorization.scope_digest != expected_scope_digest
    {
        return ConsentDecision::Denied;
    }

    ConsentDecision::ExpansionRequiresFreshAdmission
}

fn difference(
    left: &BTreeSet<String>,
    right: &BTreeSet<String>,
) -> BTreeSet<String> {
    left.difference(right).cloned().collect()
}
