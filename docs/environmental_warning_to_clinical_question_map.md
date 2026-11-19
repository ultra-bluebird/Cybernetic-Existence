# Environmental Warning and Clinical Question Map

## Purpose

This map helps distinguish environmental sensor observations from private
body-related observations and produces questions for appropriate human follow-up.

It does not diagnose, infer health, infer cognitive state, confirm a biological
reaction, or authorize device manipulation.

## Separation rule

Environmental observations and body-related observations are separate evidence
classes.

Environmental observations may include:

- dissolved oxygen;
- salinity or conductivity;
- water temperature;
- pH;
- turbidity;
- hydraulic flow;
- sensor-health state.

Private body-related observations may include:

- observable discomfort;
- redness;
- swelling;
- skin or tissue change;
- irritation;
- timing of an externally observed device warning;
- concern about wear, damage, heating, corrosion, or material change.

Neither class proves the other.

An environmental measurement MUST NOT be converted into a clinical conclusion.
A private observation MUST NOT be represented as an environmental measurement.

## Mapping table

| Canal-monitoring parameter | Environmental meaning | Permitted host/system vocabulary | Not permitted | Safe escalation question |
|---|---|---|---|---|
| Dissolved oxygen | Oxygen available in water; can indicate water-quality and biological stress conditions | “The environmental monitor reported a dissolved-oxygen change at this time.” | “Low dissolved oxygen explains a symptom.” | “Is this environmental condition relevant to the documented operating or exposure context?” |
| Salinity or conductivity | Dissolved-ion content or a conductivity proxy; may affect corrosion, material swelling, water chemistry, and environmental habitat conditions | “The monitor recorded a conductivity or salinity change.” | “The salinity measurement proves tissue incompatibility.” | “Could the documented salinity/conductivity range affect the relevant material, coating, or environmental exposure pathway?” |
| Temperature | Water or environmental thermal condition; may affect materials, electronics, microbial activity, and environmental quality | “A temperature change was observed near the reported time.” | “Temperature proves a biological response.” | “Does this temperature range matter for material performance, device instructions, or the concern being evaluated?” |
| pH | Water acidity or alkalinity; may influence corrosion, dissolution, chemical form, and environmental processes | “The monitor recorded a pH excursion or trend.” | “pH establishes irritation or toxicity in a person.” | “Could the recorded environmental pH be relevant to a known material-degradation, corrosion, or exposure concern?” |
| Sensor-health alert | Data-quality or instrument-status condition | “The environmental data source was unavailable, stale, or out of calibration.” | “Missing sensor data is evidence of a personal condition.” | “What additional record or direct inspection is needed before relying on this environmental context?” |
| Internal system warning | Private system event or user-observed alert whose meaning has not been clinically verified | “A system warning occurred; its meaning is unknown.” | “The warning confirms sensitization, cytotoxicity, infection, toxicity, or device failure.” | “What information would help determine whether this warning needs manufacturer support, routine clinical follow-up, or urgent assessment?” |

## Output contract

A warning interpreter MAY output only:

1. `observable_description`
2. `environmental_context`
3. `candidate_discussion_topics`
4. `missing_information`
5. `escalation_questions`
6. `urgent_review_flag`

The interpreter MUST NOT output:

- diagnosis;
- probability of a diagnosis;
- confirmed ISO 10993 category;
- treatment instruction;
- device manipulation instruction;
- medical clearance;
- autonomous action;
- public status;
- identity inference.

## Urgent review flag

The `urgent_review_flag` is permitted only for a plain-language instruction to seek
urgent in-person care or emergency services when severe or rapidly worsening symptoms
are reported, including breathing difficulty, face or throat swelling, chest pain,
fainting, severe escalating pain, high fever, rapidly spreading rash, drainage or
apparent infection near a body-contacting device, acute neurological symptoms, or
apparent device failure with acute symptoms.

The flag is not a diagnosis.
