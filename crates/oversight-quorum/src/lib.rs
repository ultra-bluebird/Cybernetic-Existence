#![forbid(unsafe_code)]

//! Verification of policy-defined independent-review quorums.
//!
//! This crate checks declared membership, role diversity, conflict status, and
//! approval count. It does not establish legal authority or reviewer neutrality.

use std::collections::BTreeSet;

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum ReviewerCategory {
    SubjectAdvocate,
    PrivacySpecialist,
    TechnicalAuditor,
    OmbudsReviewer,
    CommunityRepresentative,
}

#[derive(Debug, Clone)]
pub struct ReviewerApproval {
    pub reviewer_id: String,
    pub category: ReviewerCategory,
    pub membership_active: bool,
    pub conflict_disclosed: bool,
    pub conflict_disqualifying: bool,
    pub approved: bool,
}

#[derive(Debug, Clone)]
pub struct QuorumPolicy {
    pub minimum_approvals: usize,
    pub minimum_distinct_categories: usize,
    pub required_categories: BTreeSet<ReviewerCategory>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QuorumDecision {
    Approved,
    InsufficientApprovals,
    InsufficientCategoryDiversity,
    MissingRequiredCategory,
}

pub fn verify_quorum(
    policy: &QuorumPolicy,
    approvals: &[ReviewerApproval],
) -> QuorumDecision {
    let valid: Vec<&ReviewerApproval> = approvals
        .iter()
        .filter(|approval| {
            approval.approved
                && approval.membership_active
                && approval.conflict_disclosed
                && !approval.conflict_disqualifying
        })
        .collect();

    if valid.len() < policy.minimum_approvals {
        return QuorumDecision::InsufficientApprovals;
    }

    let categories: BTreeSet<ReviewerCategory> =
        valid.iter().map(|approval| approval.category.clone()).collect();

    if categories.len() < policy.minimum_distinct_categories {
        return QuorumDecision::InsufficientCategoryDiversity;
    }

    if !policy.required_categories.is_subset(&categories) {
        return QuorumDecision::MissingRequiredCategory;
    }

    QuorumDecision::Approved
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quorum_requires_disclosed_non_disqualifying_reviewers() {
        let policy = QuorumPolicy {
            minimum_approvals: 2,
            minimum_distinct_categories: 2,
            required_categories: BTreeSet::from([ReviewerCategory::TechnicalAuditor]),
        };

        let approvals = vec![
            ReviewerApproval {
                reviewer_id: "reviewer-a".to_owned(),
                category: ReviewerCategory::TechnicalAuditor,
                membership_active: true,
                conflict_disclosed: true,
                conflict_disqualifying: false,
                approved: true,
            },
            ReviewerApproval {
                reviewer_id: "reviewer-b".to_owned(),
                category: ReviewerCategory::PrivacySpecialist,
                membership_active: true,
                conflict_disclosed: true,
                conflict_disqualifying: false,
                approved: true,
            },
        ];

        assert_eq!(verify_quorum(&policy, &approvals), QuorumDecision::Approved);
    }
}
