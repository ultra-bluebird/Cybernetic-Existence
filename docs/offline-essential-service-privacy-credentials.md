# Offline Essential Service Privacy Credentials

## Status and scope

This document specifies a proposed privacy-preserving credential architecture for optional service-continuity and resource-accounting workflows in offline or low-connectivity conditions.

It does not define a gate for emergency shelter, water, cooling, sanitation, urgent medical referral, evacuation information, or other essential services.

The central service rule is:

\[
\operatorname{EssentialServiceAccess}(p) = \text{available}
\]

for any person \(p\) seeking essential assistance, without requiring identity, citizenship, age, disability, income, housing documentation, phone ownership, online account, device credential, or cryptographic proof.

The purpose of a privacy credential is to reduce disclosure where a person **chooses** to use an optional continuity feature. It must never be used to make survival, shelter, cooling, water, sanitation, or emergency information contingent upon a cryptographic artifact.

## Core principle

The safe priority order is:

\[
\text{Immediate essential access}
>
\text{human assistance}
>
\text{offline public information}
>
\text{optional privacy credential}
>
\text{administrative reconciliation}
\]

A proof failure, expired credential, unavailable issuer key, damaged device, lost wallet, dead battery, unsupported format, or cryptographic error must not produce denial of essential assistance.

\[
\operatorname{ProofFailure}
\Rightarrow
\operatorname{OfferEssentialService}
\]

not:

\[
\operatorname{ProofFailure}
\Rightarrow
\operatorname{DenyEssentialService}
\]

## Appropriate and inappropriate uses

| Use case | Privacy credential appropriate? | Required fallback |
|---|---:|---|
| Entry to emergency shelter | No | Walk-in access |
| Entry to cooling center | No | Walk-in access |
| Potable water, sanitation, emergency information | No | Walk-in access |
| Accessible transportation information | No | Walk-in access |
| Optional continuity between community service sites | Yes, only if the person chooses | Human-assisted and no-credential route |
| Optional reusable meal, supply, or transit voucher | Yes, if not required for essentials | Equivalent essential provision without credential |
| Duplicate-prevention for limited nonessential inventory | Possibly, with public review | Manual equitable process |
| Post-event aggregate reconciliation | Yes, using aggregate privacy-safe evidence | No effect on immediate aid |
| Donation or mutual-aid acknowledgment | Yes, strictly optional | No impact on receiving aid |
| Public-benefit eligibility enforcement | Generally not for essential services | Universal access and human review |

## Privacy and access invariants

\[
D_{\text{person,persistent}} = 0
\]

\[
D_{\text{credential-log}} = 0
\]

\[
D_{\text{presentation-linkage}} = 0
\]

\[
G_{\text{credential-required}} = 0
\]

\[
G_{\text{network-required}} = 0
\]

\[
G_{\text{device-required}} = 0
\]

\[
G_{\text{identity-required}} = 0
\]

Where:

- \(D_{\text{person,persistent}}\) is persistent person-derived data.
- \(D_{\text{credential-log}}\) is a retained record of presentations.
- \(D_{\text{presentation-linkage}}\) is the ability to correlate multiple uses by the same person.
- \(G_{\text{credential-required}}\) is a credential gate for essential access.
- \(G_{\text{network-required}}\) is an online verification dependency.
- \(G_{\text{device-required}}\) is a requirement for a personal phone or specialized device.
- \(G_{\text{identity-required}}\) is an identity proof requirement.

## Architectural recommendation

### Use signed capability statements first

A complete general-purpose zero-knowledge proof system is not necessary for the initial offline profile. The immediate, field-usable architecture is:

1. A community-approved issuer signs a narrow optional capability statement.
2. The holder stores the credential locally, on paper, a user-controlled device, or another accessible carrier.
3. The holder may present a derived proof or selective disclosure presentation.
4. A local verifier checks the issuer signature against a preloaded trusted-key package.
5. The verifier retains no presentation history.
6. If verification fails, optional administrative handling may fall back to a human process.
7. Essential service access remains available regardless.

W3C Verifiable Credentials support selective disclosure, allowing a holder to reveal only the information needed to a verifier; a verifier can verify a presentation without involving the issuer during that presentation. [212] The W3C Verifiable Credentials overview also describes BBS-based selective disclosure proofs, where a holder derives a selectively disclosed proof from an issuer’s base proof. [215][222]

### Credential statement

A narrow credential should assert only a purpose-limited capability such as:

```text
This holder may optionally receive one community-issued transit-support voucher
during the stated public emergency period.
```

It should not assert a diagnosis, augmentation type, disability status, home address, income, citizenship, age, medical condition, or personal identity unless a separate lawful and genuinely necessary process requires it.

The predicate should be minimal:

\[
\operatorname{eligibleForOptionalSupport} = \text{true}
\]

not a bundle of personal claims:

\[
(
\text{name},
\text{address},
\text{age},
\text{health},
\text{income},
\text{device},
\text{identity}
)
\]

## Offline trust model

### Preloaded trust bundle

Offline verification requires a locally installed, versioned trust bundle:

```text
Trusted issuer public keys.
Issuer key identifiers.
Credential format versions.
Accepted proof suites.
Validity periods.
Revocation or suspension snapshot.
Emergency override policy.
Package signature.
Package expiration policy.
Rollback package.
```

The verifier checks a signed local package:

\[
\operatorname{VerifySignature}(M,\sigma,K_{\text{root}}) = \text{true}
\]

Where:

- \(M\) is the trust-bundle manifest.
- \(\sigma\) is its signature.
- \(K_{\text{root}}\) is an authorized public root key.

### Outage constraint

No central authority is contacted during ordinary presentation verification:

\[
\operatorname{NetworkRequest} = 0
\]

The trusted issuer may have existed before an outage, but offline verification depends on previously distributed public keys and validity information.

This means that “without a central authority during the outage” is feasible only in a limited sense:

- A verifier can validate a pre-issued cryptographic credential offline.
- A verifier cannot safely discover a previously unknown issuer offline.
- A verifier cannot reliably learn real-time revocation status without a preloaded signed status snapshot.
- A new credential cannot be securely issued by an untrusted party merely because connectivity is absent.

Therefore, essential access cannot depend on credential status.

## Credential options

| Option | Main strength | Offline feasibility | Linkability risk | Recommended role |
|---|---|---:|---:|---|
| Signed paper or QR capability token | Simple, accessible, low-compute | High | Moderate unless one-time or blinded design is used | Early optional voucher continuity |
| COSE or CBOR signed credential | Compact binary representation | High | Moderate if holder identifier is included | Low-power offline verifier profile |
| SD-JWT VC | Selective disclosure with JWT-oriented tooling | Moderate | Depends on claim and holder-binding design | Interoperable optional disclosures |
| BBS selective-disclosure credential | Derived selective-disclosure proofs | Moderate | Can reduce disclosure and proof correlation when designed carefully | Advanced privacy profile |
| Bulletproof range or set-membership proof | Compact proofs for certain arithmetic statements | Moderate | Depends on statement and transcript design | Specialized local proofs |
| zk-STARK | Transparent setup and post-quantum-oriented proof properties | Often heavier for constrained systems | Depends on application design | Research profile, not initial Cortex-M baseline |
| zk-SNARK | Succinct proofs and fast verification in some systems | Requires careful trusted-setup or proof-system choice | Depends on circuit and identifier design | Research profile with independent review |

## Scheme selection guidance

### Immediate implementation profile

For a low-power, offline public-service verifier, begin with:

- Signed capability statement.
- Short validity period.
- Local issuer-key bundle.
- No holder identifier.
- No presentation log.
- Accessible paper and digital representation.
- Human-assisted and no-credential fallback.
- Optional one-time serial management only when it does not restrict essential aid.

This profile is easier to inspect, implement, recover, and explain than a general-purpose proof circuit.

### Selective-disclosure profile

When the program needs a person to show only a narrow predicate, use a verifiable credential with selective disclosure.

Examples:

```text
This optional voucher is valid during the declared emergency window.
This optional transit-support benefit was issued by an approved community partner.
This carrier presents a currently valid community capability without revealing unrelated fields.
```

W3C describes selective disclosure as allowing holders to provide verifiers precisely the information needed and nothing more. [212] IETF SD-JWT VC work specifies formats and validation rules for verifiable credentials with and without selective disclosure, based on selective-disclosure JWT conventions. [214][217]

### ZKP research profile

Use Bulletproofs, zk-SNARKs, or zk-STARKs only after the actual predicate, device class, memory budget, proof-size limit, verification time, security assumptions, trusted-setup requirements, and recovery model are specified.

A proof-size target such as:

\[
\operatorname{ProofSize} < 1024 \text{ bytes}
\]

and a verification target such as:

\[
T_{\text{verify}} < 100 \text{ ms}
\]

must be treated as a benchmark requirement, not an assumption. It depends on:

- The ZKP system.
- The circuit or statement complexity.
- Curve or field arithmetic.
- Hash function.
- Compiler and optimization mode.
- Cortex-M model and clock rate.
- Available RAM and flash.
- Signature verification cost.
- Credential parsing cost.
- Revocation-status checks.
- Constant-time implementation quality.
- Side-channel protections.

A deployment should not claim compliance until measured on the intended hardware and documented with reproducible test vectors.

## Proof and verification model

### Predicate proof

Let \(C\) be an optional credential, \(P\) a permitted predicate, and \(r\) a fresh verifier challenge.

The holder produces:

\[
\pi =
\operatorname{Prove}
(
C,
P,
r
)
\]

The verifier checks:

\[
\operatorname{Verify}
(
K_{\text{issuer}},
P,
r,
\pi
)
=
\text{true}
\]

The verifier learns only that predicate \(P\) holds, within the documented limitations of the proof system and protocol.

### Freshness and replay resistance

A local verifier provides a fresh challenge:

\[
r \leftarrow \{0,1\}^{256}
\]

The proof must bind to \(r\):

\[
\operatorname{Verify}
(
K_{\text{issuer}},
P,
r,
\pi
)
=
\text{true}
\]

A presentation bound to one challenge should fail for another:

\[
r_1 \neq r_2
\Rightarrow
\pi_{r_1}
\not\equiv
\pi_{r_2}
\]

This reduces replay risk. It does not itself solve issuer revocation, physical token theft, coercion, or side-channel risk.

### Expiry

Let \(t\) be a local verifier clock, \(t_{\text{start}}\) a credential start time, and \(t_{\text{end}}\) its end time:

\[
t_{\text{start}}
\leq
t
\leq
t_{\text{end}}
\]

The verifier may accept a credential only within its declared validity window, subject to a documented clock-uncertainty policy.

However:

\[
\operatorname{CredentialExpired}
\Rightarrow
\operatorname{EssentialServiceStillAvailable}
\]

## Offline issuance model

### Primary issuance pathway

Before a foreseeable emergency season or during normal operations:

1. Community-authorized issuers create optional credentials.
2. Credentials are issued through accessible, non-coercive channels.
3. The holder receives a readable paper representation, accessible digital representation, or both.
4. Public verifiers receive signed trust bundles and revocation snapshots.
5. Community sites test verification offline.
6. Every service site prepares a no-credential route.

### Distributed issuer model

During network outage, multiple independent community issuers can issue optional local capability statements only when they already possess:

- Pre-authorized signing keys.
- Defined scopes.
- Bounded validity periods.
- Public accountability rules.
- Offline audit and reconciliation process.
- Secure key storage.
- Revocation and incident response process.

The issuer authority is distributed, not absent.

\[
\operatorname{OfflineIssue}
\Rightarrow
\operatorname{PreAuthorizedIssuer}
\]

A new, unknown “issuer” should not become trusted automatically during an emergency.

### Community continuity model

A practical model uses several independently governed issuers:

```text
Public library system.
Community health partner.
Mutual-aid organization.
Emergency management office.
Accessible transportation provider.
Shelter coalition.
Indigenous, neighborhood, or community governance partner where appropriate.
```

Each issuer has narrow capability scope and a public, reviewable trust-bundle entry. No single issuer becomes a mandatory gatekeeper for essential assistance.

## Privacy and anti-linkability

### No persistent presentation log

The verifier must not store:

```text
holder identifier
credential identifier
proof transcript
device identifier
BLE address
NFC identifier
IP address
location trace
camera image
voice recording
search history
service-use history
medical or disability information
```

The verifier may retain only aggregate, non-personal operational measurements where justified:

```text
number of optional credentials successfully verified in a reporting interval
number of verification failures by technical category
trust-bundle version
software version
aggregate verifier uptime
aggregate accessibility fallback availability
```

### Aggregation condition

For reporting interval \(T\):

\[
R_T =
(
N_{\text{success}},
N_{\text{technical-failure}},
N_{\text{fallback-used}}
)
\]

The report must exclude:

\[
\operatorname{Link}(R_T,\text{person}) = \varnothing
\]

Use long enough aggregation windows and small-cell suppression to avoid exposing a rare credential user.

### Anti-correlation rule

If a credential format uses a static public identifier, it may enable correlation across presentations. The preferred design is:

\[
\operatorname{presentation}_1
\not\leftrightarrow
\operatorname{presentation}_2
\]

unless the person knowingly chooses a reusable capability that needs continuity. Any unavoidable linkability must be explicitly documented before issuance.

## Accessible representations

Optional credentials must not assume a smartphone, network connection, camera, modern browser, NFC-capable device, or fine-motor interaction.

Provide equivalent representations:

| Representation | Accessibility value | Privacy rule |
|---|---|---|
| Plain-language paper credential | Works without battery, app, or network | No printed personal profile; do not retain scan log |
| Large-print credential | Supports low vision | Same limited capability statement |
| Tactile or assisted reference format | Supports independent or assisted use where feasible | No identity gate |
| Local-device credential | Supports user-controlled digital storage | No cloud dependency for presentation |
| NFC representation | Supports simple proximity handoff | No mandatory persistent identifier |
| QR representation | Supports common offline scanning | Do not embed person-identifying claims |
| Human-assisted verification | Supports people unable to use a token | Essential service remains available regardless |

## Verification outcomes

The verifier returns a clear, accessible, non-stigmatizing result:

```text
Optional capability verified.
Optional capability could not be verified.
This does not affect access to essential services.
A staff member can help with alternatives if you want assistance.
```

The verifier must never state:

```text
You are not eligible for safety.
You failed identity verification.
Your medical condition is invalid.
Your device is unsupported, so service is unavailable.
You must connect to the internet.
```

## Solidity role

On-chain verification is not required for immediate offline service access.

A blockchain or smart contract cannot be the real-time dependency for an offline shelter or cooling-center workflow:

\[
\operatorname{OfflineService}
\not\Leftarrow
\operatorname{OnChainVerification}
\]

Solidity may be considered later for:

- Publishing non-personal issuer-key commitments.
- Publishing software or trust-bundle hash commitments.
- Publishing aggregate, privacy-safe reconciliation commitments.
- Auditing signed package versions.

It must not be used to publish credential presentations, holder identifiers, service-use events, or emergency access attempts.

## Conformance requirements

### Mandatory privacy tests

- Verify that no presentation payload, identifier, or proof transcript is persisted.
- Verify that device discovery and communication metadata are not logged.
- Verify that a failed proof does not block essential service access.
- Verify that expired trust bundles trigger human review or optional credential fallback, not essential-service denial.
- Verify that local verifier operation requires no network.
- Verify that the public interface displays clear no-credential access information.
- Verify that paper, digital, and human-assisted paths remain usable.
- Verify that metrics use aggregate, small-cell-safe reporting.

### Mandatory security tests

- Test malformed credential handling.
- Test signature failure handling.
- Test proof failure handling.
- Test replay of a proof against a fresh challenge.
- Test expired credential handling.
- Test expired issuer-key bundle handling.
- Test verifier clock drift handling.
- Test revocation-snapshot staleness handling.
- Test power interruption during verification.
- Test fallback operation after device or scanner failure.
- Test that updates cannot silently add identity collection or essential-service gates.

### Benchmark requirements

A hardware benchmark report must include:

```text
Target processor class.
Clock frequency.
Compiler version.
Optimization profile.
Available RAM.
Available flash.
Proof-system implementation version.
Credential format.
Proof size in bytes.
Verification latency distribution.
Peak memory use.
Energy per verification.
Signature verification time.
Parsing time.
Replay-defense time.
Failure behavior.
Constant-time or side-channel protection statement.
```

The benchmark passes only when measured results meet the declared profile:

\[
\operatorname{ProofSize}_{p95} < 1024 \text{ bytes}
\]

\[
T_{\text{verify},p95} < 100 \text{ ms}
\]

for the actual target device and actual predicate.

## Project metrics

| Metric | Score | Basis |
|---|---:|---|
| knowledge_factor | 0.89 | Uses standards-oriented selective disclosure, signed trust bundles, explicit offline limits, benchmark requirements, and accessible failure modes |
| eco_impact_value | 0.73 | Supports reusable local public-service infrastructure and reduces unnecessary centralized data infrastructure when implemented with durable, repairable devices |
| harm_risk | 0.22 | Risks remain from credential loss, revocation staleness, coercion, and implementation flaws; constrained by unconditional essential access, no logs, and human fallback |
| accessibility_impact | 0.96 | Paper, digital, NFC, QR, and human-assisted paths are optional and equivalent; no device, account, or credential is required for essentials |
| rights_alignment | 0.99 | Preserves dignity, privacy, autonomy, data minimization, non-discrimination, offline access, accessibility, and essential-service independence |
