use std::collections::BTreeSet;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CapabilityScope {
    pub subject: String,
    pub purpose: String,
    pub operations: BTreeSet<String>,
    pub data_categories: BTreeSet<String>,
    pub audiences: BTreeSet<String>,
    pub expires_at_ms: u64,
    pub session_generation: u64,
    pub policy_version: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum AttenuationResult {
    Allowed(CapabilityScope),
    Denied,
}

pub fn attenuate(
    request: &CapabilityScope,
    policy_base: &CapabilityScope,
    consent_scope: &CapabilityScope,
    purpose_binding: &CapabilityScope,
    now_ms: u64,
) -> AttenuationResult {
    if request.subject != policy_base.subject
        || request.subject != consent_scope.subject
        || request.subject != purpose_binding.subject
        || request.purpose != policy_base.purpose
        || request.purpose != consent_scope.purpose
        || request.purpose != purpose_binding.purpose
        || request.session_generation != policy_base.session_generation
        || request.session_generation != consent_scope.session_generation
        || request.session_generation != purpose_binding.session_generation
        || request.policy_version != policy_base.policy_version
        || request.policy_version != consent_scope.policy_version
        || request.policy_version != purpose_binding.policy_version
    {
        return AttenuationResult::Denied;
    }

    let operations = intersect_all([
        &request.operations,
        &policy_base.operations,
        &consent_scope.operations,
        &purpose_binding.operations,
    ]);

    let data_categories = intersect_all([
        &request.data_categories,
        &policy_base.data_categories,
        &consent_scope.data_categories,
        &purpose_binding.data_categories,
    ]);

    let audiences = intersect_all([
        &request.audiences,
        &policy_base.audiences,
        &consent_scope.audiences,
        &purpose_binding.audiences,
    ]);

    let expires_at_ms = request
        .expires_at_ms
        .min(policy_base.expires_at_ms)
        .min(consent_scope.expires_at_ms)
        .min(purpose_binding.expires_at_ms);

    if operations.is_empty()
        || data_categories.is_empty()
        || audiences.is_empty()
        || expires_at_ms <= now_ms
    {
        return AttenuationResult::Denied;
    }

    AttenuationResult::Allowed(CapabilityScope {
        subject: request.subject.clone(),
        purpose: request.purpose.clone(),
        operations,
        data_categories,
        audiences,
        expires_at_ms,
        session_generation: request.session_generation,
        policy_version: request.policy_version.clone(),
    })
}

fn intersect_all<'a, const N: usize>(
    sets: [&'a BTreeSet<String>; N],
) -> BTreeSet<String> {
    let Some((first, rest)) = sets.split_first() else {
        return BTreeSet::new();
    };

    rest.iter().fold(
        (*first).clone(),
        |intersection, candidate| {
            intersection
                .intersection(candidate)
                .cloned()
                .collect()
        },
    )
}
