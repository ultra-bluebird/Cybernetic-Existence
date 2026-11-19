# Augmented-Hub SQLite Read API

## Purpose

This document defines the approved read-only query categories for AI-chat research
and local review tooling. Exact table names, view names, and column names must be
verified against `master.sql` before implementation.

## Approved query categories

- Discover SQLite schema objects.
- List open governance tasks.
- List published risk-budget policies.
- List non-sensitive governance objects.
- List evidence-bundle status records.
- List validation and test-result summaries.
- List unresolved review findings.
- List corridor policy summaries.
- List policy versions and validity states.

## Prohibited query categories

- Identity verification.
- Augmentation status verification.
- Personal profile construction.
- Biometric retrieval.
- Raw neural data retrieval.
- Device identifier retrieval.
- Credential retrieval.
- Session retrieval.
- Browser history retrieval.
- Automated task insertion.
- Database updates, deletes, schema alteration, extension loading, or attachment.
