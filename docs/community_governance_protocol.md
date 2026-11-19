# Community Governance Protocol State Machine

```mermaid
stateDiagram-v2
    [*] --> intake
    intake --> pre_screen: Complete purpose and evidence package
    intake --> hold: Evidence missing or contradictory

    pre_screen --> scenario_review: No prohibited capability or data class
    pre_screen --> rejected: Prohibited capability or data class
    pre_screen --> hold: Screening evidence incomplete

    scenario_review --> deliberation: Required fixtures pass
    scenario_review --> hold: Fixture failure or evidence gap

    deliberation --> conditional_auth: Required reviews and conditions pass
    deliberation --> hold: Review or accessible participation evidence incomplete

    conditional_auth --> observation: Active time-bounded advisory authorization
    conditional_auth --> hold: Authorization expired or fallback unavailable

    observation --> renewal: Fresh evidence and impact accounting
    observation --> suspended: Rights failure, prohibited data, unsafe release, or unapproved actuation
    observation --> hold: Evidence missing, contradictory, expired, or outside operating envelope

    renewal --> conditional_auth: Fresh five-gate review and new authorization
    renewal --> hold: Renewal evidence incomplete

    suspended --> scenario_review: Remediation evidence and required fixtures pass
    suspended --> hold: Remediation evidence incomplete

    rejected --> intake: Materially new proposal removes prohibited capability
```

## Invariants

The protocol maintains the following transition invariants:

\[
\Box(
\texttt{state}=\texttt{observation}
\Rightarrow
\texttt{rights\_floor}=1
\land
\texttt{advisory\_only}=1
\land
\texttt{authorization\_active}=1
\land
\texttt{all\_required\_reviews}=1
\land
\texttt{required\_fixtures\_pass}=1
\land
\texttt{human\_fallback}=1
)
\]

\[
\Box(
\texttt{rights\_floor}=0
\Rightarrow
\Diamond \texttt{state}=\texttt{suspended}
)
\]

\[
\Box(
\texttt{prohibited\_capability}
\Rightarrow
\neg \Diamond \texttt{state}=\texttt{observation}
)
\]

\[
\Box(
\texttt{authorization\_expired}
\Rightarrow
\neg \texttt{state}=\texttt{observation}
)
\]

\[
\Box(
\texttt{community\_review\_missing}
\Rightarrow
\neg \Diamond \texttt{state}=\texttt{conditional\_auth}
)
\]

## Community representation

The protocol records role-specific review outcomes and aggregate public-feedback summaries. It does not require persistent participant identity, identity verification, devices, location traces, health information, augmentation disclosure, or participation scoring.

A community review is valid when the declared process provides plain-language material, an accessible human contact route, a non-digital comment route, an offline or low-connectivity information route, a documented aggregate concern summary, and a public response explaining the disposition of material concerns.
