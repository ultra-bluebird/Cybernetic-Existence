# MSFP Lockout Continuity Model

## Purpose

Automated external-session lockout must remove external authority while
preserving local access, accessible status, and human fallback.

## Required ordering

1. Remove external session authority.
2. Block ingress and egress for the terminated session generation.
3. Invalidate session keys and capabilities.
4. Write a privacy-minimized termination receipt.
5. Confirm local controls and accessible status remain available.
6. Enter Cold state.
7. Require fresh admission for any future external session.

## Continuity requirements

During every external lockout state:

- Local controls remain available.
- Accessible plain-language status remains available.
- A local recovery action remains available.
- A human fallback route remains available where configured by the holder.
- No raw payload is required to obtain recovery information.
- No private physiological, medical, neural, biometric, or institutional data is required.

## Measurements

Record only privacy-minimized aggregate metrics:

- Lockout trigger time.
- Local-status availability time.
- Local-control availability time.
- Human-fallback availability time.
- New-admission availability time.
- Lockout duration.
- Recovery outcome.
- Reason-code class.
- Policy version.

Do not record raw payloads or infer personal traits from lockout events.
