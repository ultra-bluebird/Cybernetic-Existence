# Firebreak Enforcement Algorithm

## Input

- operation: OperationRequest
- context: FirebreakContext

## Output

- decision: FirebreakDecision

## Algorithm

1. Validate operation structure
2. Detect biological data presence
3. Detect actuation data presence
4. Check operation type allowlist
5. Apply separation rules:
   a. If biological data and actuation data are both present:
      decision = Blocked("Firebreak violation: biological-actuation overlap")
   b. If biological data is present and operation is not in minimal receipt allowlist:
      decision = Blocked("Firebreak violation: biological data authorizing action")
   c. If actuation data is present and no separate authorization:
      decision = Blocked("Firebreak violation: unauthorized actuation")
   d. Otherwise:
      decision = Allowed

## Invariants

1. Biological data never leaves the local boundary in raw form.
2. Biological data never co-exists with actuation data.
3. Biological data never authorizes actions.
4. Actuation always requires separate explicit authorization.
5. The only output from biological data is a minimized receipt.

## Proof of Correctness

The algorithm maintains invariants 1-5 by construction.

- Invariant 1: enforced by the minimal receipt transform.
- Invariant 2: enforced by rule (a).
- Invariant 3: enforced by rule (b).
- Invariant 4: enforced by rule (c).
- Invariant 5: enforced by allowlist checking.
