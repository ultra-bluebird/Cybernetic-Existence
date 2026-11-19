# Hearthline Account Continuity Policy

## Purpose

Hearthline uses passkey-first access and multi-path account continuity. It does not
use passwords as a normal sign-in method or as an account-recovery fallback.

Account continuity is designed to help a person regain secure access after device
loss, authenticator loss, or access disruption without converting recovery into a
silent account-takeover path.

## Normal Access

```text
Passkey with user verification
→ authenticated session
→ current policy checks for sensitive actions
```

Hearthline does not ask users to create, memorize, rotate, or reset a password.

## Continuity Paths

```text
- Existing secondary passkey
- Registered hardware security key
- Offline single-use continuity code
- Optional account-support contact co-sign
- Privacy-minimized re-proofing
- Optional advanced multi-party continuity
```

No continuity path may read messages, profiles, matches, consent scopes, recovery
context, health information, credentials, recovery codes, or account history.

## Continuity Ceremony

```text
CONTINUITY_REQUESTED
→ CONTINUITY_PATH_SELECTED
→ EVIDENCE_VALIDATED
→ RISK_REVIEW
→ NEW_AUTHENTICATOR_BINDING
→ INDEPENDENT_NOTIFICATION
→ COOLDOWN_ACTIVE
→ CONTINUITY_COMPLETED
```

A new authenticator requires user verification on the new device.

## Preserved Controls

During limited access or continuity:

```text
- Pause activity
- Stop future sharing
- Block or mute
- Submit a report
- End the current session
- Clear local data
- View generic security history
- View generic continuity guidance
```

## Restricted Controls

Until current high-assurance access is restored:

```text
- Sending messages
- Starting new connections
- Expanding disclosure
- Revealing contact details
- Linking providers
- Exporting account data
- Changing account-support contacts
- Changing recovery methods outside the active ceremony
```

## Notifications

When a new authenticator is added or an account-continuity ceremony changes state,
Hearthline sends generic notifications to surviving configured channels where
available.

Notifications never contain:

```text
- Credential identifiers
- Continuity codes
- Recovery-contact names
- Device inventory
- Recovery pathway details
- Profile or message content
- Recovery or health information
```

## Non-Goals

Hearthline does not:

```text
- Certify recovery status
- Use recovery information for account continuity
- Require a sponsor, clinician, family member, or support contact
- Require legal-name identity for ordinary access
- Use password fallback
- Use knowledge-based security questions
- Use SMS as an equivalent sign-in or continuity method
- Create a public trust or verification signal from continuity completion
```
