# Monotonic Segment Date-Hash Protocol

## Purpose

This protocol preserves an append-only predecessor-root chain when wall-clock time
is skewed, corrected, unavailable, or moves backward.

It uses monotonic segment serials as commitment identity and treats civil dates as
reporting metadata. It does not claim that an artifact's civil-time label is a
trusted timestamp. Trusted timing evidence remains a separate, declared channel.

## Segment identity

Each emitted artifact is identified by:

- `ledger_id`: stable identifier for one ledger epoch;
- `segment_serial`: non-negative integer allocated exactly once;
- `commitment_profile_id`: immutable identifier for canonical-record and tree rules;
- `prev_segment_root`: predecessor artifact root;
- `segment_root`: deterministic root for fixed segment membership;
- `close_reason`: interval, record_limit, size_limit, manual, reconfigure, recovery,
  or shutdown;
- `elapsed_open_ms`: non-decreasing elapsed-time reading at open;
- `elapsed_close_ms`: non-decreasing elapsed-time reading at close;
- `utc_reporting_label`: optional UTC calendar label for discovery and reporting;
- `clock_status`: trusted, estimated, skew_detected, unavailable, or recovered.

The pair `(ledger_id, segment_serial)` is authoritative for chain position.
The UTC reporting label is not authoritative for chain position.

## Genesis rule

The first artifact in a ledger epoch has:

- `segment_serial = 0`;
- `prev_segment_root` equal to 32 zero bytes encoded according to the active
  commitment profile;
- a fixed and recorded `commitment_profile_id`.

## Successor rule

For every non-genesis artifact `n`:

`artifact[n].segment_serial = artifact[n - 1].segment_serial + 1`

`artifact[n].prev_segment_root = artifact[n - 1].segment_root`

No wall-clock reading may change this relationship.

## Clock-skew rule

Wall-clock timestamps may move backward, jump forward, be unavailable, or disagree
with another time source. Such events MUST NOT:

- decrement `segment_serial`;
- reopen a closed segment;
- change a sealed artifact;
- change fixed segment membership;
- reuse a serial;
- replace `prev_segment_root`;
- cause records to migrate into a previously closed segment.

A producer MAY assign a repeated or later UTC reporting label to multiple consecutive
segments. It MUST record the applicable `clock_status` and observed offset or reason.

## Admission rule

Membership is determined at a durable admission linearization point using a
non-decreasing elapsed-time source and the open segment's fixed closure policy.

Record-carried device time, source arrival time, and wall-clock ingest time are
metadata. They MUST NOT select segment membership.

## Recovery rule

When elapsed-time continuity is uncertain because of restart, suspend, failover, or
clock-source fault, the producer MUST stop normal admission.

Before accepting new records, it MUST either:

1. recover durable open-segment membership and close that segment with
   `close_reason = recovery`; or
2. begin a new ledger epoch without reusing an earlier ledger identifier or serial.

The producer MUST NOT infer a missed historical boundary from wall-clock time.

## Date-path rule

For discoverability, artifacts MAY be mirrored under:

`segments/<ledger_id>/<segment_serial>/segment.cbor`

and MAY have a non-authoritative date index:

`date-index/<utc_reporting_label>/<ledger_id>-<segment_serial>.json`

The canonical artifact path MUST be segment-serial based.

A date index is a projection. It MUST NOT be an input to root computation or
predecessor selection.

## Verification rule

A verifier MUST:

1. verify a supported commitment profile;
2. verify each artifact root from its disclosed canonical input;
3. verify `segment_serial` continuity;
4. verify each `prev_segment_root` equals the immediately preceding verified root;
5. report UTC-label irregularities separately from chain-integrity results;
6. reject an artifact with an unsupported profile, repeated serial, serial gap,
   mismatched predecessor root, or altered canonical bytes.

A successful chain check proves commitment ordering and artifact linkage only.
It does not prove the physical truth, completeness, origin, or safety implications
of the underlying telemetry.
