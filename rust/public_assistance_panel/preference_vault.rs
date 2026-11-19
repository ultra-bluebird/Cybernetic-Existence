use std::collections::BTreeMap;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AccessibilityPreferences {
    pub text_scale_percent: u16,
    pub high_contrast: bool,
    pub preferred_language: String,
    pub reading_level: String,
    pub speech_rate_words_per_minute: u16,
    pub captions_enabled: bool,
    pub tactile_confirmation_enabled: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EnclaveRecord {
    pub encrypted_payload: Vec<u8>,
    pub created_at_unix_seconds: u64,
    pub expires_at_unix_seconds: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum VaultError {
    InvalidPreference,
    MissingRecord,
    ExpiredRecord,
    MalformedRecord,
}

pub trait SecureEnclave {
    fn seal(&mut self, plaintext: &[u8]) -> Result<Vec<u8>, VaultError>;
    fn unseal(&self, ciphertext: &[u8]) -> Result<Vec<u8>, VaultError>;
}

pub struct PreferenceVault<E: SecureEnclave> {
    enclave: E,
    records: BTreeMap<String, EnclaveRecord>,
    maximum_retention_seconds: u64,
}

impl<E: SecureEnclave> PreferenceVault<E> {
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

    pub fn delete(&mut self, local_session_label: &str) -> Result<(), VaultError> {
        validate_session_label(local_session_label)?;

        if self.records.remove(local_session_label).is_none() {
            return Err(VaultError::MissingRecord);
        }

        Ok(())
    }

    pub fn purge_expired(&mut self, now_unix_seconds: u64) {
        self.records.retain(|_, record| {
            now_unix_seconds <= record.expires_at_unix_seconds
        });
    }

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
