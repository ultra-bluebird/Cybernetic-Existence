// Filename: mk-bluebird/nanorobotics/crates/nanorobotics-guards/src/verdict.rs
// Destination: github.com/mk-bluebird/nanorobotics
#![forbid(unsafe_code)]

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Verdict {
    Allow,
    Brake,
    Deny,
}

impl Verdict {
    pub fn combine(self, other: Verdict) -> Verdict {
        use Verdict::*;
        match (self, other) {
            (Deny, _) | (_, Deny) => Deny,
            (Brake, _) | (_, Brake) => Brake,
            (Allow, Allow) => Allow,
        }
    }

    pub fn is_allow(self) -> bool {
        matches!(self, Verdict::Allow)
    }

    pub fn is_brake(self) -> bool {
        matches!(self, Verdict::Brake)
    }

    pub fn is_deny(self) -> bool {
        matches!(self, Verdict::Deny)
    }
}
