# Integrated Civic Access Research

## Status

Proposed Augmented-Hub research specification.
Not a deployed service, legal determination, accessibility certification,
or evidence of measured public benefit.

## Purpose

Study how connected physical-route and procedural improvements affect
the ability to complete ordinary civic tasks with less avoidable burden.

## Primary hypothesis

Improving both route information and procedural information can improve
task completion beyond either improvement alone.

## Initial scope

Use fictional civic tasks, public procedural documents, local simulations,
and permitted observations of public infrastructure.

Do not begin with live entitlement cases, individualized legal deadlines,
private institutional records, or personal location histories.

## Architectural components

### Public-condition evidence

Store:
- feature description;
- measured value and unit where applicable;
- observation method and time;
- source and permitted use;
- uncertainty and conflicts;
- reviewer notes and correction history.

Do not attach contributor identity to public observations.

Keep provenance records free of unnecessary personal information.

### Physical network

Represent route connections and measurable public conditions.

Treat closures, missing connections, and unmet essential requirements as
explicit conditions rather than large numerical penalties.

### Procedural network

Represent:
- task states and transitions;
- responsible service or published channel;
- required information categories;
- active effort and calendar waiting time;
- visits and repeated requests;
- correction and human-assistance paths;
- source review date.

Do not store actual application answers or private document contents.

### Session-local requirements

Accept task-specific requirements without requiring a diagnosis,
augmentation inventory, or identity classification.

Do not persist requirements after the session by default.

### Journey analysis

Evaluate each essential requirement as:
- supported;
- not supported;
- unknown.

Generate non-dominated alternatives among supported candidate journeys.

Show unknown or conflicting conditions separately.
Do not present an unknown route as confirmed accessible.

If no supported journey is found, explain the evidence gap and available
assistance options. Do not infer that the person is ineligible for service.

## Outcomes

Primary:
- correct task completion, with numerator and denominator.

Secondary:
- active effort in minutes;
- travel time in minutes;
- elapsed calendar time;
- number of visits;
- repeated information requests;
- travel distance in meters;
- unresolved failures;
- optional participant-reported effort and autonomy;
- unwanted disclosure requests.

Do not combine incompatible units without a documented transformation.
Do not construct a person score.

## Study design

Begin with fictional tasks and simulated or independently checked routes.

Where feasible, compare:
- existing information;
- improved route information;
- improved procedural information;
- combined improvements.

Predefine task success, recruitment, stopping rules, and analysis.

Never withhold necessary communication or accessibility support.

Account for task-order effects and repeated observations from the same
participant.

Report noncompletion, withdrawal, missing data, and protocol deviations.

## Citizen-science workflow

Accept observations about public conditions, not judgments about people.

Provide accessible submission, correction, and disagreement mechanisms.

Review evidence quality separately from contributor identity.
Do not reward report volume in ways that pressure unsafe fieldwork.

Do not ask volunteers to enter traffic, restricted property, or hazardous
conditions to complete a measurement.

## Rights and CyberRank

Respect voluntary self-description and communication preferences.

CyberRank is private project governance vocabulary, not public status,
verification, ranking, diagnosis, or eligibility.

Protect non-interference and continuity needs without requesting private
technical, neural, medical, or companion-system information.

Participation or refusal must not affect access to public services.

Provide human review and an accessible correction path.

## Privacy and consent

Use purpose-specific, accessible consent for participant research.

Permit withdrawal without penalty.
Do not collect continuous telemetry, biometric data, exact personal
journeys, authentication credentials, or private application contents.

The initial simulation stage collects no participant personal data.

Before participant recruitment, approve a separate data-management plan
specifying retention, deletion, responsibilities, and publication limits.

## Legal-source handling

Distinguish:
- binding requirements;
- official guidance;
- project policy;
- research assumptions;
- participant preferences.

Do not infer local legal applicability from a generic threshold.

Verify procedural statements against current primary sources before
including them in a participant-facing task.

## Environmental accounting

Measure avoided trips and distance separately from emissions.

Estimate emissions only when transport mode, relevant distance, factor
source, and system boundary are documented.

Record computation energy separately.
Do not describe hypothetical savings as measured benefits.

Environmental optimization cannot override essential access requirements.

## External-action gate

This specification authorizes no external submission, publication,
institutional contact, hardware operation, or live-service change.

Each external action requires approval for its exact target and content.

## Validation requirements

Test:
- disconnected physical networks;
- contradictory and outdated evidence;
- unknown opening hours;
- procedures with correction loops;
- missing units and invalid numeric values;
- unavailable offline or human-assisted paths;
- unmet essential requirements;
- attempts to introduce identity-based ranking;
- accidental logging of session-local requirements;
- attempts to substitute environmental benefit for access protection.

## Completion criteria

The first research release is complete when:
- models and assumptions are documented;
- evidence can be corrected without erasing disagreement;
- all analysis is reproducible locally;
- unsupported conclusions are labeled;
- accessible explanations accompany every result;
- community reviewers approve the bounded findings;
- no deployment or legal-compliance claim exceeds the evidence.
