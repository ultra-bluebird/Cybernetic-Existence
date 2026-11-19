# Cyber Particle / Memo

## Bostrom Network — Necro-Fall Corridor Research

Document date: 2026-10-17  
Content version: 2.0  
Content type: Markdown research memo  
Scientific status: Proposed model; regional calibration pending  
Publication status: Local draft; not uploaded, signed, or broadcast  
License: CC-BY-4.0

### Attribution and source fidelity

Preferred attribution, following the project record:

`bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`

Attribution supplied in the original memo, retained verbatim:

`bostrom18sd2ujv24ual9c9pshtxys6j8kh6xaead9ye7`

These strings differ. Their inclusion preserves the source record and
the project’s stated attribution preference; it does not assert that
either address has been validated or authenticated.

Publication must remain blocked until the author confirms the exact
public attribution text. Any proposed signing account must be selected
and reviewed separately.

Attribution request: credit the creator using the confirmed attribution
statement, identify modifications, and retain the applicable license
notice in a manner consistent with CC BY 4.0. Attribution must not imply
endorsement of derivatives.

### Research relationship

This memo summarizes the companion document:

`docs/research/necro-fall-corridor-connectivity-california-current.md`

No parent-particle CID, proposal CID, plot CID, or transaction record has
been assigned.

Repository paths are local document references, not claims that the
files have been committed, uploaded, pinned, or published.

### Research statement

The Necro-Fall Corridor hypothesis proposes that the availability,
longevity, suitability, and spatial arrangement of deposited organic
resources influence colonization and persistence among associated
seafloor organisms.

Whale falls, wood falls, kelp deposits, and other animal remains are
represented as potentially interacting resource patches—not
interchangeable habitats for a single universal specialist community.

Existing research supports whale-fall succession and metapopulation
modeling for whale-fall specialists. Monterey Canyon observations
support its role in transporting organic material into deeper
environments. The proposed Mendocino–coastal kelp–Monterey linkage
remains a regional hypothesis to investigate.

### Model summary

For taxon \(s\), define:

\[
\beta_{s,ij}(t)
=
\alpha_s q_{s,i}(t)q_{s,j}(t)
\exp\!\left(-\frac{d_{ij}}{L_s}\right)
\exp\!\left(-\frac{|z_i-z_j|}{Z_s}\right)
a_{s,ij}(t),
\qquad i\ne j.
\]

Here:

- \(\beta_{s,ij}\): colonization hazard from occupied source \(i\)
  to destination \(j\), yr\(^{-1}\).
- \(\alpha_s\): colonization-rate scale, yr\(^{-1}\).
- \(q_{s,i}\): taxon-specific habitat suitability, 0–1.
- \(d_{ij}\): horizontal separation, km.
- \(L_s\): horizontal dispersal scale, km.
- \(z_i\): seabed depth, m.
- \(Z_s\): vertical-separation scale, m.
- \(a_{s,ij}\): bounded directional transport modifier, 0–1.

Set \(\beta_{s,ii}=0\). This is a screening model, not a fitted
transport model.

Occupancy follows:

\[
\frac{dp_{s,j}}{dt}
=
(1-p_{s,j})
\left[
b_{s,j}+
\sum_{i\ne j}\beta_{s,ij}p_{s,i}
\right]
-e_{s,j}p_{s,j}.
\]

The background colonization hazard \(b_{s,j}\) allows recruitment from
outside the observed network.

For the homogeneous approximation:

\[
\frac{dp}{dt}=c\bar Kp(1-p)-ep,
\]

the persistence condition is:

\[
c\bar K>e,
\]

not a universal numerical threshold of \(\bar K=0.15\).

### Interpretation of the original numerical examples

Under the assumed distance-only kernel:

\[
k(d)=\exp\!\left(-\frac{d}{50\ \mathrm{km}}\right),
\]

the submitted values are:

\[
k(15\ \mathrm{km})\approx0.741,
\qquad
k(80\ \mathrm{km})\approx0.202.
\]

These are illustrative kernel weights. They are not independently
established historical and present-day mean connectivity measurements.

The draft’s reported NFCI values and decline percentage are not retained
as regional findings because their observational inputs, normalization,
and uncertainty have not been supplied.

No collapse margin, whale-abundance requirement, or 40% reduction in
active carbon transport is asserted.

### Carbon accounting

Separate:

- Organic carbon delivered to a receiving region.
- Standing carbon inventory within deposited patches.
- Colonization connectivity.
- Consumer-mediated carbon redistribution.
- Long-term carbon retention.

For whale-derived delivery:

\[
D_{\mathrm{whale}}
=
\sum_w
N_wm_w\overline M_wf_{\mathrm C,w}p_{\mathrm{dep},w},
\]

where \(m_w\) is annual mortality and \(f_{\mathrm C,w}\) converts carcass
wet mass into carbon mass.

Wood and kelp delivery require separate source-production, mobilization,
transport, and deposition terms. Forest area and canopy area alone do
not determine deep-sea carbon delivery.

### Knowledge-graph interpretation

Every proposed relationship must carry an explicit predicate and
evidence status.

| Subject | Predicate | Object | Status |
|---|---|---|---|
| Whale fall | can support bone-associated taxa | Osedax | Established general association |
| Monterey Canyon | transports | Organic material toward deeper receiving environments | Supported observation |
| Mendocino woody debris | may contribute to | Monterey Canyon wood deposits | Regional hypothesis |
| Organic-fall connectivity | may influence | Specialist occupancy | Research hypothesis |
| Kelp source beds | supply detached material to | Kelp deposits | General process; regional delivery requires estimation |
| NFCI | summarizes under a stated model | Taxon-specific network conditions | Proposed diagnostic |

Graph relationships are not automatically causal statements. A
published link does not establish that its scientific content has been
validated.

### Scientific limitations

Do not encode the following as established facts:

- All organic-fall specialists share one dispersal scale.
- All organic deposits have a 30-year useful lifetime.
- Osedax connectivity can be inferred from sulfide production alone.
- A particular lanternfish species represents half of global fish
  biomass.
- Beaver restoration necessarily increases deep-sea wood delivery.
- Carbon delivered to depth is permanently sequestered.
- A network-index threshold identifies regional ecosystem collapse.

### Publication and integrity

Before creating content-addressed endpoints:

- Finalize and review the exact UTF-8 content.
- Confirm the attribution text.
- Review the public-disclosure scope.
- Record serialization and IPFS import settings.
- Use the approved SHA-256 commitment profile.
- Check compatibility with the target Bostrom client and network.
- Resolve every endpoint from actual content.
- Retain the exact bytes associated with each published endpoint.

A CID can support content-integrity checking; it does not establish
truth or authorship. Different import settings can produce different
CIDs for the same file content.

Do not embed the memo’s own final CID inside the bytes from which that
CID is calculated. Record the resulting CID in a separate publication
receipt.

### Approval boundary

This memo does not authorize:

- Uploading or pinning.
- Publishing an account-to-content association.
- Signing a message.
- Broadcasting graph links.
- Spending funds.
- Exporting repository or account data.

Each external action requires review of its exact payload, destination,
account where applicable, and cost or resource implications.

### Suggested transaction memo

For later review only:

`NFCI-CC research memo v2.0 | proposed model | regional calibration pending`

This text intentionally excludes uncalibrated connectivity results and
does not claim account authentication.

### Verification boundaries

Assess independently:

- Content integrity: do retrieved bytes match the recorded content
  address and import profile?
- Transaction provenance: which account signed the included
  transaction?
- Attribution declaration: which creator statement appears in the
  content?
- Scientific support: which sources and observations support each
  claim?
- Publication availability: is the content retrievable at the time
  checked?

None of these checks substitutes for the others.

### Derivatives and corrections

Derivatives should identify modifications and preserve appropriate
attribution and license information.

Later corrections should receive a new content version and new content
address. A separately published correction notice may describe the
relationship to an earlier version; it must not imply that earlier
distributed copies have been erased.

# End Memo
