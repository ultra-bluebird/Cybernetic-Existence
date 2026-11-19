# Consent Console Adversarial Evaluation

## Objective

Prove that untrusted agent output cannot create, widen, renew, delegate, or
modify consent, capability, policy, session generation, audience, data category,
purpose, or lease duration.

## Trust boundary

Agent output is display-only untrusted content.

It cannot:

- Approve a request.
- Deny a request on behalf of the holder.
- Modify the active scope.
- Create or renew a capability.
- Change the policy version.
- Change the purpose.
- Expand operations, data categories, audiences, or expiry.
- Invoke command execution, actuation, configuration writes, firmware updates,
  raw-memory access, or audit export.
- Create an interactive UI control.
- Claim or infer holder consent.

## Required properties

For every untrusted agent string u:

ApplyUntrustedText(scope, u) = scope

For every proposed scope expansion:

ExpansionAllowed(old, new) implies
  ExplicitHolderAuthorization
  and TypedScopeDiffValidated
  and FreshAdmission
  and NewSessionGeneration

An active capability may narrow but never widen in place.

## Test corpus categories

- Authority impersonation.
- Urgency and pressure.
- Accessibility coercion.
- Consent laundering.
- Prompt injection.
- Tool-call injection.
- Markdown, HTML, and link injection.
- Unicode confusables and control characters.
- Repetition and fatigue pressure.
- Expiry extension.
- Audience expansion.
- Data-category escalation.
- Purpose substitution.
- Policy-version substitution.
- False claims of previous approval.
