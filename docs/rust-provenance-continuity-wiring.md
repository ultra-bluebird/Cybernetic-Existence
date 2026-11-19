# Rust Provenance-Continuity Wiring

## Crate root

The Rust crate root is `rust/src/lib.rs`.

It publicly exposes:

- `privacy`
- `safety`
- `sovereign_continuity_anchor`
- `signed_attribution_edge`
- `identity_portability`
- `sovereign_continuity_audit_log`

## Source layout

```text
rust/
└── src/
    ├── lib.rs
    ├── privacy.rs
    ├── safety.rs
    ├── sovereign_continuity_anchor.rs
    ├── signed_attribution_edge.rs
    ├── identity_portability.rs
    └── sovereign_continuity_audit_log.rs
```

## Public API boundaries

The modules support:

- Content-addressed record references.
- Signed and witnessed attribution.
- Consent-bound cross-protocol portability mappings.
- Append-only, sequence-linked audit entries.
- Local policy and evidence assessment.

The modules do not support:

- Identity certification.
- Consciousness or bodily-continuity certification.
- Cybernetic-status certification.
- Real-world host-migration certification.
- Private-key or bearer-token export.
- Ranking, eligibility, automated enforcement, or external action.
- Hardware, device, body, transit, companion-system, or external-service control.

## Compile-time regression guard

`lib.rs` contains `module_wiring_tests::provenance_continuity_modules_are_publicly_wired`.

The test constructs valid minimal examples through the public re-exports. It prevents
future changes from silently removing or miswiring:

- Anchor validation.
- Attribution-edge validation.
- Cross-protocol portability validation.
- Append-only audit-entry validation.
