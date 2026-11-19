# Locked Schema Catalog

| Schema | Version | Governing Objects | Canonical Form | Validator | Fixtures | Sensitive Boundary | Compatibility |
|---|---|---|---|---|---|---|---|
| ClaimRegister.v1 | v1 | 01–50 | Canonical Serialization v1 | Rust and Python | `tests/fixtures/claim-register/` | No direct identifiers or raw protected content | Additive fields only within v1 |
| EvidenceManifest.v1 | v1 | 24, 38, 43, 45 | Canonical Serialization v1 | Rust and Python | `tests/fixtures/evidence-manifest/` | Hashes and opaque references only for restricted sources | New major version for semantic changes |
| ConsentReceipt.v1 | v1 | 27, 28, 46 | Canonical Serialization v1 | Rego and schema validators | `tests/fixtures/consent/` | Full receipts remain controlled; public graph references are opaque | No silent scope expansion |
| CipherSuiteRegistry.v1 | v1 | 13, 30, 40 | Canonical Serialization v1 | Rust crate | `tests/fixtures/canonicalization/` | No secret keys, nonce values, or raw key material | Monotonic policy epoch |
| ProvenanceGraph.v1 | v1 | 24, 38, 43, 50 | Canonical Serialization v1 | Rust and Python | `tests/fixtures/provenance/` | Hashes, access classes, and opaque references only | Append-only supersession |
| TopologyHypothesis.v1 | v1 | 33, 48, 50 | Canonical JSON after YAML parsing | Rust parser | `tests/fixtures/topology/` | No raw telemetry or actuation instructions | Non-actuation invariant cannot be relaxed in v1 |
| OperationalResourceAccount.v1 | v1 | 23, 29, 49 | Canonical Serialization v1 | Rust and TypeScript | `tests/fixtures/resource-account/` | Computational units only; never physiological measures | Unit schedule version required |
