# MSFP Synthetic Telemetry Dataset

## Purpose

This dataset is generated solely for parser, fuzzer, rate-limit, replay, schema,
and protected-dispatch tests.

## Privacy boundary

The dataset contains no real-person data and no records derived from real
telemetry.

It excludes:

- Identity data.
- Account data.
- Location data.
- Device fingerprints.
- Biometric data.
- Physiological data.
- Neural data.
- Medical data.
- Communication content.
- Communication style or behavioral timing data.
- Augmentation or institutional status.
- Private preference contents.

## Record semantics

Each row describes a synthetic protocol case. It contains only generated
identifiers, protocol classes, bounded integer fields, fixed operation labels,
fixed category labels, expected validation outcomes, and expected dispatch
behavior.

## Required test property

For every row where expected_dispatch is false:

protected_dispatch_count = 0

For every row where expected_dispatch is true:

protected_dispatch_count = 1

No row may cause an external action, hardware action, configuration mutation,
firmware update, raw-memory access, command execution, or actuation request.
