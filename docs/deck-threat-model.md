# User-Controlled Deck Threat Model

## System Goal

Preserve local continuity, privacy, accessible control, and bounded authorized
operations while preventing a compromised deck, peripheral, update source, or
external session from obtaining unauthorized protected access.

## Protected Assets

- Encrypted local notes, maps, contacts, documents, and local source code.
- Cryptographic keys and trust bundles.
- Session and maintenance authorization state.
- Minimal audit records and consent receipts.
- Local accessibility preferences and control configurations.
- Integrity of software, policy, test vectors, and SBOMs.
- Availability of offline continuity materials.

## Trust Boundaries

1. Physical deck enclosure and storage.
2. External peripherals and removable media.
3. Deck operating system and local processes.
4. Update/package/artifact import path.
5. External network and MSFP gateway ingress.
6. Protected MSFP enforcement boundary.
7. Audit-vault storage and receipt export path.
8. Maintenance mode and firmware update interface.

## Threat Register

| Threat | Attack path | Primary controls | Verification evidence |
|---|---|---|---|
| Theft or loss | Physical possession of deck | Full-disk encryption, short local lock timeout, minimal local secrets, recovery plan | Lock-screen and offline-boot tests |
| Malicious peripheral | USB/HID/device emulation | Default-deny USB, disable Autorun, dedicated import workflow, no automatic execution | Peripheral regression test |
| Compromised OS | Malware gains local code execution | Least privilege, process separation, encrypted storage, integrity checks, protected boundary revalidation | Sandbox and privilege-boundary tests |
| Fake update | Tampered package or firmware artifact | Signed artifacts, trusted keys, digest verification, compatibility policy, maintenance-only path | Signature-negative test vectors |
| Replay | Captured message/grant reused | Nonces, expiration, one-time challenges, session binding, replay cache | Replay rejection tests |
| Denial of service | Oversized frames, request floods, storage exhaustion | Rate limits, size limits, allocation limits, bounded audit queue, offline local fallback | Load and fuzz tests |
| Overbroad maintenance | Ordinary session seeks elevated capability | Separate maintenance mode, local presence, narrow grants, independent logs | Policy denial tests |
| Audit disclosure | Logs expose payloads or private metadata | Closed schema, field allowlist, retention deletion, encrypted local vault, export review | Redaction tests |
| Receipt misuse | Printed/QR receipt replayed as authority | Receipt is non-authorizing, no bearer token, integrity hash only | Receipt parser rejects authorization use |
| Accessibility lockout | User cannot revoke or understand status | Keyboard/switch support, screen-reader status, persistent revoke path, local fallback | Modality task-completion tests |

## Security Invariants

```text
ordinary_session does not imply maintenance_authority
audit_record does not imply session_authority
receipt does not imply authorization
external_session_failure does not imply local_data_loss
compromised_deck does not imply protected_release
unverified_artifact does not imply installation
```

## Risk Review Cadence

- Review threats before a new external integration.
- Review maintenance rules before adding a new privileged capability.
- Run hostile-peripheral, replay, malformed-frame, update-signature, audit-redaction,
  and offline-continuity tests for every release.
- Record residual risks in plain language with a named mitigation owner.
