# Public Assistance Panel

`public-assistance-panel` is a Rust library for local, enclave-backed storage of opt-in accessibility preferences on a privacy-preserving public-assistance panel.

The library supports a local preference vault for settings such as text scale, high contrast, language, reading level, captions, speech rate, and tactile confirmation. It intentionally does not contain networking, analytics, cloud synchronization, speech recording, transcript retention, biometrics, identity verification, or behavioral profiling.

## Purpose

Public assistance panels should remain accessible without requiring an account, app, personal device, cloud service, internet connection, augmentation status, biometric submission, or identity disclosure.

This library supports that goal by storing only local, user-selected accessibility settings behind a secure enclave abstraction.

## Supported data

The vault can store:

- Text scaling preference
- High-contrast preference
- Preferred language
- Plain-language reading mode
- Speech rate
- Caption preference
- Tactile-confirmation preference

The vault must not store:

- Audio recordings
- Speech transcripts
- Voiceprints
- Legal names
- Government identifiers
- Device identifiers
- Persistent cross-panel identifiers
- Biometric information
- Health information
- Augmentation information
- Conversation history
- Behavioral profiles
- Precise location history

## Security model

The embedding application must provide a `SecureEnclave` implementation.

A production enclave implementation must:

- Use authenticated encryption for confidentiality and integrity
- Keep encryption keys outside ordinary application memory where platform support exists
- Reject altered ciphertext
- Avoid remote replication of preference content
- Avoid network telemetry containing preference content
- Support local deletion
- Support bounded retention

The crate does not implement cryptography itself. It defines a narrow interface so platform-specific secure hardware or operating-system facilities can be used without embedding a cloud or telemetry dependency.

## Privacy model

The vault is local-only.

- No network client is included.
- No cloud synchronization is included.
- No analytics client is included.
- No speech or transcript feature is included.
- No global identity is generated.
- Each record uses a constrained local session label.
- Every record has a maximum retention period.
- Records can be deleted immediately through the `delete` method.
- Expired records can be removed through `purge_expired`.

A local session label must be short, non-empty, and limited to ASCII letters, digits, hyphens, and underscores. It must not contain a legal name, government identifier, device identifier, biometric identifier, or a cross-panel tracking identifier.

## Example

```rust
use public_assistance_panel::{
    AccessibilityPreferences,
    PreferenceVault,
    SecureEnclave,
    VaultError,
};

struct DemoEnclave;

impl SecureEnclave for DemoEnclave {
    fn seal(&mut self, plaintext: &[u8]) -> Result<Vec<u8>, VaultError> {
        Ok(plaintext.iter().map(|byte| byte ^ 0xA5).collect())
    }

    fn unseal(&self, ciphertext: &[u8]) -> Result<Vec<u8>, VaultError> {
        Ok(ciphertext.iter().map(|byte| byte ^ 0xA5).collect())
    }
}

fn main() -> Result<(), VaultError> {
    let preferences = AccessibilityPreferences {
        text_scale_percent: 150,
        high_contrast: true,
        preferred_language: "en".to_owned(),
        reading_level: "plain-language".to_owned(),
        speech_rate_words_per_minute: 150,
        captions_enabled: true,
        tactile_confirmation_enabled: true,
    };

    let mut vault = PreferenceVault::new(DemoEnclave, 3_600)?;

    vault.save(
        "local-session-a",
        &preferences,
        1_700_000_000,
    )?;

    let restored = vault.load(
        "local-session-a",
        1_700_000_120,
    )?;

    assert_eq!(restored, preferences);

    vault.delete("local-session-a")?;

    Ok(())
}
```

The `DemoEnclave` in this example is only a deterministic demonstration. It is not an encryption implementation and must not be used in a production system.

## Build and test

```text
cargo test
```

The crate targets Rust 1.86 and uses the Rust 2021 edition.

## Integration boundaries

This crate is intended to be called by a local public-assistance application with:

- On-device speech recognition
- A local language model
- Keyboard, touch, switch, and screen-reader-compatible controls
- Captions and local text-to-speech
- Tactile or haptic confirmation when available
- A physical microphone mute control
- A physical privacy shield for display content
- Signed offline updates

The preference vault is not an identity system, authentication system, eligibility system, legal-advice system, or behavioral analytics component.

## Invariants

- Essential panel functions remain available without saved preferences.
- Essential panel functions remain available when the microphone is muted.
- Essential panel functions remain available when speech recognition has low confidence.
- Essential panel functions remain available without a network connection.
- Preference saving is opt-in.
- Preference records are local, encrypted, and retention-bounded.
- Preference records can be deleted through an accessible local action.
- No audio, transcript, identity, biometric, health, augmentation, device, or behavioral data is stored.
- No component in this crate exports preference content to a remote endpoint.
- The secure enclave implementation must reject tampered ciphertext.
- A failed decrypt operation must not return partially parsed preferences.

## Research status

This crate provides a bounded local storage interface and unit tests. It does not establish hardware-enclave security on its own. Production deployment requires platform-specific verification of the enclave integration, accessibility testing with panel users, signed-update validation, physical privacy-control testing, threat modeling, and independent security review.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.90 | The crate provides explicit local-storage, retention, deletion, and input-validation behavior |
| eco_impact_value | 0.52 | Local processing avoids unnecessary network transfer and cloud-compute demand while supporting accessible public-service access |
| harm_risk | 0.18 | The crate stores limited preference fields locally and excludes networking, identity, speech, and telemetry functions |
| accessibility_impact | 0.97 | Supports opt-in local preferences while requiring independent accessible fallback paths |
| rights_alignment | 0.96 | Supports privacy, autonomy, deletion, data minimization, local control, and non-discriminatory access |
