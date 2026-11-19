# Acceptance Pattern Index for Public Discourse

## Purpose

The Acceptance Pattern Index, abbreviated as API, is a monthly, aggregate measure of the public discourse environment surrounding cybernetic hosts and augmented citizens.

It measures patterns in public civic communication and eligible local media. It does not score individuals, identify cybernetic hosts, infer augmentation status, profile residents, track commentators, rank neighborhoods, or determine eligibility for services.

The API should be used to identify communication harms, representation gaps, institutional language needs, and opportunities for accessible public dialogue. It must not be used for policing, enforcement, platform moderation penalties, reputation scoring, political targeting, advertising, employment, insurance, benefits decisions, or surveillance.

## Data Boundary

Eligible sources:

- Public municipal announcements and meeting materials.
- Publicly available local journalism from participating or lawfully accessible sources.
- Community organization publications where permission or public availability supports use.
- Public consultation submissions only after aggregation, removal of direct identifiers, and an explicit data-use notice.
- Voluntary, privacy-preserving community surveys.

Excluded sources:

- Private messages.
- Non-public social-media posts.
- Direct messages, email, or private forums.
- Personal browsing history.
- Device identifiers.
- Location history.
- Face, voice, neural, biometric, health, or augmentation data.
- Law-enforcement intelligence.
- Employment, immigration, credit, benefit, insurance, or housing records.
- Individual-level demographic or identity inference.
- User-generated content tied to persistent person identifiers.

## Analysis Unit

The unit of analysis is a de-identified document or aggregate source-period cell, not a person.

Each record contains only:

```text
source_category
source_region
publication_month
document_language
topic_relevance_score
sentiment_score
rights_framing_score
stigmatizing_language_flag
source_weight
representation_cell
```

The `representation_cell` is a broad, community-approved aggregate source-coverage category. It can refer to geography, language availability, publication type, or participation channel. It must not identify individual demographic membership or attempt to infer a protected characteristic from text.

## Sentiment and Rights Framing

For document \(i\), define:

- \(p_i\): sentiment polarity in \([-1,1]\).
- \(r_i\): rights-aware framing score in \([0,1]\).
- \(s_i\): stigmatizing-language indicator, where one means a reviewed stigmatizing frame is present.
- \(q_i\): source-quality and relevance confidence in \([0,1]\).
- \(w_i\): source and sampling weight.

Convert polarity:

\[
P_i
=
\frac{p_i+1}{2}
\]

Compute document acceptance contribution:

\[
A_i
=
\operatorname{clip}
\left(
0.55P_i
+
0.35r_i
-
0.25s_i,
0,
1
\right)
\]

The rights-framing term prevents positive but objectifying or sensational language from receiving a high acceptance contribution. The stigma penalty prevents a highly visible hostile frame from disappearing inside an average.

## Representation Adjustment

Let \(g \in \mathcal{G}\) be community-approved aggregate representation cells, such as language-access channels, geographic service regions, publication formats, or civic participation routes.

Let:

- \(n_g\) be the number of eligible source documents in cell \(g\).
- \(N_g\) be the reference coverage target for cell \(g\).
- \(\rho_g\) be the representation weight.

\[
\rho_g
=
\operatorname{clip}
\left(
\frac{N_g}{n_g+\epsilon},
0,
\rho_{\max}
\right)
\]

The weighted monthly sentiment-and-rights score is:

\[
S_t
=
\frac{
\sum_{i \in \mathcal{D}_t}
w_i
\rho_{g(i)}
q_i
A_i
}{
\sum_{i \in \mathcal{D}_t}
w_i
\rho_{g(i)}
q_i
+
\epsilon
}
\]

This is a coverage correction, not demographic profiling. It prevents high-volume source categories from dominating the monthly result merely because they publish more frequently.

Representation bias can arise from historical discrimination, selection effects, and sampling bias in data collection; a documented correction and coverage audit are therefore necessary when using public discourse data. [190]

## Volume and Diversity

Let \(n_t\) be the number of eligible documents in a month and \(n_{\mathrm{ref}}\) be the reference minimum sample size.

\[
V_t
=
1 -
\exp
\left(
-\frac{n_t}{n_{\mathrm{ref}}}
\right)
\]

This volume confidence increases with evidence quantity but saturates so a large volume does not alone produce a high API.

Let \(p_{k,t}\) be the proportion of eligible documents from source category \(k\).

\[
D_t
=
-\frac{
\sum_{k \in \mathcal{K}}
p_{k,t}\ln(p_{k,t})
}{
\ln(|\mathcal{K}|)+\epsilon
}
\]

This normalized Shannon entropy measures source diversity. A month dominated by one institutional or media category receives a lower diversity score.

## Bias and Coverage Penalty

Let \(B_t\) represent the maximum observed disparity among representation cells:

\[
B_t
=
\max_{g \in \mathcal{G}}
\left|
S_{g,t}
-
S_t
\right|
\]

Where \(S_{g,t}\) is the weighted acceptance contribution for cell \(g\).

Let \(C_t\) be source coverage completeness:

\[
C_t
=
\frac{
|\{g \in \mathcal{G}: n_g \ge n_{\min}\}|
}{
|\mathcal{G}|
}
\]

The API is:

\[
API_t
=
Q_t
\cdot
\operatorname{clip}
\left(
0.55S_t
+
0.15V_t
+
0.20D_t
+
0.10C_t
-
0.20B_t,
0,
1
\right)
\]

Where \(Q_t\) is data-quality confidence, based on source provenance, classifier evaluation, human-review coverage, language coverage, and missing-data disclosure.

The bias penalty explicitly reduces the score when the discourse pattern differs materially across aggregate representation cells.

## Monthly Pipeline

- Define the eligible-source registry and publish inclusion criteria.
- Collect only lawful, public, opt-in, or properly authorized aggregate material.
- Remove direct identifiers and minimize metadata.
- Detect topic relevance without person-level inference.
- Score sentiment, rights framing, and stigmatizing language using a calibrated classifier.
- Conduct stratified human review across source, language, and representation cells.
- Calculate representation weights, volume confidence, diversity, coverage, and bias disparity.
- Produce API with uncertainty intervals and a source-coverage report.
- Publish aggregated findings, methods, limits, and recommended communication improvements.
- Delete or aggregate intermediate text according to the approved retention schedule.

## Human Review and Model Fairness

The model must be evaluated for:

- False positivity and false negativity of stigmatizing-language detection.
- Sentiment calibration across languages and locally relevant dialects.
- Disparity in model error across representation cells.
- Overrepresentation of high-volume publishers.
- Undercoverage of accessible formats, low-connectivity channels, and non-dominant languages.
- Whether the source registry excludes important community-controlled publications.
- Whether the report could expose a small community or person to stigma.

Fairness testing literature identifies both individual and group-fairness concerns in sentiment-analysis systems, and benchmark research has documented demographic bias in sentiment and emotion models. [193][198][200]

## Interpretation

| API interval | Interpretation | Institutional response |
|---|---|---|
| 0.00–0.24 | High discourse exclusion concern | Review public language, source gaps, stigma incidents, and accessible communication policies |
| 0.25–0.49 | Material acceptance and representation gaps | Fund community communication, accessibility, and civic-dialogue improvements |
| 0.50–0.74 | Mixed public discourse environment | Continue review and target the lowest-scoring source or representation dimensions |
| 0.75–1.00 | Strong aggregate acceptance pattern | Sustain inclusion, measure regressions, and continue independent community oversight |

The API describes public discourse patterns, not the worth, safety, credibility, or rights of cybernetic hosts or augmented citizens. A low API indicates a responsibility for institutions to improve conditions and communications; it must never justify reduced access or heightened monitoring of the people affected.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.90 | Uses transparent sentiment, rights framing, stigma detection, coverage correction, diversity, confidence, and disparity calculations |
| eco_impact_value | 0.34 | Indirect value through equitable planning and inclusion in public resilience and infrastructure programs |
| harm_risk | 0.22 | Reduced through aggregate-only analysis, source restrictions, no identity inference, human review, and retention limits |
| accessibility_impact | 0.94 | Measures language, source-format, low-connectivity, and accessible communication coverage |
| rights_alignment | 0.98 | Rejects profiling, surveillance, adverse service use, and demographic inference while supporting accountable public communication |
