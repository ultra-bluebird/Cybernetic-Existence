# Consent Lens: Actionable Journey Research

The next advance is **actionable** access: distinguish a journey that exists in every modeled configuration from one a person can actually identify and complete using permitted information.

Repository: mk-bluebird/Augmented-Hub, and mk-bluebird/Skynet  
Filename: docs/research/consent-lens-actionable-journey-research.md  
Destination: docs/research/

SOVEREIGN-ATTRIBUTION: `bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`

Attribution is document credit only—not identity, consent, or authority.

Source boundary: This document develops the supplied journey-access and bounded-assurance models into a proposed research agenda. It does not report a new participant study, operational inspection, or deployed implementation.

## 1. Critical Inquiry: Ten Research Questions

The following partition separates workflow structure, evidence, feasibility, decision-making, burden, time, privacy, resilience, verification, and empirical evaluation. It covers this bounded research agenda, not every accessibility risk.

1. Workflow structure: When does the state \((q,r)\) omit information—such as saved progress or prior assistance—that changes which transitions are usable?

2. Evidence applicability: How should a passing transition evaluation transfer across changes in interface version, staffing, communication method, or operating conditions?

3. Dependency consistency: How can contradictory dependency declarations be detected before an empty feasible set produces misleading assurance?

4. Actionable choice: When a successful route depends on an unknown configuration, what permitted observations let someone choose it without inaccessible trial and error?

5. Participation burden: Can a technically successful journey impose unacceptable repeated entry, assistance demands, or switching costs?

6. Temporal feasibility: How do deadlines, queue delays, rest periods, and evidence expiry change journey completion?

7. Privacy preservation: Can every successful path require prohibited disclosure even though each individual task appears accessible?

8. Failure resilience: Which shared components can disconnect all usable journeys, and which genuinely independent fallbacks remove those bottlenecks?

9. Verification adequacy: Which defects evade endpoint-order tests, including incorrect witnesses, omitted exit checks, and incomplete dependency enumeration?

10. Empirical validity: Do modeled paths predict voluntary participants’ completion, recovery, and burden across documented communication conditions?

## 2. Conceptual Decomposition: Ten Formal Sub-Components

These are proposed analytical models; their operational criteria require local justification.

### 1. Sufficient Workflow State

Extend the state to:

\[
x=(q,r,m)
\]

where:

- \(q\) is task position.
- \(r\) is route.
- \(m\) is necessary workflow memory.

A state representation is sufficient when histories mapped to the same state permit the same future behavior:

\[
\phi(h_1)=\phi(h_2)
\Rightarrow
\operatorname{Future}(h_1)=\operatorname{Future}(h_2)
\]

Here, \(h\) is a prior interaction history, \(\phi\) is its state abstraction, and \(\operatorname{Future}(h)\) denotes the modeled feasible continuations.

Memory should describe necessary workflow conditions—not personal profiling.

### 2. Context-Matched Edge Evidence

For transition \(e\), evaluation context \(c\), and time \(t\):

\[
V_e(c,t)\in\{P,F,U\}
\]

where \(P\), \(F\), and \(U\) mean pass, fail, and unknown.

A previous pass transfers only when its dependency checks remain established:

\[
\operatorname{Transfer}_e(c')
=
\bigwedge_{d\in D_e}\operatorname{Valid}(d,c')
\]

Here:

- \(D_e\) is the reviewed dependency set.
- \(d\) is a required dependency.
- \(c'\) is the successor context.
- \(\operatorname{Valid}(d,c')\) is evaluated using pass, fail, or unknown.

Unknown dependency validity prevents an asserted pass; it does not establish failure. An empty or undocumented dependency inventory does not automatically establish transferability.

### 3. Nonempty Feasible-World Model

Let \(K\) be known evidence and \(\Gamma\) the dependency constraints:

\[
\Omega=\{\omega:\omega\models K\land\Gamma\}
\]

where \(\omega\) is a complete modeled configuration.

Require:

\[
\Omega\neq\varnothing
\]

before calculating extrema.

An empty set means inconsistent assumptions or evidence—not universal accessibility. A minimal inconsistent subset can help locate the contradiction.

### 4. Usable Policy Versus World-Specific Path

Distinguish:

\[
\forall\omega\in\Omega\;\exists\pi:
\operatorname{Success}(\pi,\omega)
\]

from:

\[
\exists\mu\;\forall\omega\in\Omega:
\operatorname{Success}(\mu,\omega)
\]

Here:

- \(\pi\) is a world-specific path.
- \(\mu\) is a policy choosing actions from permitted observations.
- \(\operatorname{Success}\) means completion under the declared task, transition, entry, exit, and other admissibility conditions.

The first statement does not imply the second. This distinction connects the model to planning under partial observability.

### 5. Non-Compensating Burden Constraints

For path \(\pi\), define:

\[
B(\pi)=
\left(
n_{\mathrm{reentry}},
n_{\mathrm{switch}},
t_{\mathrm{active}},
n_{\mathrm{assistance}}
\right)
\]

where:

- \(n_{\mathrm{reentry}}\) counts repeated information-entry events.
- \(n_{\mathrm{switch}}\) counts route changes.
- \(t_{\mathrm{active}}\) measures active participation time in a stated unit.
- \(n_{\mathrm{assistance}}\) counts required assistance episodes.

Each component measures a different burden. Require:

\[
B_k(\pi)\leq b_k
\]

for locally justified limits \(b_k\).

Assistance is not inherently a failure. The concern is unwanted, unavailable, or disproportionately burdensome assistance. Success in one burden dimension must not automatically offset failure in another.

### 6. Temporal Completion

For task duration \(d_i\), waiting time \(w_i\), and deadline \(D_i\):

\[
t_{i+1}=t_i+d_i+w_i
\]

\[
t_i+d_i\leq D_i
\]

Here, \(t_i\) is the start time of task \(i\), and all quantities use compatible time units.

Unknown durations produce unresolved temporal feasibility. Rest and communication time must be accommodated rather than presumed negligible.

W3C’s timing guidance emphasizes completion with individual response times.

### 7. Path-Level Disclosure Constraints

Let:

- \(L_e\) be the information categories required by transition \(e\).
- \(L_{\mathrm{allowed}}\) be the permitted categories.

Then:

\[
L(\pi)=\bigcup_{e\in\pi}L_e
\]

Require:

\[
L(\pi)\subseteq L_{\mathrm{allowed}}
\]

A path that succeeds only through prohibited disclosure is not an admissible journey.

This category check does not establish anonymity or eliminate inference risk.

### 8. Shared-Component Resilience

Let \(\mathcal C\) be the collection of component sets whose loss disconnects every admissible path. Define:

\[
\kappa=\min_{C\in\mathcal C}|C|
\]

where \(C\) is a component cut set and \(|C|\) is its size.

Count independent operational components, not merely interface edges. Two routes sharing one unavailable backend may provide no independent fallback.

This measure requires an explicitly defined component-failure model. It is not a general safety score.

### 9. Witness and Bound Correctness

For every returned witness \(\pi\), independently require:

\[
\operatorname{Entry}(\pi)
\land
\bigwedge_{v\in\pi}\operatorname{NodePass}(v)
\land
\bigwedge_{e\in\pi}\operatorname{EdgePass}(e)
\land
\operatorname{Exit}(\pi)
\]

where:

- \(v\) is a visited task–route state.
- \(e\) is a traversed transition.
- The entry, node, edge, and exit predicates use the declared evaluation criteria.

For small models, verify bounds against all feasible completions:

\[
L=\min_{\omega\in\Omega}g(\omega)
\]

\[
U=\max_{\omega\in\Omega}g(\omega)
\]

Here, \(g(\omega)\) is the binary access predicate for completion \(\omega\).

Endpoint ordering alone does not establish either equality.

### 10. Observed Completion With Missing Outcomes

For one predefined study condition, let:

- \(s\): observed successful journeys.
- \(f\): observed unsuccessful journeys.
- \(u\): unresolved outcomes.
- \(N=s+f+u\).

For \(N>0\):

\[
\frac{s}{N}
\leq
p_{\mathrm{eventual}}
\leq
\frac{s+u}{N}
\]

Here, \(p_{\mathrm{eventual}}\) is the eventual success fraction in that cohort, assuming observed classifications remain fixed and unresolved outcomes ultimately resolve.

These are cohort missing-outcome bounds, not confidence intervals.

Record assistance, recovery, and burden separately from completion. For \(N=0\), the fractions are undefined and must not be displayed as zero or 100%.

## 3. Strategic Augmentation: Ten Practical Assists

1. State-memory challenge. Construct paired histories ending at the same \((q,r)\) but with different saved progress or information availability. If their next-step feasibility differs, expand the state abstraction.

2. Transferability dossier. Attach tested context, dependency scope, validity, and change conditions to every transition claim. Start with synthetic version and staffing changes; do not presume that a renamed route preserves evidence.

3. Constraint-consistency review. Check feasibility before bounds. For contradictions, report the conflicting assumptions and request review rather than deleting whichever constraint makes the result inconvenient.

4. Observation-policy experiment. Test complementary routes whose working branch is initially hidden. Compare no cue, an accessible status cue, and human-supported guidance. Distinguish reaching the goal from recognizing that completion occurred.

5. Burden-aware path review. Compare feasible paths on separate burden dimensions rather than a single convenience score. Include repeated-entry walkthroughs; WCAG addresses reuse within a process but includes specific exceptions.

6. Temporal fault deck. Introduce queue delays, timeouts, pause/resume, and expired review evidence. Check that recovery preserves progress and does not require unnecessary disclosure.

7. Synthetic disclosure ledger. Annotate transitions with required information categories. Identify journeys that appear usable only because their privacy costs were omitted.

8. Common-cause fallback exercise. Remove a shared backend, staffing pool, or communication channel. Confirm that claimed alternatives remain independently usable—not merely differently branded.

9. Independent verification challenge. Give a second evaluator the specification, not the implementation. Introduce missing entry checks, reversed handoffs, corrupted witnesses, inconsistent constraints, and incomplete completion sets. Report detection by defect class.

10. Voluntary end-to-end replication. Evaluate complete correction journeys through multiple accessible communication conditions. Use task observations and participant feedback, not neural data or background monitoring. Preserve failures as evidence about the service, not the person.

## 4. Research Interpretation

The decisive example is complementary alternatives: every configuration may contain a successful route, yet no usable strategy exists if the person cannot discover which route works.

Accordingly, report three different findings:

- Structural possibility: a path exists in at least one feasible world.
- Robust path availability: every feasible world contains a path.
- Actionable completion: one permitted observation-based policy succeeds across the declared worlds.

These findings must not be substituted for one another.

## 5. Validation and Rights Boundaries

Begin with local, synthetic, non-actuating models.

Participant evaluation should be voluntary and provide accessible communication, assistance, breaks, correction, and withdrawal from optional research.

Do not require:

- Augmentation status.
- CyberRank disclosure.
- Neural recordings.
- Private companion-system details.
- Unnecessary medical information.
- Persistent cross-service tracking.

The model evaluates services and workflows—not personal competence, credibility, identity, or civic standing.

No result authorizes surveillance, service denial, medical-system operation, physical intervention, or person-level eligibility decisions.

## 6. Current Assessment

| Metric | Assessment |
|---|---|
| knowledge_factor | Formal research proposals with explicit assumptions; empirical validation remains necessary |
| eco_impact_value | Unmeasured; local synthetic evaluation avoids unnecessary live collection |
| harm_risk | Requires review of omitted state, dependency assumptions, observation policies, and disclosure burdens |
| accessibility_impact | Complete journeys, handoffs, recovery, and burden are explicit evaluation targets |
| rights_alignment | Equal access, privacy, non-interference, correction, and uncertainty remain separate requirements |

## 7. Supporting Sources

- Bertoli, Piergiorgio, Alessandro Cimatti, Marco Roveri, and Paolo Traverso. “Towards Strong Cyclic Planning under Partial Observability.” ICAPS 2006. https://cdn.aaai.org/ICAPS/2006/ICAPS06-039.pdf

- W3C Web Accessibility Initiative. “Understanding Success Criterion 3.3.7: Redundant Entry.” https://www.w3.org/WAI/WCAG22/Understanding/redundant-entry.html

- W3C Web Accessibility Initiative. “Understanding Guideline 2.2: Enough Time.” https://www.w3.org/WAI/WCAG22/Understanding/enough-time.html

The W3C Understanding documents provide informative explanations; they do not replace the normative WCAG requirements. The mathematical extensions in this document are proposed research models, not claims that these sources validate the complete architecture.
