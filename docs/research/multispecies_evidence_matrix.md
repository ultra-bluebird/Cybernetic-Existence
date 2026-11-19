# Multispecies Evidence Matrix

## Purpose

This matrix defines minimum evidence conditions for urban ecological planning involving non-human species presence, habitat quality, habitat connectivity, disturbance, and welfare-relevant observations.

The matrix supports ecological restoration, green-infrastructure design, habitat connectivity review, and community stewardship. It does not authorize species capture, disturbance, targeting, human surveillance, property surveillance, enforcement, or person-level profiling.

## Shared protections

- Species data must not be used to infer or track human activity, residence, identity, behavior, disability, health, immigration status, augmentation status, or assistive-technology use.
- Human images, voices, identifiers, addresses, license plates, device identifiers, and other personal data must be removed, withheld locally, or prevented at collection whenever possible.
- Sensitive-species records require release review and geographic generalization before any external sharing.
- Species observations remain distinct from habitat-quality indicators, connectivity-barrier observations, and disturbance measurements.
- Lack of a species observation is not evidence of absence unless a declared sampling design supports that inference.
- Welfare-relevant observations involving injured, trapped, entangled, or otherwise endangered animals receive `priority_review`.
- Ecological outputs are advisory-only and cannot override rights, accessibility, privacy, consent, safety, or required human review.

## Evidence matrix

| Input family | Definition | Permitted source classes | Minimum evidence state | Provenance requirements | Freshness behavior | Missing-value behavior | Uncertainty method | Release default | Human privacy control | Ecological sensitivity control |
|---|---|---|---|---|---|---|---|---|---|---|
| `species_presence_observation` | Observation supporting presence of a taxon, taxonomic group, or ecological indicator species at a declared place and time | Direct observation, acoustic monitoring, camera trap, track/scat, ecological survey, community report | `observed`, `community_reported`, or `corroborated` with declared method | Method, time accuracy, location accuracy, observer or device class, taxonomic confidence, media handling, review state | Species- and season-specific; stale records remain historical evidence and cannot establish current occupancy without declared recency support | `insufficient_evidence` for current-presence claims | Spatial-temporal interval plus taxonomic-confidence bound | `local_only` until sensitivity review | No human image, voice, identity, address, license plate, device, or movement trace may be released | Exact coordinates withheld for sensitive taxa until release review |
| `habitat_quality_indicator` | Measured or observed condition relevant to shelter, food, water, vegetation structure, canopy, substrate, or breeding support | Vegetation survey, water observation, canopy model, ground-cover inspection, ecological survey, community report | Evidence compatible with declared species or habitat guild | Unit, method, season, spatial scale, model or inspection version, transformation history | Must match vegetation and hydrologic seasonality | `insufficient_evidence` | Interval bound with model and spatial-resolution components | `aggregate_with_differential_privacy` or `public` after review | No household or individual behavior data | Do not reveal sensitive habitat microfeatures where disclosure raises exploitation or disturbance risk |
| `connectivity_barrier_observation` | Physical or functional feature that may interrupt movement, migration, foraging, or access to habitat | Infrastructure inspection, wildlife movement study, ecological survey, community report | Documented observation with species or guild relevance where known | Barrier type, geometry class, observation time, method, ecological relevance basis, uncertainty | Must be refreshed after infrastructure or land-use change | `insufficient_evidence` | Spatial interval and species-response uncertainty | `local_only` until review | No person-tracking or vehicle-tracking record is needed for ecological use | Generalize locations for sensitive routes or denning, nesting, or breeding areas |
| `disturbance_level` | Declared acoustic, lighting, hydrologic, thermal, construction, or human-presence disturbance condition relevant to ecological planning | Calibrated noise measurement, light measurement, ecological survey, inspection, community report | Method and environmental conditions must be declared | Sensor calibration, temporal window, spatial context, reference condition, ecological relevance model | Event-sensitive; construction, flood, migration, and breeding periods require scenario-specific freshness | `insufficient_evidence` | Componentwise interval bound | `local_only` or aggregate release after review | Do not retain raw audio, video, Wi-Fi, Bluetooth, or device data for human monitoring | Avoid publishing exact sensitive-species disturbance sites |
| `welfare_relevant_observation` | Observation of injury, entrapment, entanglement, acute habitat hazard, stranded wildlife, or immediate welfare concern | Direct observation, community report, authorized responder record, ecological survey | `community_reported` is sufficient to trigger review | Time, generalized location, observable condition, safe contact pathway, review state | High urgency; retains historical record while routing current concern promptly | `priority_review` rather than dismissal | Qualitative urgency plus location/time interval | `local_only` by default | No submitter identity requirement; no medical or personal data request | Limit outward disclosure to reduce additional disturbance or targeting |

## Spatial-resolution policy

Spatial resolution is determined by ecological sensitivity, harm potential, planning purpose, and release class. No single precision is safe or necessary for all observations.

| Sensitivity class | Local storage precision | External release precision | Permitted planning use |
|---|---|---|---|
| `extreme_sensitive` | Exact local record may be retained only where necessary and authorized | No coordinates; release only broad ecological region, watershed, or planning district | Internal ecological review and authorized protection planning |
| `high_sensitive` | Exact or high-precision local record with strict access controls | Generalized to broad planning zone, watershed, or equivalent coarse grid | Habitat protection and infrastructure avoidance review |
| `medium_sensitive` | Exact local record subject to sensitivity review | Generalized to a planning grid or neighborhood-scale zone | Corridor and green-infrastructure planning |
| `low_sensitive` | Declared location accuracy retained locally | Generalized or exact public release only after review | Public ecological education and general planning |
| `non_sensitive` | Declared location accuracy retained | Public release permitted when provenance, license, and review requirements pass | Public ecological information and planning |

## Priority-review rule

A welfare-relevant observation enters `priority_review` when it reports an observable condition consistent with:

- Injury or entanglement.
- Entrapment or obstruction.
- Exposure to immediate flooding, heat, toxic material, traffic, construction, or infrastructure hazard.
- A blocked movement route during a declared sensitive season.
- A hazard involving a species group subject to additional ecological protection.

The report must remain advisory and reviewable. The system does not direct capture, handling, removal, intervention, or external contact without appropriate authorization and a safe response process.

## Prohibited uses

- Human surveillance or behavioral inference.
- Enforcement targeting.
- Automated wildlife intervention.
- Commercial exploitation or location-based targeting of sensitive taxa.
- Property valuation or neighborhood desirability ranking.
- Individual public-service eligibility, exclusion, or priority scoring.
- Inferring species presence from human activity data without ecological validation.
