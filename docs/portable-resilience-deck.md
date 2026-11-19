# Portable Resilience Deck

## Safe-Failure Contract

When an external session fails, expires, is revoked, or cannot authenticate:

- Block new external data releases.
- Destroy or invalidate volatile external session authority.
- Preserve access to locally stored maps, contacts, documentation, SBOMs,
  public-key bundles, checklists, and previously authorized local records.
- Display a plain-language local status message.
- Do not silently retry, upload queued records, or expand permissions.
- Do not convert audit records into renewed session authority.

## Minimum Offline Kit

- Offline maps for selected regions.
- Encrypted local contacts.
- Local emergency and continuity documentation.
- Current SBOMs for installed/relevant software.
- A public-key and certificate trust bundle with update date and expiry view.
- Disaster, heat, water, evacuation, and accessibility checklists.
- A recovery witness viewer.
- Local build and verification tools.

## External Failure Status

Use this text-first status pattern:

> External session unavailable or ended. No new external release will occur.
> Your local maps, contacts, documents, checklists, and verification records
> remain available under local access controls.

## Update Discipline

1. Review the available update.
2. Verify its source and signature according to the local trust policy.
3. Record the artifact version and digest in local inventory.
4. Apply the update during a chosen maintenance window.
5. Verify local availability after restart.
6. Preserve a recovery route that restores an authorized known-good state.

No system should assume that an external service will be available during an
emergency. Offline copies are maintained for continuity, not as claims that
they are always current.
