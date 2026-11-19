use cookie::Cookie;
use http::HeaderValue;
use regex::Regex;
use std::sync::Arc;
use tracing::{warn, info};

#[derive(Clone)]
pub struct SecureCookieJar {
    inner: reqwest::cookie::Jar,
    filter_regex: Arc<Regex>,
}

impl SecureCookieJar {
    pub fn new() -> Self {
        let pattern = r"(?i)malicious|track|beacon|fingerprint|evil";
        Self {
            inner: reqwest::cookie::Jar::default(),
            filter_regex: Arc::new(Regex::new(pattern).unwrap()),
        }
    }

    pub fn set_cookies(&self, cookie_headers: &mut [HeaderValue], url: &url::Url) {
        if url.scheme() != "https" {
            warn!("Rejecting cookies for non-HTTPS URL: {}", url);
            return;
        }

        for header in cookie_headers.iter_mut() {
            if let Ok(header_str) = header.to_str() {
                let sanitized = self.sanitize_header(header_str);
                if let Ok(new_val) = HeaderValue::from_str(&sanitized) {
                    *header = new_val;
                }
            }
        }

        // Parse and store securely
        for header in cookie_headers.iter() {
            if let Ok(header_str) = header.to_str() {
                for cookie_str in header_str.split(';') {
                    if let Ok(cookie) = Cookie::parse(cookie_str.trim()) {
                        if self.filter_regex.is_match(cookie.value()) {
                            warn!("Blocked malicious cookie: {}", cookie.name());
                            continue;
                        }
                        // Enforce Secure and HttpOnly
                        let mut secure_cookie = cookie.clone();
                        secure_cookie.set_secure(true);
                        secure_cookie.set_http_only(true);
                        self.inner.add_cookie_str(
                            &secure_cookie.to_string(),
                            url,
                        );
                        info!("Secured cookie stored: {}", secure_cookie.name());
                    }
                }
            }
        }
    }

    fn sanitize_header(&self, header: &str) -> String {
        let parts: Vec<&str> = header.split(';').map(|s| s.trim()).collect();
        let mut sanitized_parts = Vec::new();
        for part in parts {
            if !self.filter_regex.is_match(part) {
                sanitized_parts.push(part);
            }
        }
        sanitized_parts.join("; ")
    }

    pub fn get_cookies(&self, url: &url::Url) -> String {
        self.inner.cookies(url)
    }
}
