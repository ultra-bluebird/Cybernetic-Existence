# Deck Suite: Recovery, Privacy, Field Research, Accessibility, and MSFP

## Purpose

This specification defines five complementary local-first decks:

1. Recovery Witness Deck
2. Minimal Privacy Deck
3. Field Research Deck
4. Accessibility-First Deck
5. MSFP Research Deck

Each deck is a user-operated computing environment. It provides information,
local controls, encrypted storage, accessible interaction, and accountable
records. It is not an identity verifier, medical or neural system controller,
eligibility assessor, surveillance device, or remote override mechanism.

## Shared Principles

- Local operation is the default.
- Cloud synchronization is optional and must require a separate, explicit user action.
- Protected records use encrypted local storage.
- Audit records are purpose-limited and minimize retained data.
- Radios, location services, sensors, and external export are disabled or unavailable unless deliberately enabled for a defined task.
- The deck may display status and prepare requests, but protected MSFP services independently enforce authentication, policy, lease state, and release constraints.
- Every protected action has an accessible local status result.
- A restart never restores active session authority from local audit history.

## Shared Safety Properties

For all decks:

\[
\operatorname{release}(d) \Rightarrow
\operatorname{authenticated}(d)
\land \operatorname{policy\_permitted}(d)
\land \operatorname{lease\_active}(d)
\]

\[
\operatorname{cloud\_transfer}(x) \Rightarrow
\operatorname{explicit\_export\_approval}(x)
\]

\[
\operatorname{restart} \Rightarrow
\neg \operatorname{restore\_active\_session}
\]

\[
\operatorname{telemetry\_sent} =
0
\quad \text{unless a user-approved export operation is active}
\]
