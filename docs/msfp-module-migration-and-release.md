# MSFP Module Migration and Release Path

## Migration Wizard Requirements

Before enabling a module upgrade, the local migration UI must show:

1. The module name and version.
2. The declared purpose.
3. Data classes processed locally and exported externally.
4. Retention class and deletion plan.
5. New or changed capabilities.
6. Whether offline core behavior remains available.
7. Whether revoke, accessible status, correction, appeal, and human fallback remain available.
8. Accessibility changes: keyboard, status semantics, contrast, and motion.
9. Recovery plan and verified rollback/recovery availability.
10. The exact approval action required.

The UI must not use time pressure, preselected approval, dark patterns, or
mandatory cloud synchronization.

## Release Verification

Every module release requires:

- Versioned source and build inputs.
- Signed release artifact.
- SBOM.
- Artifact digest.
- Compatibility-matrix entry.
- Governance review record.
- Rights-regression test result.
- Accessibility test result.
- Security regression result.
- Recovery test result.

## Recovery

A verified return to a known-good artifact is allowed when integrity requires
it. A technical rollback must not remove local baseline rights.

```text
technical_recovery_rollback != rights_regression
```

## Compatibility Matrix

Record for each module version:

- Supported protocol versions.
- Supported policy versions.
- Required local storage schema version.
- Required status-list version, if applicable.
- Accessibility compatibility result.
- Known recovery path.
- Signed artifact digest.
- SBOM digest.
