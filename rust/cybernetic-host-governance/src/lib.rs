#![forbid(unsafe_code)]
#![doc = include_str!("../README.md")]

pub mod acknowledgment;
pub mod continuity;

pub use acknowledgment::{
    acknowledge_declaration,
    validate_acknowledgment,
    AcknowledgmentError,
    AcknowledgmentState,
    DeclarationState,
    IdentityAcknowledgment,
};

pub use continuity::{
    validate_continuity_protection,
    ContinuityProtectionError,
    ContinuityProtectionRecord,
    PreferenceState,
};
