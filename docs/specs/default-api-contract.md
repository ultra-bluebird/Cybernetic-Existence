# Augmented-Hub Default API Contract

## Scope

This contract defines the stable API vocabulary for local, identity-neutral,
evidence-bound, non-actuating Augmented-Hub components.

Every public module interface returns a structured result envelope. The envelope
does not grant identity verification, augmentation certification, clinical clearance,
legal compliance, deployment approval, firmware authority, or physical-system authority.

## Required result envelope

```json
{
  "apiVersion": "1.0.0",
  "operationId": "local-operation-reference",
  "status": "OBSERVE",
  "data": {},
  "findings": [],
  "provenance": {
    "inputArtifactIds": [],
    "transformationReceiptId": "local-receipt-reference"
  },
  "review": {
    "reviewRequired": false,
    "reviewOwner": "PROJECT_TEAM",
    "reviewStatus": "NOT_REQUIRED"
  },
  "limitations": [
    "This result is limited to supplied local artifacts and declared deterministic checks."
  ],
  "nonActuating": true,
  "identityNeutral": true
}
```

## Status vocabulary

- `OBSERVE`
- `HOLD_FOR_REVIEW`
- `ESCALATE`
- `PASSIVE_DESIGN_REVIEW`
- `REJECT`
- `NOT_CALCULATED`

## Required finding fields

```json
{
  "findingId": "local-finding-reference",
  "code": "MACHINE_READABLE_CODE",
  "severity": "INFO",
  "status": "OPEN",
  "decision": "HOLD_FOR_REVIEW",
  "summary": "Plain-language explanation.",
  "artifactReferences": [],
  "reviewRequired": true,
  "reviewOwner": "GOVERNANCE_OWNER"
}
```

## Mandatory safety fields

Every public result must include:

- `nonActuating: true`
- `identityNeutral: true`
- `limitations`
- `review`
- `provenance`

## Forbidden result values

The following values are not valid public API statuses:

- `ACTUATE`
- `ACTUATION_ALLOWED`
- `DEPLOYMENT_APPROVED`
- `HARDWARE_AUTHORIZED`
- `FIRMWARE_UPDATE_AUTHORIZED`
- `PERSON_SAFE`
- `MEDICALLY_CLEARED`
- `THERAPY_APPROVED`
- `IDENTITY_VERIFIED`
- `AUGMENTATION_CERTIFIED`
- `COMMUNITY_CONSENT_OBTAINED`
- `LEGAL_COMPLIANCE_CONFIRMED`
