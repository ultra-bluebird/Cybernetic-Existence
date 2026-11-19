# Cyberdeck Threat Surface Enumeration

## Scope

This document enumerates major attack surfaces for a user-controlled,
offline-first Cyberdeck that hosts MSFP research, local continuity materials,
policy enforcement, receipt generation, and test tooling.

It does not claim control of real neural, medical, cybernetic, or nanoscale
systems. It does not infer personal identity, health, augmentation, credibility,
or eligibility from hardware, software, network, telemetry, or behavior.

## Asset Classes

- Encrypted local documents and source repositories.
- Local accessibility and communication preferences.
- Device-held cryptographic keys and public-key trust bundle.
- Session leases, generation counters, and revocation state.
- Policy artifacts and governance review records.
- Minimal audit records and consent receipts.
- Signed module releases, SBOMs, and compatibility records.
- Offline maps, contacts, checklists, and continuity documents.
- Local test vectors, formal models, and emulator outputs.

## Attack Surface Matrix

| Surface | Attack vector | Prevention | Detection | Containment and recovery | Formal claim |
|---|---|---|---|---|---|
| Physical enclosure | Theft, tampering, evil-maid attack, cold boot | Full-disk encryption, local lock, repairable tamper-evident enclosure, minimal secrets | Boot-integrity check, local tamper inspection | Invalidate external sessions, rotate keys, preserve encrypted local records | `unlocked_state requires local authorization` |
| Power | Malicious charger, brownout, power glitch, battery depletion | USB-C PD policy, surge protection, power-domain separation, battery health checks | Voltage/reset logs, watchdog reason code | Fail closed for external authority; preserve storage integrity | `power_fault => no protected release` |
| Input and peripherals | Malicious USB/HID, removable media, keyboard emulation, DMA device | Default-deny ports, disable Autorun, dedicated import mode, IOMMU where available, peripheral allowlist | Device-class mismatch, import audit, endpoint policy | Quarantine input, block external release, preserve local UI | `unapproved_peripheral => no privileged input path` |
| Display and accessibility I/O | UI redress, focus theft, inaccessible consent/revoke flow, deceptive overlays | Semantic UI, visible focus, high contrast, keyboard/switch path, local status role, no time pressure | Accessibility regression tests, focus traversal tests | Persistent revoke/disconnect path and local recovery instructions | `active_session => reachable_revoke_control` |
| Boot and firmware | Modified firmware, bootloader compromise, rollback attack | Verified boot, measured boot, signed updates, maintenance-only firmware path, recovery media | Measurement mismatch, signature failure | Block update, enter recovery, preserve local continuity | `unverified_firmware => no maintenance authorization` |
| Operating system | Kernel exploit, privilege escalation, malicious service, persistence | Minimal services, least privilege, sandboxing, read-only base where practical, timely verified updates | Integrity monitoring, process allowlist, anomalous privilege events | Isolate process, invalidate sessions, reimage from verified media | `compromised_process != protected_release` |
| Application runtime | Parser exploit, dependency confusion, unsafe plugin, script execution | Memory-safe language where practical, no dynamic plugin execution, dependency pinning, sandboxed inspector | Fuzzing, SCA, test corpus, crash telemetry without payload | Quarantine process, preserve audit minimality | `untrusted_frame => no execution path` |
| MSFP ingress | Oversized frame, duplicate/unknown field, replay, downgrade, ciphertext alteration | Size/nesting bounds, canonical encoding, strict schema, nonce replay cache, version pinning, AEAD | Parser tests, replay tests, signature failures | Reject before release, issue minimal reason code | `invalid_frame => no protected release` |
| Policy and capability engine | Policy substitution, authority expansion, stale grant, confused deputy | Signed policy bundle, capability attenuation, purpose/audience binding, per-release lease check | Policy digest check, attenuation tests, denied-expansion log | Block release, revoke generation, recovery witness | `final_scope subset_of granted_scope` |
| V-NIR/session hardware | Stale volatile state, reset race, DMA leakage, debug access | Reset-first design, address isolation, debug lockdown, independent TTL, hardware assertions | Formal RTL proof, reset test, debug-port test | Clear V-NIR, block authority, confirm Cold state | `terminal => vnir_zero and no_authority` |
| Network | Passive capture, active MITM, DNS manipulation, unsolicited traffic, Wi-Fi attacks | Offline-first default, opt-in network, mutual authentication, encrypted transport, network allowlist | Peer verification failures, unexpected egress alerts | End external session, retain local tools | `network_failure => local_continuity_available` |
| Supply chain | Compromised package, library, compiler, build runner, device component | SBOM, signed releases, pinned dependencies, reproducible builds where feasible, vendor review | Digest mismatch, provenance check, vulnerability monitoring | Reject artifact, recover known-good build | `accepted_component => digest_matches_manifest` |
| Maintenance | Ordinary-session escalation, forged grant, malicious update, local-presence bypass | Separate maintenance mode, narrow time-bound grant, local presence, artifact signature verification, independent log | Grant verification, challenge reuse check, update test | Reject update, invalidate maintenance grant, recovery witness | `ordinary_session => not firmware_update_authority` |
| Audit and receipt export | Raw-payload logging, receipt alteration, QR disclosure, export without review | Closed schema, encryption, hash-linked receipt, local QR generation, explicit export review | Schema validation, receipt hash verification, export audit | Block export, redact, preserve minimal local record | `audit_record excludes raw_payload` |
| Local storage and backup | Data exfiltration, rollback, deletion, backup compromise | Encryption, versioned backups, restore tests, deletion policy, encrypted offline backup | Restore verification, integrity hashes, retention job reports | Restore known-good local copy; do not restore active session authority | `backup_restore != session_resurrection` |
| Time and entropy | Clock rollback, weak randomness, stale status list, predictable nonce | Monotonic clock, TTL-HWC, CSPRNG readiness gate, signed status list, freshness limits | Clock anomaly, RNG health test, status freshness check | Deny new external release; retain local access | `time_or_rng_uncertain => no new external session` |
| Side channels | Timing, power, EM, acoustic, cache, screen observation | Constant-time cryptographic operations where applicable, secret isolation, shielding proportional to threat model, display privacy controls | Side-channel review and targeted evaluation | Rotate affected keys, limit secret lifetime | `secret_operation avoids data-dependent leakage where feasible` |
| Human and process | Coercion, phishing, rushed approval, misleading support request | Plain-language approval preview, no time pressure, selective disclosure, local revoke, human fallback | Review logs, usability/accessibility testing | Revoke, pause export, preserve correction/appeal path | `approval requires explicit local action` |

## Cross-Cutting Recovery Rule

```text
any security uncertainty =>
    deny new external release
    and clear volatile authority where required
    and preserve local baseline rights
    and show accessible local status
```

## Required Review Artifacts

- Threat model and data-flow diagram.
- SBOM and signed artifact digest.
- Dependency and compiler provenance record.
- Hardware/firmware measurement policy.
- Peripheral import policy.
- Key rotation and recovery plan.
- Formal model and negative test corpus.
- Accessibility task-completion results.
- Restore and offline-continuity test result.
- Incident/recovery runbook.
