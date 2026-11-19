#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ViolationCode {
    IdentityVerificationField,
    IdentityCertificationField,
    AugmentationStatusField,
    BiometricField,
    MedicalField,
    DeviceIdentifierField,
    CredentialField,
    SessionField,
    RawNeuralDataField,
    ExternalTransmissionField,
    ActuationSemanticField,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct IdentityNeutralityViolation {
    pub code: ViolationCode,
    pub field_name: String,
    pub explanation: String,
}
