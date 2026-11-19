# Mutuality Receipt Cryptographic Boundary

## Initial implementation

Use an opaque, signed, short-lived receipt reference.

The verifier asks the authoritative Hearthline service whether the receipt remains
active for the exact purpose and scope. The service returns only the minimum
current predicate result.

## Optional future implementation

A zero-knowledge or selectively disclosable presentation may prove a minimal
predicate without revealing unrelated information.

Example:

> The holder has a currently active direct-conversation consent receipt for this
> exact conversation scope until this expiry time.

## Mandatory constraints

- No public ledger.
- No blockchain publication.
- No public DID document required.
- No persistent cross-feature subject identifier.
- No transferable reputation token.
- No accumulated history.
- No public proof gallery.
- No proof of safety, trust, desirability, or absence of reports.
- No exclusion of members who choose the ordinary non-cryptographic path.
- Immediate revocation check for every sensitive capability.
