#![cfg(kani)]

use super::{
    AuthorKind, CorridorChangeKind, CorridorPop, CorridorProposal, ProposalState,
};
use corridor_loader::ROH_GLOBAL_CEILING;
use evidence_bundle::EvidenceBundle10;
use uuid::Uuid;

fn dummy_bundle() -> EvidenceBundle10 {
    EvidenceBundle10::dummy()
}

#[kani::proof]
fn monotone_tightening_promotions_do_not_raise_ceiling() {
    let baseline = CorridorPop {
        roh_max: ROH_GLOBAL_CEILING,
        poly: corridor_loader::CorridorPolytope {
            a: vec![vec![1.0_f64, 0.0_f64]],
            b: vec![1.0_f64],
        },
    };

    let proposal = CorridorProposal {
        proposal_id: Uuid::new_v4(),
        author_kind: AuthorKind::AiChatAssistant,
        target_corridor_id: "roh.corridor.brain.6d.v1".to_string(),
        change_kind: CorridorChangeKind::DecreaseRohCeiling,
        delta: -0.05,
        rationale: "Conservative tightening".to_string(),
        evidence_bundle: dummy_bundle(),
        state: ProposalState::Draft,
        has_kani_proof: true,
        host_did: "OrganicCPU".to_string(),
        bostrom_addr: "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_string(),
        created_at_ms: 0,
        updated_at_ms: 0,
    };

    assert!(proposal.is_monotone_tightening(&baseline));

    let simulated = proposal
        .clone()
        .promote_to_simulated(&baseline, 1)
        .expect("must simulate");

    let proven = simulated
        .promote_to_proven(&baseline, 2)
        .expect("must become proven");

    let approved = proven
        .promote_to_human_approved(1, 1, 3)
        .expect("must be human-approved");

    let activated = approved
        .promote_to_activated(4)
        .expect("must activate with proof");

    let new_ceiling = baseline.roh_max + activated.delta;
    assert!(new_ceiling <= baseline.roh_max);
}
