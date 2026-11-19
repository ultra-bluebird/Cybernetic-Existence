## Canonical Machine Values

The Capability Boundary references canonical enum definitions rather than
duplicating machine values in prose.

- Privacy class: [`enums/privacy_class.json`](../enums/privacy_class.json)
- Consent status: [`enums/consent_status.json`](../enums/consent_status.json)
- Action type: [`enums/action_type.json`](../enums/action_type.json)
- Review status: [`enums/review_status.json`](../enums/review_status.json)
- Uncertainty status: [`enums/uncertainty_status.json`](../enums/uncertainty_status.json)
- Attribution mode: [`enums/attribution_mode.json`](../enums/attribution_mode.json)
- Knowledge class: [`enums/knowledge_class.json`](../enums/knowledge_class.json)
- Supersession status: [`enums/supersession_status.json`](../enums/supersession_status.json)

`action_type` classifies governance scope. It does not independently grant
execution authority. Any external action requires a separate explicit approval
process, applicable consent, privacy review, safety review, and material-change
review.

## Non-Authorization Declaration

This artifact does not authorize:

- field activity
- environmental release
- weather modification
- infrastructure control
- public alerting
- external data transfer
- rights-holder representation
- government representation
- operational system control

Internal research approval does not create external operational authorization.
