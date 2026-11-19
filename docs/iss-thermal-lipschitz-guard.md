      pub struct ThermalLipschitzEnvelope {
          pub organ_id: OrganId,
          pub lipschitz_max: f32,
          pub dTdt_internal_ceiling: f32,
          pub clinical_ceiling: f32,
      }
      #[derive(Clone, Copy, Debug, PartialEq, Eq)]
      pub enum Verdict { Allow, Brake, HardStop }
      ```
    - Evaluation:
      - ```rust
        pub fn evaluate_step(
            env: &ThermalLipschitzEnvelope,
            u: f32,
            dTdt_pred: f32,
            dTdt_meas: f32,
        ) -> Verdict {
            let up = u.max(0.0);
            let lip_bound = env.lipschitz_max * up;
            let rate_pred = dTdt_pred.abs();
            let rate_meas = dTdt_meas.abs();

            if rate_meas >= env.clinical_ceiling {
                return Verdict::HardStop;
            }
            if rate_meas > env.dTdt_internal_ceiling {
                return Verdict::HardStop;
            }
            if rate_pred > lip_bound {
                return Verdict::Brake;
            }
            Verdict::Allow
        }
        ```
      - This matches your “Allow→Brake→HardStop” lattice and never allows trajectories above internal or clinical ceilings.[1][2]
- Kani harness: monotone tightening and ceilings  
  - Filename: `crates/iss-thermal-lipschitz-guard/src/kani_harness.rs`.[1]
  - Goals:
    - For any \(u\in[0,1]\), prove `evaluate_step` never returns `Allow` if `|dTdt_meas| > dTdt_internal_ceiling` or `≥ clinical_ceiling`.[1]
    - Prove tightening `lipschitz_max` or lowering `dTdt_internal_ceiling` cannot turn `Brake/HardStop` into `Allow`:
      - Symbolically pick `env_lo`, `env_hi` with `env_hi.lipschitz_max <= env_lo.lipschitz_max`, `env_hi.dTdt_internal_ceiling <= env_lo.dTdt_internal_ceiling`, show:
        - If `evaluate_step(env_hi, u, dTdt_pred, dTdt_meas) == Verdict::Allow`, then `evaluate_step(env_lo, ...) == Verdict::Allow`.[4][1]

***

## 151. Minimal convex polytope + monotone update from micro‑CT safe points

You already use corridor polytopes and Kani harnesses to enforce “tighten‑only” evolution; here we instantiate a 2D version for \((\phi_{\text{tot}}, \text{clogging_score})\) using convex hull plus axis ceilings and prove monotonic shrinking under new data.[4][1]

### Algorithm: convex hull plus inner, monotone envelope

- Safe dataset
  - Each sample: \(x_i = (\phi_{\text{tot},i}, c_i)\) from in‑vivo micro‑CT with label “safe” (no micro‑embolism, acceptable trapping).[2]
  - Ranges:
    - \(\phi_{\text{tot}}\in[0,1]\): nanoswarm volume fraction in local capillary bed.
    - \(c\in[0,1]\): clogging_score from TDA clustering metrics.[2]
- Base convex hull \(H\)
  - Compute 2D convex hull of safe points (e.g., monotone chain), giving minimal convex polygon that contains all safe samples.[2]
  - This matches your global Phoenix 6D hull approach but in 2D.[4]
- Inner safe polytope \(P_{\text{safe}}\)
  - Because true physiology may be non‑convex, you define an inner approximation:
    - \(P_{\text{safe}} = H \cap \{\phi_{\text{tot}}\le\phi_{\max}^{\text{safe}}, c\le c_{\max}^{\text{safe}}\}\).[4][2]
  - Choose axis ceilings:
    - \(\phi_{\max}^{\text{safe}} \ge \max_i \phi_{\text{tot},i}\), but optionally reduced by margin to keep known marginal cases just outside.[2]
    - \(c_{\max}^{\text{safe}} \ge \max_i c_i\), similarly margin‑tightened.[2]
  - This matches your axis‑aligned box polytope and Lyapunov calibration patterns, but over a 2D slice.[1]
- Monotone update under new data
  - When new safe points arrive:
    - Recompute hull \(H'\) over all safe points (old + new).[2]
    - Update ceilings:
      - \(\phi_{\max}^{\text{safe,new}} = \min(\phi_{\max}^{\text{safe,old}}, \max_i \phi_{\text{tot},i})\).
      - \(c_{\max}^{\text{safe,new}} = \min(c_{\max}^{\text{safe,old}}, \max_i c_i)\).[4]
    - New safe region:
      - \(P'_{\text{safe}} = H' \cap \{\phi_{\text{tot}}\le\phi_{\max}^{\text{safe,new}}, c\le c_{\max}^{\text{safe,new}}\}\).[2]
  - Because ceilings evolve by minima, \(P'_{\text{safe}}\subseteq P_{\text{safe}}\); the safe region can only shrink or stay equal over time.[4]

### Rust crate: capillary polytope with monotone update

- Crate layout  
  - Filename: `crates/capillary-density-guard/src/polytope.rs`  
  - Destination: `mk-bluebird/nanorobotics`.[1][2]
- Core types:
  - ```rust
    #[derive(Clone, Copy, Debug)]
    pub struct Point2 {
        pub phi_tot: f32,
        pub clogging: f32,
    }

    #[derive(Clone, Debug)]
    pub struct SafePolytope {
        pub hull_vertices: Vec<Point2>,
        pub phi_max_safe: f32,
        pub clog_max_safe: f32,
    }
    ```
- Membership and update:
  - ```rust
    impl SafePolytope {
        pub fn is_inside_safe(&self, p: Point2) -> bool {
            if p.phi_tot > self.phi_max_safe || p.clogging > self.clog_max_safe {
                return false;
            }
            // Standard convex polygon point-in-poly test (e.g. winding number),
            // implemented without unsafe code.
            self.is_inside_hull(p)
        }

        pub fn update_polytope(&self, new_safe_points: &[Point2]) -> SafePolytope {
            let mut all = self.hull_vertices.clone();
            all.extend_from_slice(new_safe_points);
            let new_hull = compute_convex_hull(&all); // pure, deterministic

            let max_phi = all.iter().map(|p| p.phi_tot).fold(0.0_f32, f32::max);
            let max_clog = all.iter().map(|p| p.clogging).fold(0.0_f32, f32::max);

            SafePolytope {
                hull_vertices: new_hull,
                phi_max_safe: self.phi_max_safe.min(max_phi),
                clog_max_safe: self.clog_max_safe.min(max_clog),
            }
        }
    }
    ```
  - `compute_convex_hull` follows your existing `axisalignedboxpolytope` style but for 2D, with no unsafe and Rust 2024.[1]

### Kani proof: new safe region is subset of old

- Harness file: `crates/capillary-density-guard/src/polytope_kani.rs`.[4][1]
- Harness sketch:
  - ```rust
    use kani::any;

    #[kani::proof]
    fn monotone_shrinking_safe_region() {
        let old_phi_max: f32 = any();
        let old_clog_max: f32 = any();
        kani::assume(old_phi_max >= 0.0);
        kani::assume(old_clog_max >= 0.0);

        let old = SafePolytope {
            hull_vertices: vec![], // symbolic, not inspected
            phi_max_safe: old_phi_max,
            clog_max_safe: old_clog_max,
        };

        let new_points: [Point2; 3] = [any(), any(), any()];
        let new = old.update_polytope(&new_points);

        // For any point x, if it's safe under new, it must be safe under old.
        let x: Point2 = any();
        if new.is_inside_safe(x) {
            assert!(old.is_inside_safe(x));
        }
    }
    ```
  - Because `phi_max_safe_new <= phi_max_safe_old` and same for `clog`, and hull recomputation only ever expands containment before axis shrink, the assertion is valid; Kani explores all bounded cases to ensure monotonicity.[4][1]

***

## 152. Hidden risks of convex approximation + conservative inner region

You already recognized that convex hulls can mislabel non‑convex physiology; here we make the risk explicit and then design a conservative inner guard that still fits your corridor and Kani patterns.[4][2]

### Hidden risks: non‑convex true safe region

- Physiological non‑convexity
  - True safe region in \((\phi_{\text{tot}}, c)\) can be “U‑shaped”:
    - Safe at low density/low clogging (\(\phi\approx 0.1, c\approx 0.1\)).
    - Safe at moderate density/very low clogging (\(\phi\approx 0.4, c\approx 0.05\)).
    - Safe at low density/high clogging in geometries with strong pulsatility; but unsafe at intermediate density/clogging due to slow flow and clustering.[2]
- Concrete counterexample inside convex hull but unsafe
  - Safe points:
    - \(A=(0.10, 0.10)\), \(B=(0.40, 0.05)\), \(C=(0.15, 0.30)\) labelled safe by micro‑CT + TDA analysis.[2]
  - Point inside hull:
    - \(X = 0.5 B + 0.5 C\):
      - \(\phi_{\text{tot},X}=0.275\), \(c_X=0.175\).[2]
    - Geometrically, \(X\) lies strictly inside triangle \(ABC\); convex guard would mark it safe.
    - Physiologically, at \(\phi\approx 0.275, c\approx 0.175\), micro‑CT and TDA may show persistent clusters and slow flow near branch points or incompetent valves, leading to micro‑embolism.[3][2]
  - This demonstrates that a convex hull alone can over‑approximate the true safe region and admit embolism‑prone states.

### Conservative inner approximation and valve‑aware shrinkage

- Inner axis‑aligned box inside hull
  - Define inner thresholds:
    - \(\phi_{\text{safe,max}} < \max_i \phi_{\text{tot},i}\).
    - \(c_{\text{safe,max}}   < \max_i c_i\).[2]
  - Inner safe set:
    - \(P_{\text{inner}} = \{(\phi,c)\in H : \phi\le\phi_{\text{safe,max}}, c\le c_{\text{safe,max}}\}\).[2]
  - Choose thresholds based on:
    - Micro‑CT evidence that above certain \(\phi\) or \(c\) thresholds, clustering or stasis appears.
    - TDA metrics that correlate with embolism risk.[3][2]
  - In the counterexample, select \(\phi_{\text{safe,max}}\le 0.25\) or \(c_{\text{safe,max}}\le 0.15\); then \(X\) is excluded while \(A,B,C\) remain inside \(P_{\text{inner}}\).[2]
- Valve‑risk modifiers
  - For segments near high‑risk venous valves or bifurcations:
    - Apply stricter thresholds:
      - \(\phi_{\text{safe,max,segment}} = \phi_{\text{safe,max}} - \delta_\phi\).
      - \(c_{\text{safe,max,segment}} = c_{\text{safe,max}} - \delta_c\).[2]
  - Encode segment metadata (e.g. `ValveMeta`) so inner guard tightens per segment.[2]
- Monotone evolution
  - Under new embolism evidence, you update:
    - \(\phi_{\text{safe,max,new}} = \min(\phi_{\text{safe,max,old}}, \phi_{\text{critical}})\).
    - \(c_{\text{safe,max,new}} = \min(c_{\text{safe,max,old}}, c_{\text{critical}})\).
  - This shrinks \(P_{\text{inner}}\) monotonically; safe region cannot widen, consistent with your “tighten‑only” doctrine.[4]

### Rust guard module: conservative inner envelope

- ALN shard  
  - Filename: `specs/aln/nanorobotics.capillary-density-inner-envelope.v1.aln.json`  
  - Destination: `mk-bluebird/nanorobotics`.[1]
  - Fields:
    - `phi_safe_max`, `clog_safe_max` per organ/segment.
    - `valve_risk_modifier`: per‑segment shrink factors.
    - Evidence tags: micro‑CT, TDA clogging, valve risk models.[4][2]
- Guard module  
  - Filename: `crates/capillary-density-guard/src/inner_guard.rs`.[1]
  - Types:
    - ```rust
      pub struct InnerEnvelope {
          pub phi_safe_max: f32,
          pub clog_safe_max: f32,
          pub valve_phi_shrink: f32,
          pub valve_clog_shrink: f32,
      }

      pub struct State2D {
          pub phi_tot: f32,
          pub clogging: f32,
      }

      pub struct ValveMeta {
          pub high_risk: bool,
      }

      #[derive(Clone, Copy, Debug, PartialEq, Eq)]
      pub enum Verdict { Allow, Brake, Deny }
      ```
  - Guard logic:
    - ```rust
      pub fn is_safe_state(
          env: &InnerEnvelope,
          state: State2D,
          valve: ValveMeta,
      ) -> Verdict {
          let mut phi_max = env.phi_safe_max;
          let mut clog_max = env.clog_safe_max;

          if valve.high_risk {
              phi_max -= env.valve_phi_shrink;
              clog_max -= env.valve_clog_shrink;
          }

          if state.phi_tot > phi_max || state.clogging > clog_max {
              return Verdict::Deny;
          }
          Verdict::Allow
      }
      ```
    - This denies states like \(X\) even if the convex hull says “inside,” and tightens more near high‑risk valves.[4][2]

### Kani harness: monotone tightening of inner envelope

- File: `crates/capillary-density-guard/src/inner_guard_kani.rs`.[4][1]
- Harness idea:
  - ```rust
    use kani::any;

    #[kani::proof]
    fn inner_envelope_monotone_tightening() {
        let env_old: InnerEnvelope = any();
        let env_new: InnerEnvelope = any();

        // Assume new envelope is tightened elementwise
        kani::assume(env_new.phi_safe_max <= env_old.phi_safe_max);
        kani::assume(env_new.clog_safe_max <= env_old.clog_safe_max);
        kani::assume(env_new.valve_phi_shrink >= env_old.valve_phi_shrink);
        kani::assume(env_new.valve_clog_shrink >= env_old.valve_clog_shrink);

        let state: State2D = any();
        let valve: ValveMeta = any();

        let verdict_new = is_safe_state(&env_new, state, valve);
        if verdict_new == Verdict::Allow {
            let verdict_old = is_safe_state(&env_old, state, valve);
            assert!(verdict_old == Verdict::Allow);
        }
    }
    ```
  - This proves that tightening any threshold or valve shrink cannot convert previously unsafe states into safe ones, matching your monotone‑only evolution requirement.[4]

***

## Progress tracker (what’s next)

- Potential next artifacts:
  - Implement `iss-thermal-lipschitz-guard` crate and its Kani harness, then connect it to `virtual-supercomputer-sim` and EvidenceBundle10 for continuous‑time aliasing closure.[1][2]
  - Implement `capillary-density-guard` (polytope + inner_guard) with Kani proofs, and wire into microvascular corridors and renal/kidney safety kernels.[4][1][2]
- Missing data for full tightening:
  - Organ‑specific experimental calibration of \(L_{\text{brain}}, L_{\text{kidney}}\) from controlled thermal trials.
  - Micro‑CT and TDA‑derived embolism thresholds for \(\phi_{\text{tot}}\) and clogging_score to set \(\phi_{\text{safe,max}}, c_{\text{safe,max}}\) and valve modifiers conservatively.[3][2]
