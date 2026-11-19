use crate::{
    adapter::IdentityNeutralAdapter,
    request::AssessmentRequest,
    response::AssessmentResponse,
};

pub trait ReadOnlyAssessmentPort {
    fn assess_read_only(
        &self,
        request: AssessmentRequest,
    ) -> AssessmentResponse;
}

#[derive(Clone, Debug)]
pub struct DefaultReadOnlyAssessmentPort {
    adapter: IdentityNeutralAdapter,
}

impl DefaultReadOnlyAssessmentPort {
    pub fn new(adapter: IdentityNeutralAdapter) -> Self {
        Self { adapter }
    }
}

impl ReadOnlyAssessmentPort for DefaultReadOnlyAssessmentPort {
    fn assess_read_only(
        &self,
        request: AssessmentRequest,
    ) -> AssessmentResponse {
        self.adapter.assess(request)
    }
}

pub fn assess_read_only(
    adapter: &IdentityNeutralAdapter,
    request: AssessmentRequest,
) -> AssessmentResponse {
    adapter.assess(request)
}
