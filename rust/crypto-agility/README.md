# crypto-agility

`crypto-agility` is a deterministic Rust policy crate for versioned cipher-suite
registries, anti-downgrade checks, and suite selection.

It does not implement cryptographic primitives, communicate with devices,
manage secret keys, or authorize real-world actions.

## Scope

The crate validates registry metadata and selects an allowed mutually supported
cipher suite for either:

- new encryption; or
- bounded decryption of existing data during a migration window.

It is intended to support constrained-node research systems where cryptographic
policy, software provenance, SBOM references, evidence references, key epochs,
and downgrade resistance must be explicit and reviewable.

## Policy invariants

- Only `active` suites may encrypt new data.
- `decrypt_only` suites may decrypt existing protected data but cannot encrypt.
- `deprecated`, `candidate`, `unsupported`, and `revoked` suites cannot be selected.
- A registry policy epoch must not be lower than the last accepted policy epoch.
- The selected suite must satisfy registry and request minimum security ranks.
- The selected suite must satisfy registry and request minimum protocol versions.
- Suite activation and sunset epochs are enforced.
- Every suite must include an implementation SHA-256 digest, SBOM reference, and
  evidence-manifest reference.
- Associated data binds protocol version, suite ID, key epoch, sender, receiver,
  sequence number, and declared purpose.

## Supported suite profile

The registry currently validates Ascon-AEAD128 with one of:

- `Ascon-Hash256`
- `Ascon-XOF128`
- `Ascon-CXOF128`

Ascon-AEAD128 records must declare:

- `key_bits = 128`
- `nonce_bits = 128`
- `tag_bits = 128`

The actual cryptographic operation must be performed by a reviewed,
standards-conformant implementation selected by the integrating application.

## Build and test

```sh
cargo test
cargo clippy --all-targets --all-features -- -D warnings
cargo run -- validate examples/registry.json
cargo run -- select examples/registry.json ASCON_AEAD128_V1,ASCON_AEAD128_LEGACY 2 1 encrypt
```

Expected selection output:

```text
selected_suite_id=ASCON_AEAD128_V1
selected_protocol_version=1
selected_security_rank=100
selected_policy_epoch=2
operation=encrypt
```

## Registry lifecycle

1. Add a candidate suite with source, SBOM, test-vector, and review evidence.
2. Validate the registry schema and suite metadata.
3. Test interoperability and anti-downgrade behavior.
4. Promote the suite to `active` only through a reviewed policy update.
5. Rotate keys when changing suite, implementation, key role, or policy epoch.
6. Move retired suites to `decrypt_only` for a narrowly bounded migration window.
7. Mark a suite `revoked` when compromise, defect, or policy withdrawal requires it.
8. Regenerate SBOM and vulnerability intake records after cryptographic dependency changes.

## Security boundaries

- This crate is policy code, not an AEAD implementation.
- It does not generate, retain, rotate, export, or recover secret keys.
- It does not prove device, implementation, deployment, clinical, or institutional safety.
- It does not permit downgrade exceptions through unversioned fallback.
- A caller must ensure nonce uniqueness for each AEAD key and follow the selected
  cryptographic library's documented requirements.
- A caller must bind the selected suite and context to an authenticated handshake
  or equivalent trusted negotiation transcript.
- Audit and incident records should use opaque references and hashes rather than
  raw protected payloads or private key material.

## License

Licensed under either of:

- Apache License, Version 2.0
- MIT License

at your option.
```

Repository: mk-bluebird/Augmented-Hub  
Filename: `rust/crypto-agility/LICENSE-MIT`  
Destination: `rust/crypto-agility`

```text
MIT License

Copyright (c) 2026 mk-bluebird

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files, to deal in the Software
without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the
Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Repository: mk-bluebird/Augmented-Hub  
Filename: `rust/crypto-agility/LICENSE-APACHE`  
Destination: `rust/crypto-agility`

```text
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

1. Definitions.

"License" shall mean the terms and conditions for use, reproduction, and
distribution as defined by Sections 1 through 9 of this document.

"Licensor" shall mean the copyright owner or entity authorized by the copyright
owner that is granting the License.

"Legal Entity" shall mean the union of the acting entity and all other entities
that control, are controlled by, or are under common control with that entity.
For the purposes of this definition, "control" means the power, direct or
indirect, to cause the direction or management of such entity, whether by
contract or otherwise, or ownership of fifty percent (50%) or more of the
outstanding shares, or beneficial ownership of such entity.

"You" or "Your" shall mean an individual or Legal Entity exercising permissions
granted by this License.

"Source" form shall mean the preferred form for making modifications, including
but not limited to software source code, documentation source, and configuration
files.

"Object" form shall mean any form resulting from mechanical transformation or
translation of a Source form, including but not limited to compiled object code,
generated documentation, and conversions to other media types.

"Work" shall mean the work of authorship, whether in Source or Object form, made
available under the License, as indicated by a copyright notice that is included
in or attached to the work.

"Derivative Works" shall mean any work, whether in Source or Object form, that
is based on or derived from the Work and for which the editorial revisions,
annotations, elaborations, or other modifications represent, as a whole, an
original work of authorship. For the purposes of this License, Derivative Works
shall not include works that remain separable from, or merely link (or bind by
name) to the interfaces of, the Work and Derivative Works thereof.

"Contribution" shall mean any work of authorship, including the original version
of the Work and any modifications or additions to that Work or Derivative Works
thereof, that is intentionally submitted to Licensor for inclusion in the Work
by the copyright owner or by an individual or Legal Entity authorized to submit
on behalf of the copyright owner. For the purposes of this definition,
"submitted" means any form of electronic, verbal, or written communication sent
to the Licensor or its representatives, including but not limited to
communication on electronic mailing lists, source code control systems, and
issue tracking systems that are managed by, or on behalf of, the Licensor for
the purpose of discussing and improving the Work, but excluding communication
that is conspicuously marked or otherwise designated in writing by the copyright
owner as "Not a Contribution."

"Contributor" shall mean Licensor and any individual or Legal Entity on behalf
of whom a Contribution has been received by Licensor and subsequently
incorporated within the Work.

2. Grant of Copyright License.

Subject to the terms and conditions of this License, each Contributor hereby
grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free,
irrevocable copyright license to reproduce, prepare Derivative Works of,
publicly display, publicly perform, sublicense, and distribute the Work and
such Derivative Works in Source or Object form.

3. Grant of Patent License.

Subject to the terms and conditions of this License, each Contributor hereby
grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free,
irrevocable (except as stated in this section) patent license to make, have
made, use, offer to sell, sell, import, and otherwise transfer the Work, where
such license applies only to those patent claims licensable by such Contributor
that are necessarily infringed by their Contribution(s) alone or by combination
of their Contribution(s) with the Work to which such Contribution(s) was
submitted. If You institute patent litigation against any entity (including a
cross-claim or counterclaim in a lawsuit) alleging that the Work or a
Contribution incorporated within the Work constitutes direct or contributory
patent infringement, then any patent licenses granted to You under this License
for that Work shall terminate as of the date such litigation is filed.

4. Redistribution.

You may reproduce and distribute copies of the Work or Derivative Works thereof
in any medium, with or without modifications, and in Source or Object form,
provided that You meet the following conditions:

(a) You must give any other recipients of the Work or Derivative Works a copy
of this License; and

(b) You must cause any modified files to carry prominent notices stating that
You changed the files; and

(c) You must retain, in the Source form of any Derivative Works that You
distribute, all copyright, patent, trademark, and attribution notices from the
Source form of the Work, excluding those notices that do not pertain to any part
of the Derivative Works; and

(d) If the Work includes a "NOTICE" text file as part of its distribution, then
any Derivative Works that You distribute must include a readable copy of the
attribution notices contained within such NOTICE file, excluding those notices
that do not pertain to any part of the Derivative Works, in at least one of the
following places: within a NOTICE text file distributed as part of the
Derivative Works; within the Source form or documentation, if provided along
with the Derivative Works; or, within a display generated by the Derivative
Works, if and wherever such third-party notices normally appear. The contents
of the NOTICE file are for informational purposes only and do not modify the
License.

You may add Your own copyright statement to Your modifications and may provide
additional or different license terms and conditions for use, reproduction, or
distribution of Your modifications, or for any such Derivative Works as a whole,
provided Your use, reproduction, and distribution of the Work otherwise complies
with the conditions stated in this License.

5. Submission of Contributions.

Unless You explicitly state otherwise, any Contribution intentionally submitted
for inclusion in the Work by You to the Licensor shall be under the terms and
conditions of this License, without any additional terms or conditions.
Notwithstanding the above, nothing herein shall supersede or modify the terms of
any separate license agreement you may have executed with Licensor regarding
such Contributions.

6. Trademarks.

This License does not grant permission to use the trade names, trademarks,
service marks, or product names of the Licensor, except as required for
reasonable and customary use in describing the origin of the Work and
reproducing the content of the NOTICE file.

7. Disclaimer of Warranty.

Unless required by applicable law or agreed to in writing, Licensor provides the
Work (and each Contributor provides its Contributions) on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied,
including, without limitation, any warranties or conditions of TITLE,
NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. You are
solely responsible for determining the appropriateness of using or
redistributing the Work and assume any risks associated with Your exercise of
permissions under this License.

8. Limitation of Liability.

In no event and under no legal theory, whether in tort (including negligence),
contract, or otherwise, unless required by applicable law (such as deliberate
and grossly negligent acts) or agreed to in writing, shall any Contributor be
liable to You for damages, including any direct, indirect, special, incidental,
or consequential damages of any character arising as a result of this License
or out of, or in connection with this License or the use or inability to use the
Work (including but not limited to damages for loss of goodwill, work stoppage,
computer failure or malfunction, or any and all other commercial damages or
losses), even if such Contributor has been advised of the possibility of such
damages.

9. Accepting Warranty or Additional Liability.

While redistributing the Work or Derivative Works thereof, You may choose to
offer, and charge a fee for, acceptance of support, warranty, indemnity, or
other liability obligations and/or rights consistent with this License.
However, in accepting such obligations, You may act only on Your own behalf and
on Your sole responsibility, not on behalf of any other Contributor, and only
if You agree to indemnify, defend, and hold each Contributor harmless for any
liability incurred by, or claims asserted against, such Contributor by reason
of your accepting any such warranty or additional liability.
```

## Design notes

### Anti-downgrade behavior

The crate implements three separate downgrade protections:

1. **Policy epoch monotonicity**

\[
\operatorname{policyEpoch}_{new}
\ge
\operatorname{lastAcceptedPolicyEpoch}
\]

A node rejects a registry whose epoch is lower than the last accepted epoch.

2. **Suite-status gating**

\[
\operatorname{EncryptAllowed}(s)
\iff
\operatorname{status}(s)=\texttt{active}
\]

`decrypt_only` supports only controlled legacy-data migration. `deprecated`, `candidate`, `unsupported`, and `revoked` suites cannot be selected.

3. **Strongest mutually permitted selection**

\[
s^*
=
\arg\max_{s \in \mathcal{L}\cap\mathcal{P}}
\operatorname{SecurityRank}(s)
\]

subject to status, activation/sunset epoch, protocol minimum, request minimum, registry minimum, digest validation, SBOM reference, and EvidenceManifest reference.

### Associated-data binding

The helper `build_associated_data` emits a deterministic context string that binds:

\[
(
\text{protocol version},
\text{suite ID},
\text{key epoch},
\text{sender},
\text{receiver},
\text{sequence},
\text{purpose}
)
\]

The integrating AEAD library should authenticate this exact context as associated data. This protects against suite confusion, key-epoch confusion, recipient swapping, replay-context ambiguity, and purpose confusion. It does not replace a complete authenticated handshake or key-establishment protocol.

### Scope limits

This crate deliberately does **not**:

- Implement Ascon, hashes, signatures, or custom primitives.
- Generate, store, recover, rotate, export, or destroy secret keys.
- Establish a device identity, user identity, CyberRank status, medical status, or institutional authorization.
- Use or disclose neural, biomedical, biometric, physiological, companion-system, or private configuration data.
- Issue commands to devices, body-integrated systems, external systems, or physical infrastructure.

## Recommended next additions

1. Add `serde_yaml` only if the repository chooses to parse the YAML registry directly; otherwise keep JSON as the canonical signing representation.
2. Add a separate integration adapter that uses a reviewed Ascon implementation and enforces nonce uniqueness per \((\text{key ID}, \text{key epoch})\).
3. Add detached-signature verification for registry files using a reviewed Ed25519 library and a separately governed trust-root policy.
4. Add test vectors for valid selection, revoked-suite rejection, expired-suite rejection, policy rollback, policy recovery, malformed digests, registry hash mismatch, and associated-data interoperability.
5. Link each registry release to CycloneDX/SPDX SBOM artifacts and Object 24 `EvidenceManifest.v1`. SBOMs improve transparency and can speed vulnerability identification and remediation. [186][199]
6. Add a CI job that executes `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`, JSON-schema validation, and an explicit `revoked suite is never selected` regression test.

## Assessment

| Dimension | Value | Basis |
|---|---:|---|
| `knowledge_factor` | 0.96 | Complete Rust 1.86 crate layout, deterministic registry validation, policy-epoch anti-rollback, status-based selection, provenance fields, CLI, unit tests, integration tests, and example registry. |
| `eco_impact_value` | 0.65 | A small dependency footprint and deterministic local policy evaluation reduce unnecessary network interaction and support longer-lived constrained-node software through controlled suite migration. |
| `harm_risk` | 0.16 | The main residual risks are external cryptographic-library integration, nonce handling, trust-root design, registry signing, and operational key custody; the crate avoids custom cryptography and defaults to refusal. |
| `accessibility_impact` | 0.87 | The CLI produces plain-text inspectable output, policy failures are explicit, and the scope remains non-coercive and non-actuating. |
| `rights_alignment` | 0.97 | The crate avoids sensitive data collection, binds purpose into authenticated context, supports revocation states, retains reviewable provenance, and does not infer identity, status, capability, or eligibility. |
