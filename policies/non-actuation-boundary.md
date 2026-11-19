# Non-Actuation Boundary

## Purpose

This policy limits repository artifacts to research, simulation, local analysis,
documentation, governance, and decision-support functions.

## Allowed effects

- Observe authorized inputs
- Derive approved features
- Simulate declared models
- Summarize permitted outputs
- Propose options for human review
- Log governance and integrity events
- Request authorized review

## Prohibited effects

- Autonomous physical actuation
- Autonomous body or device control
- Physical deployment instruction
- Coercive participation
- Override of local consent
- Override of a person's stated choice
- Identity, health, augmentation, capability, credibility, or eligibility inference
- Public CyberRank status publication
- Raw sensitive-data export outside authorized scope

## Invariant

\[
\operatorname{PermittedEffect}
\in
\{
\texttt{observe},
\texttt{derive},
\texttt{simulate},
\texttt{summarize},
\texttt{propose},
\texttt{log},
\texttt{request\_review}
\}
\]

Any unrecognized effect is prohibited by default.
