# Assistive Continuity Policy

## Principle

External-session security controls must not remove local control, accessible
status, communication access, or configured human fallback.

## Required interface properties

- All controls are keyboard operable.
- No keyboard trap is permitted.
- Focus is always visible and not obscured.
- Session status has semantic programmatic exposure.
- Critical session termination is announced through a nonvisual-capable alert.
- Alerts remain available in local history after announcement.
- Color, sound, vibration, animation, and timing are never the sole means of
  communicating a security state.
- Revoke control uses unambiguous language and remains reachable while an
  external session is active.
- Consent is never inferred from inactivity, response speed, input method,
  writing style, fatigue, repetition, or communication variation.
- A session ending does not remove local access or configured human fallback.
- Technical detail is optional and follows a plain-language summary.

## External authority rule

Ending an external session must result in:

external_authority = false
local_controls_available = true
accessible_status_available = true
human_fallback_available = true
fresh_admission_required = true
