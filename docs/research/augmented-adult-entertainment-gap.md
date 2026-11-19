# The Augmented Adult Gap
## Entertainment Access, Neural Privacy, and Continuity-Centered Design

Status: Research and engineering position paper.
Scope: Entertainment software, accessible input, privacy, and continuity.
Boundary: This document does not classify individuals, determine employment
fitness, certify devices, or authorize interaction with medical systems.

## Executive Position

Adults are a substantial, established video-game audience. The unresolved
question is not whether adults play games, but whether entertainment systems
provide durable, privacy-preserving access for people who use alternative
input, including brain-computer interfaces.

This paper distinguishes four questions:

- Audience: Who plays games?
- Access: Which interaction requirements exclude people?
- Governance: What privacy, autonomy, and equal-access safeguards apply?
- Continuity: What happens when a vendor, account, interface, or service changes?

No person should have to disclose a diagnosis, implant inventory, neural data,
or private self-description to request ordinary accessibility features.

## Evidence-Based Foundation

The Entertainment Software Association's 2026 U.S. report estimates:

- 212.3 million people play video games at least one hour per week.
- 67% of Americans ages 5–90 play weekly.
- The average player age is 37.

Its 2024 report placed the average player age at 36 and reported that adult
players had played for an average of 17 years.

These findings establish that adulthood is not a peripheral gaming market.
They do not establish that publishers meet every adult's accessibility needs.

A separate international survey summarized by GameDev Reports included
24,216 active players across 22 countries and reported an average age of 41.
That result describes its surveyed population; it should not be treated as
directly interchangeable with the U.S. estimate, which includes younger
children.

## Regulatory and Employment Boundaries

Brain-computer interfaces are not one uniform regulatory category.

Any regulatory statement should identify the relevant device, intended use,
jurisdiction, and stage of development. Investigational authorization,
Breakthrough Device designation, and marketing authorization are distinct.

The FDA Breakthrough Devices Program is voluntary. Its designation is not
marketing authorization and is not a universal prerequisite for implanted
BCI development.

Device regulation must not be converted into a personal status label.
Using a BCI does not, by itself, establish that someone is unsafe, unable to
work, or unsuitable for entertainment access.

Workplace medical examinations, disability-related inquiries, accommodation,
and direct-threat assessments have their own legal requirements. They must
not be inferred from a game preference, an input device, or a voluntary
cybernetic-host self-description.

## Neurorights and Project Governance

UNESCO adopted its Recommendation on the Ethics of Neurotechnology on
11 November 2025. It provides an international normative framework for
national action; it is not a substitute for examining applicable domestic law.

This project separately adopts the following governance commitments:

- Respect voluntary self-description without requiring verification.
- Separate accessibility preferences from identity and medical information.
- Do not use CyberRank as an eligibility, ranking, diagnosis, or public status.
- Do not infer employment fitness from entertainment activity.
- Do not collect neural signals for ordinary input configuration.
- Do not condition access on research participation or secondary data use.
- Preserve correction, complaint, appeal, and accessible human fallback.

These are project requirements, not representations that every jurisdiction
already imposes identical legal obligations.

## The Engineering Gap

The useful distinction is not simply conventional input versus BCI-native input.

A game can remain inaccessible after an interface successfully generates
mouse, keyboard, switch, or controller events.

Potential barriers include:

- Mandatory simultaneous commands.
- Short response windows.
- Sustained button holds.
- Repeated high-frequency actions.
- Menus inaccessible through the configured input.
- Mandatory voice communication.
- Timeouts during communication or rest.
- Loss of settings after updates.
- Unexplained restrictions on legitimate accessibility software.

These barriers should be tested directly rather than attributed to age,
diagnosis, or a presumed device capability.

## Proposed Input Architecture

Use an application-level semantic action boundary.

Supported actions should include:

- Navigate.
- Select.
- Cancel.
- Pause.
- Resume.

An input adapter may translate an already authorized external input into
these actions. The entertainment application should not require knowledge
of the physiological source of an action.

The application must not:

- Read raw neural signals.
- Request implant credentials.
- Operate or configure a decoder.
- Change stimulation or medical-device settings.
- Infer mental state from interaction timing.
- Require a device or diagnosis declaration to enable accessibility.

Optional dwell or timing settings should be user-controlled interface
preferences, not estimates of cognitive or neurological status.

Input confidence, where an adapter provides it, must not become a measure
of competence, identity, consent, or eligibility.

## Minimum Acceptance Requirements

### Access

- Core menus support serial navigation and selection.
- Core actions can be remapped without medical disclosure.
- Adjustable timing is available wherever compatible with the game mode.
- Supported modes disclose unavoidable timing constraints before play.
- Menus, account recovery, purchase confirmation, and complaints are tested,
  not merely gameplay.
- Communication supports text alternatives and extended response time.
- Accessibility configuration is available before timed interaction begins.

### Privacy

- The application requests no raw neural data.
- Input configuration requires no diagnosis or implant inventory.
- Accessibility telemetry is optional and separate from access.
- Configuration export excludes private physiological information.
- Secondary research, advertising, and profiling are disabled by default.
- Stopping optional collection does not remove ordinary service access.

### Non-Interference

- The application has no medical-device control interface.
- Input loss does not trigger repeated or escalating commands.
- Destructive and financial actions require explicit confirmation.
- Pausing entertainment does not imply pausing assistive communication.
- No feature claims to protect, repair, calibrate, or monitor an implant.

### Continuity

- Preferences can be exported in a documented local format.
- Material input changes receive accessible release notes.
- Accessibility settings survive supported upgrades.
- A supported offline mode does not require periodic neural-data access.
- Vendor exit and service termination notices explain available alternatives.
- Game configuration portability is not represented as medical-device
  interoperability.

### Equal Treatment

- No access decision uses CyberRank.
- No safety-sensitive label is generated from BCI use.
- No accessibility preference is treated as evidence of reduced competence.
- No therapeutic-versus-elective distinction determines project-level dignity
  or ordinary accessibility support.
- Restrictions have a plain-language explanation and review route.

## Research Claims Requiring Further Evidence

The following are research questions, not established conclusions:

- How many players use different forms of BCI-assisted input?
- Which input constraints matter most across different game genres?
- How often do updates disrupt alternative-input access?
- What support and continuity arrangements do affected players prefer?
- Which publisher decisions are driven by market size, regulation,
  engineering cost, licensing, or platform rules?
- Which anti-cheat policies permit legitimate accessibility adapters?
- How do outcomes differ between ordinary input emulation and semantic
  application-level integration?

Device-specific trial enrollment must not be used as a census of augmented
people or of the broader alternative-input audience.

## Research Method

Recruit participants through voluntary, accessible channels.

Ask about tasks and access barriers rather than requiring diagnoses or
implant details.

Allow asynchronous participation, communication assistance, breaks, and
withdrawal from optional research.

Separate:

- Participant-reported experience.
- Observed interface behavior.
- Vendor statements.
- Applicable law.
- Proposed project policy.

Do not publish identity-linked device histories, neural recordings, private
companion-system information, or inferred medical characteristics.

## Evaluation Metrics

Measure:

- Core-task completion through the configured input.
- Unintended-action frequency.
- Recovery steps after input loss.
- Number of mandatory simultaneous actions.
- Accessibility-setting persistence after updates.
- Timeout-related task failures.
- Successful local preference export and import.
- Optional-telemetry refusal without access loss.
- Complaint and appeal completion through accessible channels.

Report measurement conditions and limitations.

Do not replace these measures with a single score of the person.

## Conclusion

Adult participation in gaming is established. Durable access for varied
bodies, communication patterns, and input systems remains an engineering and
governance task that deserves direct measurement.

The practical objective is entertainment that accommodates users without
requiring disclosure, preserves meaningful control, and remains usable when
interfaces and vendors change.
