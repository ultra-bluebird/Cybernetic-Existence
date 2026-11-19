# Canonical Serialization v1

## Status

Normative for signed, hashed, content-addressed, or provenance-bound artifacts.

## Scope

This specification defines the canonical JSON byte representation used by:

- ClaimRegister.v1
- EvidenceManifest.v1
- ReproducibilityManifest.v1
- ProvenanceGraph.v1
- CipherSuiteRegistry.v1
- ConsentReceipt.v1
- OperationalResourceAccount.v1
- AssistiveIndexPreregistration.v1
- IntegratedT3AcceptanceCriteria.v1

## Canonicalization rules

1. Parse the input into a schema-valid typed value.
2. Exclude detached signature values from the signing payload.
3. Serialize values as UTF-8 JSON.
4. Sort object keys recursively by Unicode code point.
5. Emit no insignificant whitespace.
6. Preserve array order unless a schema defines a semantic set.
7. Require UTC timestamps with a `Z` suffix.
8. Require lowercase hexadecimal for SHA-256 digests.
9. Reject NaN, infinity, exponent notation, and floating-point values in signed artifacts.
10. Encode arbitrary-precision quantities as ASCII decimal strings.
11. Reject duplicate object keys before canonicalization.
12. Hash canonical UTF-8 bytes using SHA-256.

## Digest rule

\[
H(P) =
\operatorname{SHA256}
(
\operatorname{UTF8}
(
\operatorname{CanonicalJSON}(P)
)
)
\]

## Detached signature rule

A detached signature is computed over:

\[
\texttt{domain-separator}
\parallel
H(P)
\]

The signature field is excluded from \(P\).

## Security boundary

Canonicalization does not validate authorization, consent, evidence strength, or
semantic correctness. Those concerns must be validated by their corresponding
schemas and policy engines before canonicalization.
