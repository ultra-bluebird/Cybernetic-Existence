# Biocompatibility Evidence Boundary Checklist

## Purpose

This checklist adapts the disciplined structure of lifecycle assessment to organize
biocompatibility evidence.

It is not a lifecycle assessment, clinical diagnosis, medical-device certification,
risk clearance, regulatory submission, or authorization to alter a device.

## 1. Evaluation purpose

Record:

- question being evaluated;
- intended audience;
- decision the evidence can inform;
- decision the evidence cannot make;
- whether the request concerns general education, device information, clinical
  discussion preparation, or manufacturer follow-up;
- review status.

Example:

"Organize available information for a clinician or manufacturer discussion about a
documented body-contacting material concern. This record does not determine diagnosis,
compatibility, or treatment."

## 2. Functional unit

Define the smallest concrete object of evaluation.

Examples:

- one named material formulation;
- one coating or adhesive;
- one final finished device version;
- one external contact interface;
- one known exposure pathway;
- one documented material-degradation scenario.

Do not use an undefined category such as "all cybernetic integration."

## 3. System boundary

Record inclusions and exclusions.

Potential inclusions:

- base material;
- coating;
- adhesive;
- pigment;
- electrode;
- packaging-contact transfer where relevant;
- manufacturing residues;
- sterilization method;
- wear, corrosion, degradation, and extractables;
- body-contact pathway;
- intended contact duration.

Potential exclusions:

- unknown proprietary formulation;
- unavailable manufacturing data;
- unverified third-party claims;
- material components not known to contact the body.

Every exclusion MUST state how it limits interpretation.

## 4. Evidence inventory

For each input, record:

- evidence identifier;
- source organization;
- source status;
- publication or revision date;
- material or device specificity;
- applicable contact category;
- observed or modeled value;
- units;
- method;
- quality status;
- uncertainty;
- known gaps.

Evidence categories may include:

- manufacturer information;
- instructions for use;
- implant card or device record;
- chemical characterization;
- controlled biological-evaluation result;
- laboratory test report;
- clinician-provided information;
- user-observed event;
- published material-family reference;
- unknown.

A user-observed event is evidence of an observation, not evidence of a diagnosis.

## 5. Biological endpoint map

Map each evidence item only to endpoints it actually addresses:

- chemical characterization;
- cytotoxicity;
- sensitization;
- irritation;
- systemic toxicity;
- genotoxicity;
- implantation response;
- hemocompatibility;
- degradation-product exposure;
- material-mediated pyrogenicity;
- unknown or not assessed.

An endpoint may be marked `not_assessed`, `inconclusive`, `not_detected`,
`detected`, or `contradictory`.

`not_detected` is not equivalent to safe, compatible, or clear.

## 6. Interpretation

State separately:

- what the evidence supports;
- what it does not support;
- material assumptions;
- missing information;
- uncertainty;
- appropriate next question;
- recommended human follow-up route where individualized assessment is needed.

The interpretation MUST NOT state a diagnosis, compatibility clearance, treatment
instruction, device-manipulation instruction, public rank, or machine authority.

## 7. Privacy and retention

The record MUST:

- remain local by default;
- not contain a governance DID;
- not contain CyberRank status;
- not be exported by default;
- not be used for training or telemetry by default;
- allow correction and deletion;
- record only the minimum detail necessary for the stated purpose.

## 8. Urgent-care boundary

The checklist MUST display an urgent-care instruction for severe or rapidly worsening
symptoms, including breathing difficulty, swelling of the face or throat, chest pain,
fainting, high fever, rapidly spreading rash, severe escalating pain, drainage or
apparent infection near a body-contacting device, acute neurological symptoms, or
apparent device failure with acute symptoms.

Research and documentation do not replace urgent in-person clinical assessment.
