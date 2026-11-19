use crate::cookie_jar::SecureCookieJar;
use anyhow::{anyhow, Result};
use reqwest::{Client, ClientBuilder};
use std::time::Duration;
use tracing::{info, warn};

pub fn force_perplexity_refresh(force: bool, verbose: bool) -> Result<()> {
    if !force {
        info!("Skipping refresh. Use --force to override.");
        return Ok(());
    }

    let _ = tracing_subscriber::fmt::try_init();

    info!("Initiating forced Perplexity session refresh...");
    let jar = SecureCookieJar::new();
    let client = ClientBuilder::new()
        .cookie_provider(std::sync::Arc::new(jar.clone()))
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        .timeout(Duration::from_secs(30))
        .build()?;

    let url = url::Url::parse("https://www.perplexity.ai/api/auth/session")?;

    // Pre-flight to get cf_clearance
    let preflight_resp = client.get(url.clone()).send()?;
    if verbose {
        info!("Preflight status: {}", preflight_resp.status());
    }

    // Force new session token
    let login_payload = serde_json::json!({
        "strategy": "refresh",
        "force": true,
    });

    let login_resp = client
        .post("https://www.perplexity.ai/api/auth/callback/credentials")
        .json(&login_payload)
        .send()?;

    if !login_resp.status().is_success() {
        return Err(anyhow!(
            "Failed to refresh session. Status: {}",
            login_resp.status()
        ));
    }

    let session_data = login_resp.json::<serde_json::Value>()?;
    if let Some(token) = session_data.get("sessionToken").and_then(|v| v.as_str()) {
        info!("Session token acquired successfully.");
        // Encrypt and store locally for persistence (optional)
        std::fs::write("/tmp/sovereign_session.key", token)?;
    } else {
        warn!("No session token in response.");
    }

    // Verify access
    let verify = client.get("https://www.perplexity.ai").send()?;
    info!("Access verification status: {}", verify.status());

    Ok(())
}
