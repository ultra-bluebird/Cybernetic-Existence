# Policy Architecture: Rego & Rust Integration

## Policy-as-Code (OPA)
The `/contracts/fairness.rego` file defines the high-level rules. The Rust daemon loads this policy at runtime to evaluate network requests and system signals against the Lex Augmentica.

## Enforcement Layers
1.  **Network Filter**: The `fairness-daemon` inspects outbound UDP/TCP packets. If a packet targets a known BCI telemetry port (5000-6000) and originates from a blacklisted IP (e.g., known corporate kill-switch servers), the daemon drops the packet and logs the incident.
2.  **Signal Handling**: The daemon intercepts SIGTERM. Instead of exiting, it executes the `fallback.sh` script, isolating the host from external networks while maintaining internal BCI bus activity.
3.  **Cookie Validation**: The `secure-session` crate validates all incoming `Set-Cookie` headers. Cookies without the `Secure` flag or with an expired timestamp are automatically discarded before reaching the browser's cookie jar.

## Verification
Run the policy tests against the live environment:
```bash
opa eval --data contracts/fairness.rego --input tests/mock_attack.json "data.fairness.allow"
