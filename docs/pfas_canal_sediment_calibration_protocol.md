# PFAS Canal-Sediment Calibration Protocol

## Model boundary

The model is applied only to one named PFAS analyte, one defined canal reach, one
sediment compartment, one depth interval, and one declared concentration basis.

The concentration basis MUST be one of:

- dry-mass-normalized sediment concentration;
- porewater concentration;
- suspended-solids-normalized concentration; or
- dissolved-water concentration.

A model fit MUST NOT mix concentration bases.

## Parameter semantics

Before fitting, the study MUST define:

- `k_d`: effective irreversible loss or transformation rate from the chosen
  compartment;
- `k_r`: effective replenishment, desorption, remobilization, or source-release rate;
- `C_0`: initial concentration at a recorded reference time;
- `t`: elapsed time from the recorded reference time.

For persistent PFAS, `k_d` MUST NOT be labelled biodegradation unless direct,
analyte-specific transformation evidence supports that interpretation.

## Required field record

Each sample event MUST retain:

- site and fixed station identifier;
- station geometry and depth interval;
- sample matrix and concentration basis;
- date and time;
- water level, flow or velocity, and recent precipitation;
- temperature;
- conductivity or salinity;
- pH;
- oxidation-reduction potential where available;
- turbidity and suspended-solids context;
- sediment grain size, organic carbon, bulk density, moisture, and CEC;
- canal operation and maintenance events;
- upstream and lateral-input observations where available;
- analytical method, reporting limit, qualifier, and QA/QC result;
- chain-of-custody record;
- laboratory result and uncertainty.

## Fit eligibility

A parameter fit is eligible only when:

- at least three temporally distinct observations exist for the same defined
  analyte-compartment-station combination;
- input and disturbance events are recorded for the fitting period;
- censored results are handled using a declared method;
- units are consistent;
- model residuals are retained;
- parameter confidence intervals or posterior intervals are reported.

## Rejection conditions

The fit MUST be rejected or expanded when:

- major unmodeled source loading occurs;
- dredging, cleaning, or resuspension invalidates compartment continuity;
- concentration bases are mixed;
- station identity or depth interval changes without a new model version;
- quality controls fail;
- fitted parameters require negative rates;
- residual structure is correlated with flow, salinity, or sediment class and the
  model does not include the relevant process.

## Interpretation boundary

A fitted rate is a conditional site-model parameter. It is not a universal PFAS
degradation constant and is not transferable to another analyte, sediment type,
hydrologic regime, canal reach, or time period without validation.
