#![cfg_attr(not(feature = "std"), no_std)]

//! Local-only accessibility preference storage for a public-assistance panel.
//!
//! This crate intentionally does not provide networking, telemetry, analytics,
//! cloud synchronization, speech recording, transcript retention, identity
//! management, biometric processing, or device tracking. It stores only
//! explicit accessibility preferences in an enclave-backed local vault.
//!
//! A platform integration supplies the [`SecureEnclave`] implementation. The
//! enclave implementation must provide authenticated encryption, protect keys
//! from ordinary application memory, and reject tampered ciphertext.

#[cfg(not(feature = "std"))]
compile_error!("public-assistance-panel currently requires the default `std` feature.");

use std::collections::BTreeMap;
use std::time::{SystemTime, UNIX_EPOCH};

/// Accessibility preferences that a person may explicitly choose to store on
/// the local panel.
///
/// These fields are intentionally limited to presentation and interaction
/// options. The structure must not be extended with identity, voiceprint,
/// transcript, health, biometric, augmentation, or behavioral fields.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AccessibilityPreferences {
    /// Preferred text scaling percentage, constrained to 80 through 300.
    pub text_scale_percent: u16,

    /// Whether high-contrast rendering is preferred.
    pub high_contrast: bool,

    /// User-selected language tag or local language label.
    pub preferred_language: String,

    /// User-selected plain-language reading mode.
    pub reading_level: String,

    /// Text-to-speech rate, constrained to 80 through 320 words per minute.
    pub speech_rate_words_per_minute: u16,

    /// Whether captions should be shown when available.
    pub captions_enabled: bool,

    /// Whether local tactile confirmation is enabled when supported.
    pub tactile_confirmation_enabled: bool,
}

/// Encrypted local preference record.
///
/// The record is scoped to a local session label. The session label must not
/// contain a government identifier, legal name, device identifier, biometric
/// identifier, or any cross-panel persistent identifier.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EnclaveRecord {
    /// Authenticated ciphertext supplied by the secure enclave.
    pub encrypted_payload: Vec<u8>,

    /// Creation time expressed as seconds since the Unix epoch.
    pub created_at_unix_seconds: u64,

    /// Expiry time expressed as seconds since the Unix epoch.
    pub expires_at_unix_seconds: u64,
}

/// Errors returned by preference-vault operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum VaultError {
    /// A submitted preference, label, retention period, or time value is invalid.
    InvalidPreference,

    /// The requested local record is absent.
    MissingRecord,

    /// The requested record has passed its retention deadline.
    ExpiredRecord,

    /// Decrypted content does not match the constrained local serialization format.
    MalformedRecord,

    /// The enclave implementation rejected a cryptographic operation.
    EnclaveFailure,
}

/// Platform-specific interface to a secure enclave or hardware-backed secure
/// storage service.
///
/// Implementations must use authenticated encryption. A successful [`unseal`]
/// result must establish both ciphertext confidentiality and integrity.
///
/// This trait intentionally exposes no export, synchronization, telemetry, or
/// remote-replication method.
pub trait SecureEnclave {
    /// Authenticates and encrypts plaintext for local storage.
    fn seal(&mut self, plaintext: &[u8]) -> Result<Vec<u8>, VaultError>;

    /// Authenticates and decrypts local ciphertext.
    fn unseal(&self, ciphertext: &[u8]) -> Result<Vec<u8>, VaultError>;
}

/// Local, enclave-backed vault for opt-in accessibility preferences.
///
/// The vault does not generate a global identity. Each application integration
/// should use a short-lived, local-only session label. Call [`delete`] at the
/// end of a session when the person did not request future local reuse.
pub struct PreferenceVault<E: SecureEnclave> {
    enclave: E,
    records: BTreeMap<String, EnclaveRecord>,
    maximum_retention_seconds: u64,
}

impl<E: SecureEnclave> PreferenceVault<E> {
    /// Creates a local preference vault with a bounded maximum retention period.
    ///
    /// The caller selects the retention limit according to the panel's
    /// documented local policy. A retention limit of zero is rejected.
    pub fn new(enclave: E, maximum_retention_seconds: u64) -> Result<Self, VaultError> {
        if maximum_retention_seconds == 0 {
            return Err(VaultError::InvalidPreference);
        }

        Ok(Self {
            enclave,
            records: BTreeMap::new(),
            maximum_retention_seconds,
        })
    }

    /// Stores explicit local accessibility preferences under a local-only label.
    ///
    /// Existing records for the same label are replaced. The replacement remains
    /// local, encrypted, and subject to the configured expiry period.
    pub fn save(
        &mut self,
        local_session_label: &str,
        preferences: &AccessibilityPreferences,
        now_unix_seconds: u64,
    ) -> Result<(), VaultError> {
        validate_session_label(local_session_label)?;
        validate_preferences(preferences)?;

        let plaintext = serialize_preferences(preferences);
        let encrypted_payload = self.enclave.seal(&plaintext)?;

        let expires_at_unix_seconds = now_unix_seconds
            .checked_add(self.maximum_retention_seconds)
            .ok_or(VaultError::InvalidPreference)?;

        self.records.insert(
            local_session_label.to_owned(),
            EnclaveRecord {
                encrypted_payload,
                created_at_unix_seconds: now_unix_seconds,
                expires_at_unix_seconds,
            },
        );

        Ok(())
    }

    /// Loads an active local preference record.
    ///
    /// Expired records are not returned. Applications should call
    /// [`purge_expired`] periodically and always provide a visible, accessible
    /// option to delete saved preferences.
    pub fn load(
        &self,
        local_session_label: &str,
        now_unix_seconds: u64,
    ) -> Result<AccessibilityPreferences, VaultError> {
        validate_session_label(local_session_label)?;

        let record = self
            .records
            .get(local_session_label)
            .ok_or(VaultError::MissingRecord)?;

        if now_unix_seconds > record.expires_at_unix_seconds {
            return Err(VaultError::ExpiredRecord);
        }

        let plaintext = self.enclave.unseal(&record.encrypted_payload)?;
        deserialize_preferences(&plaintext)
    }

    /// Deletes a local preference record immediately.
    ///
    /// This is the software path for a visible “clear saved preferences” action.
    pub fn delete(&mut self, local_session_label: &str) -> Result<(), VaultError> {
        validate_session_label(local_session_label)?;

        if self.records.remove(local_session_label).is_none() {
            return Err(VaultError::MissingRecord);
        }

        Ok(())
    }

    /// Deletes all records whose configured retention period has expired.
    pub fn purge_expired(&mut self, now_unix_seconds: u64) {
        self.records
            .retain(|_, record| now_unix_seconds <= record.expires_at_unix_seconds);
    }

    /// Returns the number of currently retained local records.
    ///
    /// This exposes no record content and is intended only for local health and
    /// maintenance checks.
    pub fn record_count(&self) -> usize {
        self.records.len()
    }

    /// Returns the current system time as seconds since the Unix epoch.
    pub fn current_time_unix_seconds() -> Result<u64, VaultError> {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|duration| duration.as_secs())
            .map_err(|_| VaultError::InvalidPreference)
    }
}

fn validate_session_label(value: &str) -> Result<(), VaultError> {
    if value.is_empty() || value.len() > 96 {
        return Err(VaultError::InvalidPreference);
    }

    if !value
        .bytes()
        .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-' || byte == b'_')
    {
        return Err(VaultError::InvalidPreference);
    }

    Ok(())
}

fn validate_preferences(value: &AccessibilityPreferences) -> Result<(), VaultError> {
    if !(80..=300).contains(&value.text_scale_percent) {
        return Err(VaultError::InvalidPreference);
    }

    if value.preferred_language.is_empty() || value.preferred_language.len() > 48 {
        return Err(VaultError::InvalidPreference);
    }

    if value.reading_level.is_empty() || value.reading_level.len() > 48 {
        return Err(VaultError::InvalidPreference);
    }

    if !(80..=320).contains(&value.speech_rate_words_per_minute) {
        return Err(VaultError::InvalidPreference);
    }

    if value.preferred_language.contains('|') || value.reading_level.contains('|') {
        return Err(VaultError::InvalidPreference);
    }

    Ok(())
}

fn serialize_preferences(value: &AccessibilityPreferences) -> Vec<u8> {
    format!(
        "{}|{}|{}|{}|{}|{}|{}",
        value.text_scale_percent,
        value.high_contrast,
        value.preferred_language,
        value.reading_level,
        value.speech_rate_words_per_minute,
        value.captions_enabled,
        value.tactile_confirmation_enabled
    )
    .into_bytes()
}

fn deserialize_preferences(input: &[u8]) -> Result<AccessibilityPreferences, VaultError> {
    let value = std::str::from_utf8(input).map_err(|_| VaultError::MalformedRecord)?;
    let parts: Vec<&str> = value.split('|').collect();

    if parts.len() != 7 {
        return Err(VaultError::MalformedRecord);
    }

    let preferences = AccessibilityPreferences {
        text_scale_percent: parts[0].parse().map_err(|_| VaultError::MalformedRecord)?,
        high_contrast: parts[1].parse().map_err(|_| VaultError::MalformedRecord)?,
        preferred_language: parts[2].to_owned(),
        reading_level: parts[3].to_owned(),
        speech_rate_words_per_minute: parts[4]
            .parse()
            .map_err(|_| VaultError::MalformedRecord)?,
        captions_enabled: parts[5].parse().map_err(|_| VaultError::MalformedRecord)?,
        tactile_confirmation_enabled: parts[6]
            .parse()
            .map_err(|_| VaultError::MalformedRecord)?,
    };

    validate_preferences(&preferences)?;
    Ok(preferences)
}

#[cfg(test)]
mod tests {
    use super::{
        AccessibilityPreferences, PreferenceVault, SecureEnclave, VaultError,
    };

    #[derive(Default)]
    struct TestEnclave;

    impl SecureEnclave for TestEnclave {
        fn seal(&mut self, plaintext: &[u8]) -> Result<Vec<u8>, VaultError> {
            Ok(plaintext.iter().map(|byte| byte ^ 0xA5).collect())
        }

        fn unseal(&self, ciphertext: &[u8]) -> Result<Vec<u8>, VaultError> {
            Ok(ciphertext.iter().map(|byte| byte ^ 0xA5).collect())
        }
    }

    fn preferences() -> AccessibilityPreferences {
        AccessibilityPreferences {
            text_scale_percent: 160,
            high_contrast: true,
            preferred_language: "en".to_owned(),
            reading_level: "plain-language".to_owned(),
            speech_rate_words_per_minute: 160,
            captions_enabled: true,
            tactile_confirmation_enabled: true,
        }
    }

    #[test]
    fn saves_and_loads_preferences_locally() {
        let mut vault = PreferenceVault::new(TestEnclave, 3_600).expect("valid vault");
        let expected = preferences();

        vault
            .save("local-session-a", &expected, 1_000)
            .expect("save succeeds");

        let actual = vault
            .load("local-session-a", 1_200)
            .expect("load succeeds");

        assert_eq!(actual, expected);
        assert_eq!(vault.record_count(), 1);
    }

    #[test]
    fn rejects_expired_preference_records() {
        let mut vault = PreferenceVault::new(TestEnclave, 60).expect("valid vault");

        vault
            .save("local-session-a", &preferences(), 1_000)
            .expect("save succeeds");

        let error = vault
            .load("local-session-a", 1_061)
            .expect_err("record must expire");

        assert_eq!(error, VaultError::ExpiredRecord);
    }

    #[test]
    fn deletes_preferences_on_request() {
        let mut vault = PreferenceVault::new(TestEnclave, 3_600).expect("valid vault");

        vault
            .save("local-session-a", &preferences(), 1_000)
            .expect("save succeeds");

        vault
            .delete("local-session-a")
            .expect("delete succeeds");

        let error = vault
            .load("local-session-a", 1_001)
            .expect_err("deleted record must not load");

        assert_eq!(error, VaultError::MissingRecord);
    }

    #[test]
    fn rejects_invalid_or_tracking_like_session_labels() {
        let mut vault = PreferenceVault::new(TestEnclave, 3_600).expect("valid vault");

        let error = vault
            .save("session with spaces", &preferences(), 1_000)
            .expect_err("label must be restricted");

        assert_eq!(error, VaultError::InvalidPreference);
    }

    #[test]
    fn rejects_out_of_range_accessibility_preferences() {
        let mut vault = PreferenceVault::new(TestEnclave, 3_600).expect("valid vault");
        let invalid_preferences = AccessibilityPreferences {
            text_scale_percent: 40,
            ..preferences()
        };

        let error = vault
            .save("local-session-a", &invalid_preferences, 1_000)
            .expect_err("text scaling must be constrained");

        assert_eq!(error, VaultError::InvalidPreference);
    }

    #[test]
    fn purges_expired_records() {
        let mut vault = PreferenceVault::new(TestEnclave, 60).expect("valid vault");

        vault
            .save("local-session-a", &preferences(), 1_000)
            .expect("save succeeds");

        vault.purge_expired(1_061);

        assert_eq!(vault.record_count(), 0);
    }
}
