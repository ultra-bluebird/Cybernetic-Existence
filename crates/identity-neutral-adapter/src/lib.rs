#![forbid(unsafe_code)]
#![deny(unused_must_use)]
#![deny(unused_imports)]
#![deny(unused_variables)]

pub mod adapter;
pub mod api;
pub mod reality_window;
pub mod request;
pub mod response;
pub mod validation;
pub mod violation;

pub use adapter::IdentityNeutralAdapter;
pub use api::{
    assess_read_only,
    DefaultReadOnlyAssessmentPort,
    ReadOnlyAssessmentPort,
};
pub use reality_window::{
    RealityWindow,
    RealityWindowError,
};
pub use request::{
    AssessmentRequest,
    AssessmentRequestError,
};
pub use response::{
    AssessmentResponse,
    AssessmentResponseStatus,
};
pub use validation::validate_request;
pub use violation::{
    IdentityNeutralityViolation,
    ViolationCode,
};
