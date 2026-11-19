# MSFP Ephemeral Entropy and Teardown Requirements

## Scope

V-NIR is modeled as a protected volatile session buffer or enclave-local memory
region. This document does not claim universal physical data erasure or control
of biological, neural, medical, or cybernetic systems.

## Entropy requirements

A session key must have a 256-bit representation:

KeyLength(K_session) = 256 bits

The seed used to derive session keys must meet the required cryptographic
security strength:

H_min(seed) >= 256 bits

Session keys must be derived with domain separation over:

- Protocol version.
- Session identifier.
- Session generation.
- Deck binding.
- Protected-boundary binding.
- Purpose.
- Policy version.

## Prohibited V-NIR contents

V-NIR must not retain:

- Long-term private keys.
- Unencrypted personal data.
- Durable audit payloads.
- General command interfaces.
- Cross-session replay state.
- Capabilities after expiry or revocation.

## Teardown rule

A session termination event occurs at the earliest of:

- Lease expiry.
- User revocation.
- Policy revocation.
- Watchdog expiry.
- Integrity failure.
- Explicit local termination.

After a termination event:

- Session key handles are destroyed or invalidated.
- Session capabilities are revoked.
- Replay state is discarded.
- Ingress and egress are disabled.
- No external authority remains.
- A privacy-minimized teardown receipt is recorded.

## Teardown evidence

The receipt may include session pseudonym, generation, termination reason,
timestamps, policy version, and integrity measurement. It must not include raw
session keys, raw payloads, biometric data, neural data, or unnecessary
identity data.
