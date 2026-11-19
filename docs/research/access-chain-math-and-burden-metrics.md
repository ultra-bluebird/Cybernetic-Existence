# Access-Chain Mathematics and Administrative-Burden Metrics

## Status and purpose

Proposed research specification extending integrated-civic-access.md.

Use mathematics to evaluate whether a person can move through a physical
and procedural journey toward a chosen civic task with less avoidable
effort, repetition, uncertainty, and disclosure.

The formulas are research definitions, not validated assessment scales,
legal tests, accessibility certifications, or person scores.

## Access-chain structure

Represent a journey through connected physical and procedural states:

information -> preparation -> travel or remote connection -> service
interaction -> submission -> correction if needed -> task resolution

A journey may omit travel, contain alternatives, or revisit an earlier
state. Do not force every task into a linear sequence.

Represent the combined network as a directed graph:

G = (V, E)

Vertices describe public locations or procedural states.
Edges describe movement, communication, or procedural transitions.

An edge may have:
- physical conditions;
- available communication methods;
- opening hours or timing constraints;
- required information categories;
- active effort and travel time;
- financial cost;
- evidence source, observation time, and uncertainty.

## Essential-requirement evaluation

For journey J and stated requirement k:

r_k(J) belongs to {supported, not_supported, unknown}

Overall journey status:

- not_supported: at least one essential requirement is not supported;
- unknown: none is not supported, but at least one is unknown;
- supported: every essential requirement is supported.

Unknown is not equivalent to supported.
Not supported describes the candidate journey, not the person's ability
or entitlement.

Do not allow a short distance, low cost, or environmental benefit to
compensate for an unmet essential requirement.

## End-to-end completion

For a fixed, declared observation period:

completion_rate =
    completed_task_episodes / initiated_task_episodes

Define the task and completion criterion before collecting outcomes.

Report separately:
- completed;
- still in progress;
- stopped, reason voluntarily supplied;
- stopped, reason unknown;
- outcome unknown.

Do not treat every noncompletion as a failure attributable to the person.

## Conditional stage progression

For a particular sequential pathway:

P(all stages completed) =
    product over i of P(stage i completed | all prior stages completed)

This is a conditional-probability identity, not an independence assumption.

Do not multiply unconditional stage success rates.
Do not apply the linear formula directly to branching paths or correction
loops without a model accounting for those structures.

Stage denominators must include only episodes that reached the relevant
stage. Report their counts.

## Journey burden vector

Keep separate:

B(J) = (
    learning_minutes,
    preparation_minutes,
    submission_minutes,
    correction_minutes,
    participant_waiting_minutes,
    travel_minutes,
    elapsed_calendar_hours,
    visit_count,
    repeat_request_count,
    out_of_pocket_cost,
    travel_distance_meters
)

Active administrative effort equals the sum of learning, preparation,
submission, and correction minutes.

Participant waiting means occupied waiting, such as holding on a call or
waiting at a counter.

Elapsed calendar time overlaps other measures and must not be added to
them.

Use mutually exclusive activity categories when summing time.
If two activities overlap, allocate the interval once or report a range.

## Comparing alternatives

Journey A dominates journey B when A is no worse on every declared
burden objective and strictly better on at least one.

Compare only alternatives meeting essential requirements.

Present non-dominated alternatives with understandable tradeoffs.
Do not create an unexplained universal "best" journey.

Keep unknown alternatives visible as evidence-limited options, distinct
from supported recommendations.

## Correction-loop model

Let:
- a = initial active effort in minutes;
- p = constant probability of another correction cycle, 0 <= p < 1;
- r = additional effort per correction cycle in minutes.

Under this simplified model:

expected_correction_cycles = p / (1 - p)

expected_active_minutes = a + r * p / (1 - p)

Assumptions:
- correction probability is constant across cycles;
- correction effort is constant;
- the episode continues until completion;
- there is no abandonment or terminal rejection.

If those assumptions do not hold, report observed cycle distributions or
use a separately specified process model.

Do not present a modeled expectation as a measured outcome.

## Key administrative-burden metrics

### Learning time

Minutes spent locating and understanding relevant instructions.

Report:
- median and upper-tail time;
- task and channel;
- number of observations;
- missing observations.

Keep optional feedback on clarity separate from timed performance.

### Active administrative effort

Sum of mutually exclusive learning, preparation, submission, and
correction minutes.

Exclude travel and occupied waiting when these are reported separately.

### Occupied waiting

Minutes spent waiting while the participant must remain engaged or
present.

Distinguish occupied waiting from calendar processing delay.

### Elapsed resolution time

Time from the predefined start event to the predefined resolution event.

Report unresolved episodes and their observed follow-up time.
Do not report only completed episodes as though they represent everyone.

### Repeat-request rate

repeat_request_rate =
    unnecessary_repeat_requests / all_information_requests

An unnecessary repeat request asks for information already supplied,
still applicable, and available for the declared purpose.

Document the review rule.
A required update or legitimate correction is not automatically repetition.

### First-submission acceptance

first_submission_acceptance =
    submissions_accepted_as_complete_without_correction /
    first_submissions_assessed

This measures administrative completeness, not approval of the request
and not legal eligibility.

### Correction burden

Report:
- proportion of assessed submissions requiring correction;
- correction cycles per affected episode;
- correction effort;
- whether correction can occur without restarting.

### Visit burden

Report:
- visits per initiated episode;
- visits per completed episode;
- visits independently reviewed as avoidable.

Do not assume all in-person visits are unwanted.
Preserve voluntary in-person and human-assisted service.

### Direct financial burden

Report participant-incurred fees, transport charges, postage, printing,
and other explicitly defined expenses by currency.

Do not assign a wage value to a person's time by default.

### Participant-reported experience

Offer optional, accessible questions about:
- clarity;
- effort;
- frustration;
- control over the process;
- feeling respected;
- ability to obtain assistance.

Declare wording and response scale before use.
Keep responses separate unless a validated composite is adopted.

Do not infer mental health or physiological state from these answers.

### Unwanted disclosure requests

unwanted_disclosure_request_rate =
    episodes_with_a_reported_unwanted_disclosure_request /
    episodes_with_a_response_to_that_optional_question

Report response counts and missingness.

Distinguish a participant's reported experience from a legal determination
that a request was unlawful.

### Correction and assistance access

Report whether each tested workflow provides a usable:
- explanation of the problem;
- correction channel;
- human-assistance channel;
- review or appeal route where applicable.

Test actual task completion through the channel, not just its existence.

## Evaluating change

For a burden measure where lower is better:

absolute_reduction = baseline - followup

relative_reduction =
    (baseline - followup) / baseline

Relative reduction is undefined when baseline is zero.
Report the absolute change instead.

For completion, report the change in percentage points and the underlying
counts.

Do not claim causal improvement from an uncontrolled comparison.
Account for changes in task difficulty, recruitment, channel, opening
hours, follow-up duration, and available support.

## Fairness and governance

Compare system conditions, communication methods, and task pathways.

Do not infer identity, disability, augmentation, diagnosis, or eligibility.

Respect private CyberRank self-description and governance boundaries.
Never convert these metrics into public status or person ranking.

Operational comparisons without demographic data do not establish
demographic or intersectional equity.

Do not shorten necessary communication time to improve speed metrics.
Do not remove review, consent, or correction protections to reduce steps.

## Privacy and collection boundaries

Begin with fictional tasks, public instructions, and local simulations.

Use coarse durations or participant summaries where sufficient.
Do not collect continuous location, neural, biometric, medical,
companion-system, credential, or private case data.

Participant research requires accessible consent and an approved
retention/deletion plan.

Publish aggregates only after disclosure-risk review.
A small-cell threshold alone is not a guarantee of anonymity.

## Validation tests

Verify:
- unknown evidence never becomes confirmed support;
- essential requirements cannot be traded away;
- time intervals are not double counted;
- zero denominators produce unavailable, not zero;
- unresolved episodes remain visible;
- first-submission acceptance is not confused with eligibility;
- legitimate updates are not labeled unnecessary repetition;
- communication variation does not become a competence judgment;
- accessible and offline alternatives remain available;
- reported environmental savings use a declared measurement boundary.

## Acceptance criterion

The research extension is ready for a bounded pilot when each metric has:
- a named purpose;
- a numerator and denominator where applicable;
- a unit;
- an observation window;
- missing-data rules;
- an accessible collection method;
- a privacy boundary;
- a documented interpretation limit;
- a responsible reviewer.
