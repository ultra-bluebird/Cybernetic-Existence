# Canal Biofilm Methanotrophic Carbon Protocol

## Purpose

This protocol defines an evidence and accounting framework for evaluating the
methane-oxidation potential of canal-wall biofilms and its possible contribution to
a declared net climate-impact assessment.

It does not establish methane oxidation in Phoenix, carbon-negative operation,
biological safety, equipment authorization, open-environment bioaugmentation, or
physical control.

## Oxidation-potential equation

`O_bio =
 k_ox *
 A_wall *
 B_areal *
 f_methanotroph *
 (1 - f_salinity_inhibition)`

Units:

- `k_ox`: millimoles methane per gram dry weight per day;
- `A_wall`: square metres of wetted/colonized wall surface;
- `B_areal`: grams dry biofilm per square metre;
- `f_methanotroph`: dimensionless fraction in `[0, 1]`;
- `f_salinity_inhibition`: dimensionless fraction in `[0, 1]`;
- `O_bio`: millimoles methane per day.

## Evidence status

A published maximum oxidation potential from another canal system is a
`reference` or `calibration_prior`.

It MUST NOT be represented as:

- a Phoenix measurement;
- a universal microbial coefficient;
- evidence of persistent local methane oxidation;
- a carbon-negative finding;
- a basis for organism release;
- a basis for machinery operation.

## Local measurement requirement

A local parameter estimate requires:

- biofilm dry-mass sampling or a validated dry-mass proxy;
- wall-area and wetted-area measurement;
- methane concentration and, where applicable, methane flux;
- methane oxidation measurement;
- salinity or conductivity with conversion method;
- temperature;
- dissolved oxygen;
- pH;
- organic-carbon context;
- microbial-community evidence where used to estimate methanotroph fraction;
- season and flow state;
- sampling and analytical method;
- replicate samples;
- uncertainty;
- source and review status.

A non-detect result MUST be retained.

## Salinity model

A candidate local inhibition model is:

`f_salinity_inhibition(S) =
  1 / (1 + exp(-a * (S - S50)))`

`a` and `S50` are local calibration parameters.

The model MUST be compared with:

- no salinity-effect model;
- piecewise threshold model;
- alternative monotone model.

No salinity-inhibition curve is accepted without local evidence and review.

## Methane availability rule

Methanotroph abundance or methane oxidation potential MUST NOT be inferred solely from
methane flux, salinity, wall area, or biofilm presence.

The study record MUST distinguish:

- methane emitted;
- methane dissolved;
- methane oxidized;
- methane transported;
- methane not measured;
- oxidation not detected.

## Net carbon boundary

A net-negative conclusion requires:

- declared functional unit;
- methane-to-carbon-dioxide-equivalent conversion source and assessment horizon;
- direct energy measurement in joules;
- electricity or fuel impact factor;
- material and installation inventory;
- maintenance, cleaning, replacement, and disposal inventory;
- aeration and scrubbing energy;
- water and consumable inputs;
- biological side-effect assessment;
- uncertainty propagation;
- sensitivity analysis;
- independent review appropriate to the intended claim.

`O_bio > 0` is not sufficient for a net-negative claim.

## Hard gates

A result MUST remain `review_required` when:

- oxidation is not directly measured;
- dry biofilm mass is absent;
- salinity calibration is absent;
- methane availability is not measured;
- energy use is not metered;
- lifecycle boundary is incomplete;
- ecological review is unresolved;
- an open environmental bioaugmentation proposal is present;
- uncertainty analysis is absent.

## Output classes

The system MAY output:

- `reference_prior`;
- `local_measurement`;
- `not_detected`;
- `inconclusive`;
- `review_required`;
- `excluded`.

The system MUST NOT output:

- carbon-negative certified;
- environmental release approved;
- organism deployment approved;
- autonomous machine action.
