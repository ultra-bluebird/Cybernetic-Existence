# Bio-Curtain Interception Sizing Protocol

## Purpose

This protocol defines a research-sizing and verification method for a contained,
non-autonomous pollutant-interception barrier.

It does not authorize installation, environmental release, bioaugmentation, PFAS
destruction, nutrient-removal performance, canal modification, aeration, or physical
actuation.

## Required input record

Every sizing run MUST retain:

- target analyte or nutrient;
- influent concentration and flow;
- influent mass load;
- flow time series;
- corridor residence time;
- outfall geometry;
- water depth, width, and velocity profile;
- effective curtain capture area;
- bypass fraction;
- FOG media-class distribution;
- FOG fouling, head-loss, and maintenance evidence;
- treatment-media identity;
- sorption or transformation evidence;
- unit test efficiency;
- media age and breakthrough state;
- containment basis;
- ecological review;
- human review;
- source and uncertainty records.

## Target definition

The target is:

`target_load_reduction_fraction > 0.90`

The target MUST be evaluated against mass load, not concentration alone.

`load = concentration * flow`

The report MUST distinguish:

- apparent concentration reduction;
- dilution;
- sorption transfer;
- transformation;
- confirmed defluorination;
- destruction;
- removal for disposal;
- unknown fate.

## Idealized sequential-unit estimate

For independently measured unit efficiency eta_unit:

`unit_count =
 ceiling(ln(1 - target_efficiency) / ln(1 - eta_unit))`

This estimate is valid only if:

- units are sequential;
- unit capture zones are independent;
- no unmeasured bypass exists;
- hydraulic short-circuiting is excluded;
- unit efficiency is measured in a matching analyte, matrix, flow, and media-age
  condition;
- uncertainty is included.

The estimate MUST be marked `design_assumption` until a local verification study is
completed.

## Residence-time check

For an effective first-order model:

`system_efficiency = 1 - exp(-k_effective * contact_time)`

For a target reduction exceeding 90 percent:

`k_effective * contact_time >= ln(10)`

`k_effective` MUST be analyte-specific, matrix-specific, flow-specific, media-age
specific, and supported by direct measurement.

## FOG coupling

FOG media records MAY affect sizing only through measured or reviewed parameters:

- effective open-area reduction;
- hydraulic head loss;
- capture efficiency change;
- bypass fraction;
- fouling rate;
- maintenance interval;
- resuspension risk.

A FOG class label alone MUST NOT be treated as a hydraulic coefficient.

## Hard gates

A sizing result is `review_required` when:

- target analyte is unspecified;
- mass load cannot be calculated;
- unit efficiency is not measured;
- hydraulic bypass is unknown;
- media breakthrough state is unknown;
- PFAS fate is described as destruction without transformation-product evidence;
- defluorination is claimed without fluoride mass balance;
- open environmental bioaugmentation is proposed;
- containment, ecological review, or human review is absent.

## Output states

The system MAY output:

- `insufficient_input`;
- `design_assumption`;
- `contained_bench_verification`;
- `review_required`;
- `excluded`.

The system MUST NOT output:

- deployment approved;
- environmental release approved;
- PFAS destroyed;
- biological remediation certified;
- autonomous placement command.
