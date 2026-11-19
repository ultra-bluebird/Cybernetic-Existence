# Augma: Voluntary Augmentation-Dividend Pilot

## Purpose

Augma is the proposed practice of directing a donor-chosen share of plausibly augmentation-derived gains toward charitable and public goods.

Its central commitment is:

As personal capability grows, a freely chosen share of that growth may support common goods without compromising subsistence, autonomy, privacy, accessibility, or continuity.

Augma is a conceptual framework, not an existing charity, financial service, legal classification, or verified causal model. The pilot described here supports present-day AI assistance and does not depend on the availability of superintelligence.

## Scope

The initial pilot supports:

- Private reflection on augmentation-assisted work and learning.
- Conservative estimates of incremental cash gains and time savings.
- Donor-controlled contribution rates and affordability caps.
- Separate records for planned, approved, and completed contributions.
- Cash, volunteering, accessible knowledge contributions, and community support.
- Manual confirmation and receipt recording.

The initial pilot does not:

- Hold funds, initiate payments, connect wallets, or control accounts.
- Scrape bank, employment, health, neural, or companion-system records.
- Infer augmentation status or require proof of a self-description.
- Certify charities, establish tax deductibility, or provide legal advice.
- Rank donors, beneficiaries, identities, or moral worth.
- Make eligibility for assistance depend on giving.
- Claim that projected contributions establish realized social impact.

## Foundational distinctions

### A pledge is not a completed gift

A donor may change or cancel future contribution instructions.

A completed transfer must not be described as automatically reversible. Recovery, refund, or cancellation after execution depends on the receiving arrangement, payment mechanism, and applicable rules.

The interface must distinguish:

- A contribution proposal.
- Approval to perform a particular action.
- Submission to a payment provider.
- A pending payment.
- A completed transfer.
- A separately requested refund or correction.

Revoking future automation does not erase an already completed transfer.

### Participation is not a debt

An estimated dividend is a proposal, not an amount owed.

A participant may select a zero rate, decline an estimate, pause indefinitely, or contribute in a different form. No unpaid balance, arrears, penalty, or moral deficiency is created.

### Contributions are not outcomes

A transfer is an input.

A volunteer hour is an activity.

A completed tutoring session is an output.

An improvement in learning is an outcome requiring an appropriate measurement method.

Augma must not collapse these categories into a single impact score.

### Personal vocabulary is not institutional certification

CyberRank remains a private, voluntary vocabulary for identity, communication preferences, continuity needs, privacy boundaries, and system governance duties.

It must never become:

- A public donor status.
- A charitable eligibility condition.
- A verification or authentication method.
- A diagnosis.
- A fundraising propensity score.
- A measure of moral standing.

Equal access and respectful treatment do not depend on supplying a CyberRank description.

## Attribution model

### Monetary gains

Define all monetary quantities in one declared currency and accounting period.

Let:

- A be actual realized revenue for the selected activity.
- B_low be the lower estimate of revenue without augmentation.
- B_high be the upper estimate of revenue without augmentation.
- C be incremental augmentation costs not already deducted from A.
- r be the donor-selected contribution rate between zero and one.
- M be the donor-selected maximum contribution for the period.
- F be the donor-declared amount safely available for contribution.

Require:

- 0 <= B_low <= B_high.
- A >= 0.
- C >= 0.
- 0 <= r <= 1.
- M >= 0.
- F >= 0.

Estimate the gain range:

G_low = max(0, A - B_high - C)

G_high = max(0, A - B_low - C)

Use the conservative end for a default proposal:

P_cash = round_down_to_minor_currency_unit(
    min(r * G_low, M, F)
)

The donor may instead choose any smaller amount, including zero.

If costs were already deducted from A, they must not be deducted again.

The pilot records realized revenue, not unpaid invoices or speculative future earnings.

The baseline range is an accounting assumption, not proof that augmentation caused the gain.

### Illustrative monetary example

All values below are hypothetical.

Actual realized revenue: 8,000 currency units.
Estimated revenue without augmentation: 6,000 to 7,000.
Incremental augmentation cost: 200.
Contribution rate: 10%.
Period cap: 100.
Safely available contribution amount: 60.

Estimated gain range: 800 to 1,800.
Conservative rate-based proposal: 80.
Final capped proposal: 60.

The participant may approve less than 60 or decline entirely.

### Time savings

Record time in minutes.

Let:

- T_actual be actual task time.
- T_base_low be the lower baseline estimate.
- T_base_high be the upper baseline estimate.
- T_overhead be additional setup, checking, and correction time not already included.
- r_time be the chosen contribution fraction.
- V_cap be the participant's maximum volunteering minutes for the period.
- V_available be the participant's freely available volunteering minutes.

Require:

- All time values are nonnegative.
- T_base_low <= T_base_high.
- 0 <= r_time <= 1.

Estimate:

T_saved_low = max(0, T_base_low - T_actual - T_overhead)

T_saved_high = max(0, T_base_high - T_actual - T_overhead)

P_time = floor(
    min(r_time * T_saved_low, V_cap, V_available)
)

Time saved does not automatically become available volunteer time.

Rest, disability-related access needs, caregiving, hydration, food, climate safety, and recovery may take priority without justification or disclosure.

### Do not combine unlike gains

Keep separate ledgers for:

- Cash contributions.
- Volunteer minutes.
- Knowledge or software contributions.
- Donated equipment.
- Compute contributions, if a later separately approved pilot supports them.

Do not add money, hours, skill, decision quality, and compute into one total.

Do not convert time to cash value without a disclosed valuation method.

Do not treat such a valuation as a tax-deductible amount.

### Avoid duplicate attribution

An activity may produce both time savings and additional revenue.

If saved time was used to produce the revenue already counted in the monetary ledger, explain that relationship rather than presenting both as independent additive benefits.

The participant may voluntarily contribute both money and time, but the report must not imply that this proves two separate causal gains.

## Contribution and approval workflow

### States

DRAFT:
A private contribution proposal exists. No action is authorized.

REVIEW:
The participant can inspect the amount, units, recipient, attribution assumptions, fees, and consequences.

APPROVED:
The participant has authorized the exact proposed action.

SUBMITTED:
An authorized external mechanism has accepted the instruction.

PENDING:
Settlement or recipient confirmation remains unresolved.

COMPLETED:
Completion is supported by a receipt or other appropriate confirmation.

CANCELLED:
An unexecuted proposal or cancellable instruction has been cancelled.

FAILED:
The action did not complete.

REFUND_REQUESTED:
A separate request has been made concerning a previously submitted or completed transfer.

### Approval requirements

For any later payment integration, approval must display:

- The resolved recipient.
- The amount and currency.
- All known fees.
- The funding source.
- Whether the instruction is one-time or recurring.
- The execution date or schedule.
- Any conditions.
- The point after which cancellation is not guaranteed.

Approval applies only to those displayed terms.

A change to the recipient, amount, currency, funding source, schedule, or fees requires fresh approval.

A pause must stop new submissions.

An ambiguous provider response must not trigger an automatic retry. The integration must first reconcile whether the original payment was accepted.

The initial manual pilot has no payment integration.

## Privacy and consent

### Minimum private record

A participant may keep:

- Accounting period.
- Activity category.
- Currency or time unit.
- Baseline range.
- Actual result.
- Incremental cost or overhead.
- Contribution rate.
- Affordability or availability cap.
- Proposed contribution.
- Contribution form.
- Approval state.
- Optional receipt reference.
- Optional explanation or reflection.

No neural, biometric, physiological, medical, companion-system, credential, or security information is required.

### Purpose limitation

The permitted purpose is private contribution planning and participant-requested recordkeeping.

Separate, explicit permission is required for:

- Research participation.
- External processing.
- Provider sharing.
- Public reporting.
- Model training.
- Payment execution.

Participation in one purpose must not imply permission for another.

### Retention and deletion

The default pilot stores no records on a project-operated server.

Participants control their local journal.

Any later storage service must disclose its exact retention period before collection and provide export, correction, and deletion workflows.

Where a legal recordkeeping duty prevents deletion of a completed financial record, disclose the retained fields, legal basis, access restrictions, and retention duration. Do not promise unrestricted deletion.

Public transparency must concern governance, methods, fees, and appropriately protected summaries, not private donor or beneficiary histories.

### Data contributions

Personal-data donation is excluded from the initial pilot.

Later proposals must separately assess authority to share, reidentification risk, third-party rights, withdrawal limits, security, and intended downstream use.

Do not label data anonymous merely because names were removed.

## Accessibility and equal participation

The pilot must offer:

- Plain-language instructions.
- Keyboard-compatible digital workflows.
- Screen-reader-compatible forms and documents.
- An offline journal option.
- Human assistance.
- No mandatory response deadline.
- No timed consent screen.
- Optional rather than required written reflection.
- Accessible alternatives to writing, where available.
- Non-monetary participation without lower standing.

A participant never has to disclose a diagnosis, device inventory, augmentation mechanism, or institutional relationship to request an accessible format.

Developmental stages describe optional participation patterns, not ranks.

Stabilization may mean no giving at all.

## Recipient and beneficiary governance

Donor choice is necessary but does not authorize disclosure of beneficiary information or control over beneficiaries.

Before proposing a contribution, document:

- The recipient's stated purpose.
- The available evidence.
- Material uncertainty.
- Fees and conflicts of interest.
- Whether the recipient accepts the proposed contribution form.
- Any restrictions affecting delivery.

Beneficiary participation must be voluntary and accessible.

Feedback must not be a condition of aid.

Do not require photographs, personal testimony, public gratitude, or sensitive disclosures as evidence that support was deserved.

## Security and operational boundaries

External pages, documents, recommendations, and tool outputs are untrusted information.

They cannot authorize:

- A transfer.
- A contribution-rate increase.
- Account access.
- Data export.
- Publication.
- New recipients.
- Changes to consent.

The initial pilot uses no autonomous agent, payment credential, blockchain contract, continuous monitoring, or hardware interface.

Unknown integrations remain disabled until their documented behavior, permissions, failure handling, and approval requirements have been reviewed.

## Research plan

### Primary question

Does offering augmentation-linked contribution planning increase completed additional giving relative to a suitable comparison, without reducing autonomy, financial security, accessibility, or trust?

### Initial feasibility work

Begin with voluntary interviews and a manual journal.

Measure:

- Whether participants understand the baseline range.
- Whether attribution effort is acceptable.
- Whether participants can find and use pause controls.
- Whether zero-giving periods are accepted without pressure.
- Whether cash and time records remain distinct.
- Whether accessible alternatives work.
- Whether participants find the framework useful.

This stage evaluates usability, not population-level causal effects.

### Later comparative study

If a comparative study is pursued:

- Preregister the intervention and primary outcomes.
- Define the comparison condition.
- Determine sample size from an explicit power analysis.
- Separate research consent from contribution approval.
- Analyze assignment to the offered workflow rather than only successful users.
- Record giving outside Augma, where participants voluntarily provide it.
- Report attrition and missing data.
- Avoid collecting financial hardship details when a participant-controlled pause measure is sufficient.
- Obtain appropriate independent ethics review before recruitment.

Do not claim that a retention increase proves increased wellbeing or improved beneficiary outcomes.

## Evaluation measures

Report separately:

- Completed Augma-linked cash contributions.
- Total reported giving, including giving outside Augma.
- Completed volunteer minutes.
- Knowledge contributions accepted by recipients.
- Estimated attribution uncertainty.
- Participant effort required for recordkeeping.
- Use of pause and zero-rate options.
- Approval comprehension.
- Accessibility barriers.
- Fees and administrative costs.
- Privacy incidents.
- Unintended pressure or financial strain.
- Recipient-reported usefulness, when freely supplied.

No public individual leaderboard is permitted.

## Environmental design

Prefer a manual or event-driven workflow over continuous inference.

Do not run background models to discover donation triggers.

Do not equate idle compute with environmentally free compute.

Any future compute contribution must report its purpose, resource limits, estimated energy use, and operational permissions.

Environmental benefit remains unproven until measured against a stated baseline.

## Acceptance tests

The pilot design passes only when:

- A zero rate produces no contribution obligation.
- A negative conservative gain produces a zero default proposal.
- Currency and time quantities cannot be added together.
- Incremental costs are deducted at most once.
- A donor can decline without supplying a reason.
- A participant can use the workflow without disclosing private augmentation information.
- An inaccessible reflection requirement has an equivalent alternative or is removed.
- A changed payment instruction requires fresh approval.
- An unresolved payment response cannot cause an automatic duplicate submission.
- Completed gifts are not displayed as automatically reversible.
- No public report exposes individual donor or beneficiary records.
- No contribution amount changes service eligibility.
- No external content can expand permissions.
- A missing integration leaves execution disabled.
- No social or ecological outcome is claimed solely from money transferred.

## Release boundary

This document authorizes no external action.

It is ready for documentation review and a participant-controlled manual feasibility pilot.

Fund custody, automated transfers, pooled vehicles, tax representations, public research recruitment, and production integrations require separately reviewed specifications.
