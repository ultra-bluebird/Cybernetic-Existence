# MSFP-LCC Rights-Baseline Lattice

## Purpose

This specification defines the rights baseline that must remain available when
an external MSFP session is denied, expires, is revoked, fails integrity
validation, or enters recovery.

The rights baseline is a governance and accessibility property. It is not a
public identity system, a CyberRank score, an eligibility criterion, a medical
assertion, or a technical verification of a person's self-description.

## Baseline Elements

```text
BaselineRights =
    LocalAccess
    Privacy
    AccessibleStatus
    Revoke
    Export
    Correction
    Appeal
    HumanFallback
```

## Ordering

For baseline sets `b1` and `b2`:

```text
b1 <= b2 iff every guarantee present in b1 is present in b2
```

Recovery must preserve or improve the baseline:

```text
TerminalState => BaselineRights(next) superset_of BaselineRights(current)
ConsentRevoked => BaselineRights(next) superset_of BaselineRights(current)
ExternalAnalysis => no_automatic_downgrade
```

## Baseline Guarantees

| Guarantee | Required local behavior | External failure behavior |
|---|---|---|
| LocalAccess | View local status, local documents, and preferences without network access | Preserved |
| Privacy | Minimum disclosure, purpose restriction, no raw hostile-payload retention by default | Preserved |
| AccessibleStatus | Plain-language text, semantic status, high contrast, reduced-motion-compatible UI | Preserved |
| Revoke | Local user-controlled external-session termination path | Preserved |
| Export | Holder-initiated selective export of permitted summaries or receipts | Preserved |
| Correction | Append-only correction of private governance records | Preserved |
| Appeal | Local dispute/review instructions and contact method | Preserved |
| HumanFallback | Offline support instructions and non-network termination explanation | Preserved |

## Terminal Recovery Sequence

```text
AuthorityOff
    < TrafficBlocked
    < EvidenceSeal
    < LocalAccessConfirmed
    < Cold
```

`Cold` means no active external authority, no active lease, no pending
protected release, no retained volatile plaintext, and no session
resurrection from an audit record.

## Prohibitions

- Do not remove local access merely because an external session ends.
- Do not require continuous network access for baseline rights.
- Do not require disclosure of identity, health, disability, augmentation,
  neural information, or technical inventory for baseline rights.
- Do not use CyberRank preferences as public status, verification, ranking,
  eligibility, diagnosis, or automated decision criteria.
- Do not treat a session failure as evidence about the person.
- Do not retain raw hostile payloads by default.
