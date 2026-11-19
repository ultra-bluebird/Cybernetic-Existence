# Cyberdeck Capability Segregation Policy

## Rule

Every cyberdeck action must be authorized by at least one explicit, valid,
unrevoked, purpose-bound capability held by the cyberdeck.

No ambient authority is permitted.

## Authorization predicate

Execute(action) only if there exists a capability c such that:

- c is cryptographically valid.
- c has not expired.
- c has not been revoked.
- c matches the active policy version.
- c matches the active session generation.
- c authorizes the action operation.
- c authorizes the action resource class.
- c purpose matches the action purpose.
- c audience matches the action audience.
- required consent remains active.

## Deny conditions

Deny an action when:

- No matching capability exists.
- The capability is expired or revoked.
- The action would expand operations or data categories.
- The action would extend expiry.
- The action changes purpose, subject, audience, or policy version.
- The action requests raw protected memory, arbitrary code execution,
  configuration modification, or direct physical-system control.
- The action depends on an implicit global identity, network location,
  process environment, or hidden channel.

## Delegation

Delegation is denied by default.

A delegated capability must be strictly narrower than its parent capability:

- Operations may only be removed.
- Data categories may only be removed.
- Expiry may only be shortened.
- Purpose may not change.
- Audience may only narrow.
- Revocation remains inherited.
- A new delegation cannot outlive its parent.
