use std::collections::BTreeSet;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DisclosureDecision {
    pub requested: BTreeSet<String>,
    pub necessary: BTreeSet<String>,
    pub consented: BTreeSet<String>,
    pub policy_permitted: BTreeSet<String>,
    pub purpose_aligned: BTreeSet<String>,
    pub allowed: BTreeSet<String>,
}

impl DisclosureDecision {
    pub fn build(
        requested: BTreeSet<String>,
        necessary: BTreeSet<String>,
        consented: BTreeSet<String>,
        policy_permitted: BTreeSet<String>,
        purpose_aligned: BTreeSet<String>,
    ) -> Self {
        let allowed = requested
            .intersection(&necessary)
            .cloned()
            .collect::<BTreeSet<_>>()
            .intersection(&consented)
            .cloned()
            .collect::<BTreeSet<_>>()
            .intersection(&policy_permitted)
            .cloned()
            .collect::<BTreeSet<_>>()
            .intersection(&purpose_aligned)
            .cloned()
            .collect();

        Self {
            requested,
            necessary,
            consented,
            policy_permitted,
            purpose_aligned,
            allowed,
        }
    }

    pub fn permits_release(
        &self,
        released: &BTreeSet<String>,
    ) -> bool {
        released.is_subset(&self.allowed)
    }

    pub fn raw_disclosure_ratio(
        &self,
        released: &BTreeSet<String>,
    ) -> f64 {
        ratio(released.len(), self.requested.len())
    }

    pub fn necessary_disclosure_ratio(
        &self,
        released: &BTreeSet<String>,
    ) -> f64 {
        ratio(released.len(), self.necessary.len())
    }

    pub fn purpose_alignment(
        &self,
        released: &BTreeSet<String>,
    ) -> f64 {
        if released.is_empty() {
            return 1.0;
        }

        let aligned_count = released
            .intersection(&self.purpose_aligned)
            .count();

        aligned_count as f64 / released.len() as f64
    }
}

fn ratio(
    numerator: usize,
    denominator: usize,
) -> f64 {
    match (numerator, denominator) {
        (0, 0) => 0.0,
        (_, 0) => 1.0,
        _ => numerator as f64 / denominator as f64,
    }
}
