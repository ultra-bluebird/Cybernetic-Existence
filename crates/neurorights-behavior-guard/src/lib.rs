// crates/neurorights-behavior-guard/src/lib.rs
#![forbid(unsafe_code)]

pub enum BehaviorKind {
    EmploymentDecisionFromDreams,
    CreditScoringFromNeurodata,
    // extend as .evo adds behaviors
}

pub fn behavior_policy_check(kind: BehaviorKind) {
    match kind {
        BehaviorKind::EmploymentDecisionFromDreams
        | BehaviorKind::CreditScoringFromNeurodata => {
            // Hard fail at runtime if ever reached; CI and proc-macro
            // aim to make this path unreachable in production.
            panic!("forbidden neurorights behavior attempted: {:?}", kind);
        }
    }
}
