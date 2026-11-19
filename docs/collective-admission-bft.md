# Collective Admission BFT Model

## Scope

This model describes a simulated distributed admission collective. It does not
claim to model, observe, operate, verify, or control real nanosystems,
biological systems, neural systems, or medical devices.

## Participant assumptions

Let N be the number of participants and f the maximum number of Byzantine
participants.

The protocol requires:

N >= 3f + 1

An acceptance or final-rejection quorum requires:

q_final = 2f + 1

A cautionary threat threshold requires:

q_caution = f + 1

## Decision outcomes

- ACCEPT: a fresh, bounded session capability may be issued.
- REJECT: the current proposal generation is denied.
- ABSTAIN: evidence is insufficient; no external authority is granted.

## Admission safety rule

ACCEPT is permitted only if:

- At least 2f + 1 eligible signed accept reports exist.
- All reports bind the same session id, generation, proposal hash, and policy version.
- No final-rejection quorum exists for that proposal generation.
- The requested authority is capability-bounded and lease-limited.

## Byzantine-report handling

A single report cannot force rejection because a Byzantine participant can lie.

A cautionary pause requires at least f + 1 independent eligible threat reports.

A final rejection requires at least 2f + 1 independent eligible threat reports.

## Forward-only finality

For each session id and generation, at most one final decision may exist.

A later request must use a new generation and complete fresh admission.
