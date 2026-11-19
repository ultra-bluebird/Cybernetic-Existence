# Local-First Organic Integration Policy

## Principle

The system is designed around user continuity, local control, and explicit
interoperability. It must not require a hidden cloud dependency or an automatic
external connection for core local functions.

## Local-first requirements

- The deck starts in offline state.
- Local preferences, policies, receipts, and recovery guidance are available
  without network access.
- A connection request requires a user-initiated action and active consent.
- An external session is temporary, purpose-bound, capability-limited, and
  revocable.
- A user can end an external session through a persistent local control.
- Network restoration never resumes a prior session automatically.
- Data export, synchronization, backup, and audit sharing require visible
  scope and explicit approval.
- External authority ends before local recovery begins.
- Local status and human fallback remain available during and after lockout.
- The system does not infer identity, health, augmentation, credibility, or
  eligibility from language, behavior, metadata, input method, or disclosure
  choices.

## Continuity invariant

If no network is available:

local_controls_available = true
local_preferences_available = true
recovery_guidance_available = true
external_authority_active = false

If an external session ends:

external_authority_active = false
local_controls_available = true
local_preferences_available = true
recovery_guidance_available = true
fresh_admission_required = true
