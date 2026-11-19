# Hearthline M2 Progress and Wiring

## Status

**Milestone:** M2 — Repository Hardening  
**Status:** Implemented; validation pending an environment with installed Node dependencies.  
**Next gate:** Run the full test and build suite before adding production services.

The recorded hardening session could parse `package.json`, but it could not run Vitest
or Vite because `node_modules` was unavailable in that environment. This is not a
source-code pass or failure result.

## M2 Completed Work

- Package metadata uses the Hearthline Starter identity.
- A component registry documents allowed module read relationships.
- A forbidden-data guard rejects sensitive identity, health, recovery, credential,
  reputation, and behavioral-profiling keys.
- Audit helpers use content-free event templates.
- Local storage uses the `hearthline-starter:` namespace.
- Local export sanitization excludes drafts, messages, recipients, candidates,
  consent data, persona data, internal audit references, and credential details.
- Browser passkey inspection remains informational only.
- Startup validates the component registry before rendering normal application UI.
- Privacy, threat-model, accessibility, browser-support, milestone, and release
  documents are present.
- A non-deploying GitHub Actions quality workflow is present.

## Validation Still Required

```text
[ ] npm ci in an approved dependency-present environment
[ ] npm run test
[ ] npm run build
[ ] Component registry import validation
[ ] Forbidden-data guard validation
[ ] Audit event call-site compatibility check
[ ] Browser refresh persistence check
[ ] Local reset check
[ ] Sanitized export check
[ ] Keyboard-navigation check
[ ] Startup-error UI check
```

## Canonical Wiring

```text
main.jsx
→ validates component registry once
→ renders App on success
→ renders a generic local error state on validation failure

App and pages
→ useHearthlineStore
→ local state and localStorage

useHearthlineStore
→ consent
→ matching
→ message assistant
→ integrity
→ persona
→ audit
→ passkey capability inspection

storage
→ forbidden-data guard
→ safe local export

audit
→ content-free event templates
→ generic user-readable history

component registry
→ documents and tests forbidden data-flow relationships
```

## Protected Boundaries

```text
TrueCompass cannot read Lantern, recovery-expression, or recipient-persona data.
Lantern cannot read recovery-expression or recipient-persona data.
Recovery-expression and recipient-persona modules cannot read Lantern data.
Audit events cannot include private content, recipient references, field names,
credentials, recovery material, health data, or person-score values.
Local export cannot include drafts, messages, recipient mappings, persona mappings,
consent details, audit references, or credential capability details.
```

## Compile-Safety Rules

```text
- Preserve existing function exports until every call site has been migrated.
- Prefer compatibility aliases for renamed audit event types.
- Keep component policy checks in dependency-free modules.
- Keep browser capability inspection informational only.
- Import the storage prefix from one shared module; do not duplicate it.
- Do not add a backend client directly to React pages.
- Do not add network activity to local data helpers.
- Add tests before changing behavior in consent, matching, persona, audit, storage,
  or message-drafting modules.
- Run test and build checks after each focused change.
```

## M2 Exit Criteria

```text
[ ] All Vitest suites pass.
[ ] Vite production build passes.
[ ] Component registry validation passes.
[ ] Forbidden-data guard validation passes.
[ ] No existing page fails because of renamed audit event types.
[ ] Startup error state exposes no technical internals.
[ ] Local export remains sanitized.
[ ] README and documentation accurately describe a local demonstration.
[ ] GitHub Actions workflow is present and non-deploying.
```

## Next Pathway

The next implementation milestone after M2 is not real messaging or third-party
integration. It is a production-foundation contract layer:

```text
src/contracts/
  identityAccessContract.js
  consentDecisionContract.js
  connectionTransitionContract.js
  auditEventContract.js
```

The contract layer will let the current local implementation remain usable while
future server-authoritative implementations are introduced behind stable adapters.

No production identity, messaging, recovery, provider linking, proof presentation,
or guardian delivery feature is considered implemented until the relevant server
contracts, security review, privacy review, and integration tests exist.
