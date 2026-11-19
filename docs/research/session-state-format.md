# Session State Declaration Format

Format version: 1

## Required batch-ending block

Use these field names and order:

Session state:
  Format version:
  Scope:
  Delivered work:
  Verification:
    Compilation:
    Integration:
    Evidence authentication:
    Repository installation:
  Next batch:
  Standards in force:
  Repositories:
  Destinations:
  Pending hardening:
  Continuity limitations:

## Semantics

Delivered work means artifacts were supplied in the response.
It does not mean compilation, test execution, installation, or deployment.

Verification entries use:
- not_executed;
- reported_pass;
- reported_fail;
- not_established.

Each reported result must identify its evidence basis elsewhere.

Use descriptive work labels, not numbered object identifiers.

Do not place private profiles, drafts, companion details, credentials,
personal identities, or raw scene data in the declaration.

## Resume behavior

A declaration preserves coordination metadata.
It does not supply source code that is absent from the receiving context.

On resume:
- preserve known limitations;
- do not infer test success;
- do not reconstruct private content;
- identify missing artifacts before editing;
- retain protective defaults when prior state is unknown.
