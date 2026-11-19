# CyberRank Integration and Continuity Rubric

## Purpose

CyberRank is a rights-centred, non-diagnostic, and non-verifying governance rubric for designing accessible services, technology systems, public infrastructure, and institutional workflows.

It supports people who self-describe as cybernetic hosts, integrated-technology users, BCI users, assistive-technology users, or persons with private companion systems.

The rubric defines institutional duties for privacy, equal access, continuity, non-interference, accessible remedies, and accountable governance.

It does not determine whether a person’s self-description is technically, medically, legally, scientifically, or institutionally verified.

It does not create a public registry, personal credential, human-worth score, capability score, eligibility category, device inventory, or hierarchy of persons.

## Foundational principles

Self-description is sufficient for respectful interaction and access support.

Respect does not require verification.

Service access does not require disclosure.

Privacy preferences must not reduce service quality.

Uncertainty must not create an automatic denial.

A person’s private body–mind integration, assistive technology, BCI use, companion system, health information, biometric information, neural information, network information, or device information must not be inferred, stored, ranked, published, or used as an identity proxy.

## Core invariants

NoIdentityInference means that a system must not infer, store, publish, rank, transfer, sell, or use cybernetic-host status, integrated-technology status, BCI status, companion-system status, health information, disability information, biometric information, neural information, behavioral information, communication patterns, device fingerprints, repair history, or network characteristics as a proxy for identity or eligibility.

NoCompelledDisclosure means that a person must not be required to provide private technical, bodily, cognitive, medical, neural, biometric, device, network, telemetry, repair, or companion-system information to obtain equal service access.

AccessEquivalence means that every supported pathway provides the same core outcome without added cost, delay, disclosure burden, reduced quality, reduced remedy, or loss of human assistance.

NonInterference means that a system responds to environmental and operational hazard concerns through accessible alternatives and general hazard controls rather than requiring disclosure of private system architecture.

RightsMonotonicity means that a policy change may add protections but must not silently weaken core protections.

## Rubric dimensions

CyberRank uses seven non-hierarchical dimensions.

Each dimension describes a service-design consideration.

Each dimension is optional, self-described, and independent of eligibility, credibility, human worth, or entitlement.

| Dimension | Service-design question | Required system response |
|---|---|---|
| Communication continuity | Does the person request a specific communication or interaction pathway? | Provide accessible format, human assistance, and a correction route |
| Integration privacy | Does the person request that private technology relationships remain undisclosed? | Do not request proof, device details, telemetry, body information, or technical architecture |
| Assistive continuity | Could failure of an access tool, interface, or service pathway prevent equal access? | Provide independent non-digital and human-assisted alternatives |
| Companion-system discretion | Does the person request privacy and non-interference concerning a private companion system? | Do not scan, detect, inventory, track, or publicly label the person or system |
| Environmental compatibility | Does the person report a possible environmental or operational access concern? | Assess general hazard conditions and provide accessible alternatives |
| Service restoration | Could an outage, maintenance event, uncertainty condition, or system failure interrupt access? | Preserve essential-service continuity and provide outage fallback |
| Governance and remedy | Could a decision affect access, privacy, autonomy, or participation? | Provide explanation, correction, appeal, non-retaliation, and accountable review |

## Continuity profiles

Continuity profiles are not ranks.

They describe the breadth of protections that a service must be prepared to provide.

| Profile | Description | Required protections |
|---|---|---|
| Profile A: Standard equal access | No self-description is shared, or no additional continuity preference is requested | Equal access, accessible communications, correction, appeal, and no identity inference |
| Profile B: Privacy-preserving access | A person requests privacy, alternative communication, or minimal disclosure | No compelled disclosure, non-digital pathway, human assistance, and privacy-preserving records |
| Profile C: Assistive continuity | A person indicates that reliable access, communication, mobility, or support pathways are important | Redundant pathways, outage planning, accessible status notices, repair and correction routes |
| Profile D: Integrated-system continuity | A person self-describes a meaningful relationship with integrated technology, BCI use, assistive technology, or a private companion system | All Profile C protections plus non-interference review and strict no-inference controls |
| Profile E: High-continuity support | A person requests extensive continuity, discretion, human fallback, environmental compatibility, and material-change protections | All Profile D protections plus enhanced incident response, human review, renewal controls, and documented non-diminishment protections |

## Profile assignment rule

No person is required to accept, disclose, prove, register, or retain a profile.

A person may request any protection available under this rubric without selecting a profile.

The rubric must not assign a profile automatically from behavior, appearance, communication, service use, device signals, body data, health data, location, network data, repair history, or inferred characteristics.

## Non-diminishment requirement

For every person and service pathway:

ServiceOutcome(with_self_description) equals ServiceOutcome(without_self_description)

The outcome comparison includes:

- Core service completion
- Response time
- Service quality
- Cost
- Privacy burden
- Human assistance
- Accessible communication
- Correction availability
- Appeal availability
- Emergency support
- Outage support

## Safe uncertainty behavior

When a system cannot safely determine an appropriate automated result, it must preserve access.

The system must not interpret uncertainty as a reason to deny service, demand disclosure, infer identity, reduce service quality, or terminate support.

The system must instead:

- Provide a neutral human-assisted pathway
- Provide a non-digital alternative where relevant
- Explain the uncertainty in plain language
- Preserve correction and appeal rights
- Record only privacy-preserving operational evidence
- Escalate high-impact cases to accountable human review

## Environmental non-interference

Environmental and operational hazards may be assessed through general categories:

- Electromagnetic conditions
- Magnetic conditions
- Wireless transmission conditions
- Optical conditions
- Acoustic conditions
- Mechanical vibration conditions
- Thermal conditions
- Network continuity conditions
- Coercive or exclusionary operational practices

The assessment must not require the person to disclose private technical details, body data, device information, health information, or companion-system information.

## Material-change safeguards

A material change affects rights, data collection, data retention, automation, access pathways, human assistance, non-digital alternatives, correction, appeal, authority, or essential-service continuity.

Material changes require:

- Documented rationale
- Rights-delta analysis
- Privacy review
- Accessibility review
- Scenario testing
- Accountable human authorization
- Accessible notice
- Correction and appeal availability
- Versioned evidence

A change is prohibited when it weakens a core protection.

## Conformance scenarios

Implementations must test synthetic scenarios covering:

- No account available
- Optional telemetry refused
- No network available
- Power outage
- Human assistance requested
- Phone pathway required
- Relay pathway required
- Screen-reader pathway required
- Keyboard-only pathway required
- Text-only pathway required
- Environmental compatibility concern
- Privacy request
- Automated uncertainty
- Correction request
- Appeal request
- Attempted identity inference
- Attempted compelled disclosure
- Attempted retaliation
- Material policy change

## Limitation

This rubric is a governance and engineering framework.

It does not create or determine personal rank, legal status, clinical status, scientific status, technical certification, institutional recognition, service eligibility, or a claim about the private systems of any person.
