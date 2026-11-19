use public_assistance_panel::{
    AccessibilityPreferences,
    PreferenceVault,
    SecureEnclave,
    VaultError,
};

struct DemonstrationEnclave;

impl SecureEnclave for DemonstrationEnclave {
    fn seal(&mut self, plaintext: &[u8]) -> Result<Vec<u8>, VaultError> {
        Ok(plaintext.iter().map(|byte| byte ^ 0xA5).collect())
    }

    fn unseal(&self, ciphertext: &[u8]) -> Result<Vec<u8>, VaultError> {
        Ok(ciphertext.iter().map(|byte| byte ^ 0xA5).collect())
    }
}

fn main() -> Result<(), VaultError> {
    let preferences = AccessibilityPreferences {
        text_scale_percent: 175,
        high_contrast: true,
        preferred_language: "en".to_owned(),
        reading_level: "plain-language".to_owned(),
        speech_rate_words_per_minute: 155,
        captions_enabled: true,
        tactile_confirmation_enabled: true,
    };

    let mut vault = PreferenceVault::new(
        DemonstrationEnclave,
        60 * 60,
    )?;

    vault.save(
        "demo-session",
        &preferences,
        1_700_000_000,
    )?;

    let restored = vault.load(
        "demo-session",
        1_700_000_180,
    )?;

    println!(
        "Loaded local preferences: text={}%, high_contrast={}, captions={}",
        restored.text_scale_percent,
        restored.high_contrast,
        restored.captions_enabled,
    );

    vault.delete("demo-session")?;

    Ok(())
}
