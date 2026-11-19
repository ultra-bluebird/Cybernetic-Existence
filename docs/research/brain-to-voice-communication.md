# Brain-to-Voice Communication

## Purpose

Brain-to-voice communication translates measured brain activity associated
with attempted speech into audible synthetic speech.

The central research objective is **closed-loop** communication: the person
hears the generated speech and can adjust subsequent speech attempts,
expression, timing, and stopping behavior.

This document distinguishes demonstrated scientific results from proposed
engineering requirements. It does not describe a deployed Augmented-Hub
medical device, provide implantation instructions, or authorize access to
neural, medical, or companion systems.

## Evidence and Scope

Human research has demonstrated streaming speech synthesis from cortical
surface recordings and expressive voice synthesis from intracortical
recordings.

These demonstrations establish feasibility under particular recording,
training, and experimental conditions. They do not establish unrestricted
access to private thought, universal decoding accuracy, or suitability for
every person.

The mathematical models below are explanatory engineering formulations.
Unless explicitly stated otherwise, they are not exact reconstructions of
the cited research implementations.

## Terminology

| Term | Definition |
|---|---|
| Brain–computer interface, or BCI | A system that converts measured brain activity into communication or another output. |
| Speech neuroprosthesis | An assistive system intended to support or restore speech communication using nervous-system signals. |
| Attempted speech | Trying to produce speech, including when intelligible vocal output is prevented by paralysis or impaired motor control. |
| Imagined speech | Internally imagining speech without necessarily attempting its physical production; a distinct research target. |
| Anarthria | Loss of the ability to articulate speech; this does not by itself establish loss of language comprehension or communicative intention. |
| Dysarthria | A motor-speech disorder affecting speech production, with varying features and severity. |
| Electrocorticography, or ECoG | Recording electrical activity using electrodes placed on the cortical surface. |
| Intracortical recording | Recording using electrodes that penetrate cortical tissue. |
| High-gamma activity | A relatively high-frequency component of cortical activity used in some speech-decoding systems; approximately 70–150 Hz is a commonly studied band. |
| Phoneme | A language-specific speech-sound category that can distinguish words. |
| Articulatory representation | A representation of speech-production features, such as tongue or lip configuration. |
| Mel spectrogram | A time–frequency sound representation using perceptually motivated frequency spacing. |
| Vocoder | A synthesis system that converts acoustic representations into an audible waveform. |
| Prosody | Intonation, rhythm, stress, and timing that contribute to expression and meaning. |
| Streaming decoder | A decoder that produces successive outputs while new input continues to arrive. |
| Causal model | A model using current and past inputs rather than unavailable future inputs. |
| Look-ahead | Future context deliberately buffered before generating output, introducing additional delay. |
| Calibration | Training or adapting the mapping between recorded signals and communication targets. |
| Signal drift | Changes in recorded signal characteristics over time. |
| Fallback communication | An alternative, user-selected communication method available when a primary interface is unsuitable or unavailable. |

Surface electromyography measures muscle activity rather than brain
activity. It can support related silent-speech interfaces but must not be
labeled direct neural recording.

## Demonstrated Research Foundations

### Streaming Speech From Cortical-Surface Recordings

Littlejohn and colleagues reported a streaming brain-to-voice system using
high-density surface recordings from speech sensorimotor cortex in a
participant with severe paralysis and anarthria.

The study used recurrent neural network transducer models, decoded in
80-millisecond increments, and personalized synthesis to the participant's
preinjury voice.

An 80-millisecond decoding increment does not mean that total
intention-to-audio latency was 80 milliseconds.

NIH reported:

- 47.5 words per minute in the study's larger-vocabulary condition.
- 90.9 words per minute in a smaller, 50-word condition.

These figures describe different task conditions and must not be treated as
equivalent unrestricted-conversation benchmarks.

Sources:

- Littlejohn et al., “A streaming brain-to-voice neuroprosthesis to restore
  naturalistic communication.”
  https://www.nature.com/articles/s41593-025-01905-6
- PubMed record:
  https://pubmed.ncbi.nlm.nih.gov/40164740/
- NIH research summary:
  https://www.nih.gov/news-events/nih-research-matters/brain-computer-interface-restores-natural-speech-after-paralysis

### Expressive Voice From Intracortical Recordings

A separate 2025 study demonstrated voice synthesis using 256
microelectrodes implanted in the ventral precentral gyrus of a participant
with ALS and severe dysarthria.

The participant received closed-loop audio feedback and demonstrated
control over aspects of intonation and short sung melodies.

This result distinguishes intelligible word production from expressive
voice control. It does not establish that every expressive feature is
reliably decoded in unrestricted daily use.

Sources:

- “An instantaneous voice-synthesis neuroprosthesis.”
  https://www.nature.com/articles/s41586-025-09127-3
- PubMed record:
  https://pubmed.ncbi.nlm.nih.gov/40506548/

### General Scientific Background

The speech-neuroprosthesis literature describes neural recording,
speech-related cortical representations, decoding strategies, synthesis,
and evaluation.

Source:

- “The speech neuroprosthesis.”
  https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11540306/

## Proposed Use-Case Scenarios

The scenarios below are engineering proposals informed by research.
They are not claims of validated deployment.

### Everyday Conversation

A person uses streaming synthesized speech to participate in conversation.

Requirements:

- An accessible way to enable the communication mode.
- Immediate access to mute, cancel, and correction.
- Optional text display.
- A user-selected alternative communication method.
- No automatic substitution of suggested wording for intended wording.

Evaluation:

- End-to-end latency.
- Listener intelligibility.
- Unintended output.
- Correction effort.
- User-reported conversational agency.

### Appointments and Personal Care

A person communicates requests, preferences, questions, and disagreement.

The interface must distinguish:

1. A decoder-generated candidate.
2. Output emitted through an enabled communication mode.
3. A statement explicitly confirmed for a consequential record or action.

A decoded statement alone must not be treated as authorization for
treatment, financial action, account access, or disclosure.

### Expressive Social Participation

A person selects a voice and controls supported expressive features.

Requirements:

- Voice selection remains voluntary.
- Recreating a previous voice is optional.
- A synthetic or newly selected voice is not treated as less authentic.
- Inferred emotion is not presented as an authoritative account of the
  person's internal state.

### Remote Work, Education, and Civic Participation

A proposed local interface supplies speech to an optional conferencing
application.

Keep these stages separate:

1. Signal acquisition.
2. Local decoding.
3. Local audio output.
4. External transmission.
5. Recording or transcription.

Authorization for one stage does not automatically authorize another.

## Technical Architecture

A generalized processing chain is:

Attempted speech
→ recorded neural activity
→ validated preprocessing
→ feature extraction
→ causal encoder
→ speech representation
→ voice synthesis
→ permitted output
→ audible feedback.

Accessible cancel controls and fallback communication should be available
across the processing chain.

### Signal Acquisition

Let the recorded sample be:

\[
\mathbf{x}[n]\in\mathbb{R}^{C},
\]

where \(C\) is the number of recording channels.

For sampling rate \(f_s\), in samples per second:

\[
t_n=\frac{n}{f_s}.
\]

An approximate measurement model is:

\[
\mathbf{x}[n]
=
\mathbf{s}[n]
+
\mathbf{a}[n]
+
\boldsymbol{\epsilon}[n],
\]

where:

- \(\mathbf{s}[n]\): neural contribution represented in the recording.
- \(\mathbf{a}[n]\): artifacts.
- \(\boldsymbol{\epsilon}[n]\): remaining measurement noise.

This additive expression is not a complete physical model of the
electrode–tissue interface.

ECoG and intracortical signals require recording-specific preprocessing.
Their features and interpretation are not interchangeable.

### Time–Frequency Feature Extraction

For an illustrative ECoG pipeline, the short-time Fourier transform is:

\[
X_c(m,k)
=
\sum_{n=0}^{N-1}
x_c[n+mH]w[n]e^{-j2\pi kn/N},
\]

where:

- \(c\): recording channel.
- \(m\): frame index.
- \(k\): frequency-bin index.
- \(N\): window length, in samples.
- \(H\): frame hop, in samples.
- \(w[n]\): window function.
- \(j=\sqrt{-1}\).

An illustrative log-power feature is:

\[
z_c[m]
=
\log\left(
\epsilon+
\sum_{k\in\mathcal{K}_{\gamma}}
|X_c(m,k)|^2
\right),
\]

where \(\mathcal{K}_{\gamma}\) selects the intended high-gamma bins and
\(\epsilon>0\) prevents taking the logarithm of zero.

The window and update intervals differ:

\[
T_{\mathrm{window}}=\frac{N}{f_s},
\qquad
T_{\mathrm{hop}}=\frac{H}{f_s}.
\]

Frequent updates do not imply that the model uses only a short history.

For streaming operation, the implementation must document whether each
window uses past samples only or introduces future-sample buffering.

### Causal Temporal Encoding

A recurrent encoder can be written as:

\[
\mathbf{h}_t
=
f_{\theta}(\mathbf{z}_t,\mathbf{h}_{t-1}),
\]

where:

- \(\mathbf{z}_t\): current feature vector.
- \(\mathbf{h}_{t-1}\): previous internal state.
- \(\theta\): trained parameters.

The internal state summarizes relevant preceding input. It must not be
described as a complete representation of the person's thoughts.

### Text- or Phoneme-Mediated Decoding

A sequence decoder estimates:

\[
\hat{Y}
=
\arg\max_Y P_{\theta}(Y\mid Z),
\]

where \(Z\) is the feature sequence and \(Y\) is a candidate symbol sequence.

An illustrative language-prior formulation is:

\[
\hat{Y}
=
\arg\max_Y
\left[
\log P_{\theta}(Y\mid Z)
+
\lambda\log P_{\mathrm{LM}}(Y)
\right].
\]

The parameter \(\lambda\) determines the influence of the language prior.

A language prior can favor common expressions. Evaluation must therefore
include uncommon names, specialized vocabulary, nonstandard grammar,
negation, and the person's chosen communication style.

Linguistic plausibility is not proof of intended meaning.

### Acoustic Decoding and Voice Synthesis

An acoustic decoder estimates:

\[
\hat{\mathbf{M}}_t
=
g_{\theta}(\mathbf{z}_{1:t}),
\]

where \(\hat{\mathbf{M}}_t\) represents an acoustic feature frame.

A synthesis model generates waveform samples:

\[
\hat{s}[n]
=
V_{\phi}(\hat{\mathbf{M}}_{\leq t},\mathbf{v}),
\]

where:

- \(\phi\): synthesis-model parameters.
- \(\mathbf{v}\): selected voice configuration.

This formulation does not require a completed text sentence before sound
generation.

Preservation of prosody depends on the information decoded and the
capabilities of the synthesis model; it must be measured rather than
assumed.

### Training With Uncertain Alignment

A general sequence loss is:

\[
\mathcal{L}_{\mathrm{sequence}}
=
-\log P_{\theta}(Y\mid Z).
\]

A transducer-style probability sums over permitted alignments:

\[
P_{\theta}(Y\mid Z)
=
\sum_{\pi\in\mathcal{A}(Y,Z)}
P_{\theta}(\pi\mid Z),
\]

where \(\mathcal{A}(Y,Z)\) includes valid alignments between input frames and
output symbols, including blank emissions.

This avoids requiring a manually specified timestamp for every symbol.

Training and evaluation must remain separated. Report performance on
held-out data, with evaluation conditions and any adaptation disclosed.

### Audible Feedback

A conceptual feedback expression is:

\[
\mathbf{e}(t)=\mathbf{r}(t)-\mathbf{y}(t),
\]

where \(\mathbf{r}(t)\) represents an intended feature and \(\mathbf{y}(t)\)
represents a corresponding perceived output feature.

Subsequent action is represented abstractly as:

\[
\mathbf{u}(t+\Delta t)
=
F(\mathbf{u}(t),\mathbf{e}(t)).
\]

These equations illustrate feedback. They do not imply direct measurement
of complete intention or establish a universal model of human speech
control.

## Responsiveness and Reliability

### End-to-End Latency

A latency budget is:

\[
L_{\mathrm{total}}
=
L_{\mathrm{acquisition}}
+
L_{\mathrm{buffering}}
+
L_{\mathrm{features}}
+
L_{\mathrm{decoding}}
+
L_{\mathrm{synthesis}}
+
L_{\mathrm{playback}}.
\]

If future context is required:

\[
L_{\mathrm{total}}'
=
L_{\mathrm{total}}+L_{\mathrm{lookahead}}.
\]

Every reported latency must name its starting and ending events.

Instruction cue, attempted-speech onset, first acquired frame, and first
audio sample are different reference events.

### Processing Throughput

For incoming chunks every \(\Delta t\):

\[
\rho
=
\frac{\mathbb{E}[T_{\mathrm{processing}}]}{\Delta t}.
\]

The basic average-throughput requirement is:

\[
\rho<1.
\]

This condition alone does not guarantee uninterrupted audio. Also report
high-percentile processing delay, queue growth, and buffer underruns.

### Word Error Rate

\[
\mathrm{WER}=\frac{S+D+I}{N},
\]

where:

- \(S\): substitutions.
- \(D\): deletions.
- \(I\): insertions.
- \(N\): reference-word count.

Report whether transcripts came from human listeners or automatic
recognition, and document reference preparation.

WER does not independently measure prosody, voice preference, agency,
or the consequences of particular errors.

### Unintended Output

A proposed metric is:

\[
R_{\mathrm{unintended}}
=
\frac{N_{\mathrm{unintended\ utterances}}}
{T_{\mathrm{enabled,\ no\ intended\ speech}}}.
\]

If time is measured in hours, the result is unintended utterances per hour
under the declared condition.

Pair it with:

\[
\mathrm{Miss\ rate}
=
\frac{N_{\mathrm{missed\ intended\ utterances}}}
{N_{\mathrm{intended\ utterances}}}.
\]

Define utterance boundaries and annotation procedures before evaluation.

A system that remains silent can minimize unintended output while failing
to provide useful communication.

### Confidence and Authorization

A speech-activity estimate might be:

\[
q_t
=
P_{\theta}
\left(
\text{speech-related activity}\mid Z_{\leq t}
\right).
\]

This estimate is not permission to broadcast.

A proposed authorization gate is:

\[
G_t=A_t\land M_t\land\neg C_t,
\]

where:

- \(A_t\): the person has enabled the communication mode.
- \(M_t\): the output destination is permitted.
- \(C_t\): cancel or mute is active.

This gate expresses an authorization requirement, not a complete
signal-processing or clinical safety policy.

For network transmission, require an independently scoped permission
rather than treating local audio authorization as sufficient.

## Rights, Privacy, and CyberRank Governance

### Respect and Equal Access

Respect voluntary self-description and communication preferences without
requiring public disclosure of diagnosis, implantation, technical
configuration, or private companion systems.

Communication variation, fatigue, repetition, and nonstandard grammar must
not be treated as evidence of reduced competence.

### Interpretation Is Not Authority

Decoder output is an interpretation of recorded signals.

It must not automatically become:

- A verified statement of private thought.
- Medical consent.
- Authorization for a purchase or external action.
- A public identity or eligibility determination.
- A clinical or institutional status claim.

### Data Separation

Manage these as separate data classes:

- Raw recordings.
- Derived features.
- Decoder parameters.
- Voice profiles.
- Candidate outputs.
- Emitted audio.
- Transcripts.
- Authorization and correction records.

For each class, document purpose, access, retention, deletion, export,
and review responsibility.

Permission to process transient signals must not silently authorize
long-term storage or unrelated model training.

### Continuity and Non-Interference

Maintain accessible fallback communication.

Do not make essential communication depend unnecessarily on:

- Internet connectivity.
- Optional telemetry.
- Participation in research.
- Public identity disclosure.
- Acceptance of unrelated software changes.

Medically consequential fallback behavior requires system-specific review.
Powering down is not a universal safety strategy.

### CyberRank Separation

Use CyberRank as a private project vocabulary for communication preferences,
privacy boundaries, continuity needs, and system duties.

Do not encode it as public status, ranking, diagnosis, verification,
eligibility, or automated decision criteria.

## Proposed Non-Actuating Evaluation Artifact

The initial Augmented-Hub implementation should evaluate supplied,
appropriately authorized recordings or simulated decoder outputs.

It must not acquire neural data, control implants, alter stimulation,
or operate clinical equipment.

| Evaluation area | Measurement |
|---|---|
| Intelligibility | Listener transcription accuracy under declared conditions. |
| Responsiveness | Median and high-percentile end-to-end latency. |
| Reliability | Dropouts, queue growth, underruns, and recovery time. |
| Agency | Cancel success and time to stop audible output. |
| Correction | Time and effort to repair an incorrect utterance. |
| Privacy | Unauthorized transmission, retention, or output events. |
| Accessibility | Success using selected controls and fallback methods. |
| Continuity | Availability during decoder or network interruption. |
| Sustainability | Energy per active hour, repairability, and service life. |

Acceptance thresholds must be chosen with intended users and the relevant
review teams. Do not invent universal clinical thresholds.

## Ecological and Maintenance Requirements

Prefer efficient local processing where feasible, durable external
equipment, supported repair, and documented migration paths.

Evaluate environmental claims using measured energy, equipment life,
material use, and lifecycle evidence.

Do not trade away communication reliability merely to reduce computation.

## Proposal-Level Assessment

The following scores are qualitative planning judgments about this
document's research direction.

They are not clinical outcomes, calibrated risk probabilities, safety
certifications, or technical audits.

| Metric | Score | Basis |
|---|---:|---|
| knowledge_factor | 0.88 | Human studies establish feasibility; wider reliability and generalization remain unresolved. |
| eco_impact_value | 0.35 | Efficient processing and durable equipment offer potential value; no lifecycle assessment is supplied. |
| harm_risk | 0.45 | Miscommunication, disclosure, interruption, and implanted-interface risks require separate assessment. |
| accessibility_impact | 0.92 | Personally controlled communication and expression are central objectives. |
| rights_alignment | 0.95 | The proposed architecture separates interpretation from authorization and preserves correction and fallback. |

## Research Priorities

1. Measure everyday usefulness rather than only prompted-task accuracy.
2. Reduce total response latency without hiding uncertainty.
3. Preserve unusual vocabulary and user-chosen expression.
4. Evaluate cancellation, correction, and unintended output explicitly.
5. Reduce recalibration and maintenance burden.
6. Preserve local communication and accessible fallback.
7. Validate privacy, security, and material changes independently.
8. Measure lifecycle costs without overstating environmental benefits.
