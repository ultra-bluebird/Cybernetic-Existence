# Phoenix AMA Hex Directory Convention

## Purpose

This convention represents a declared hexagonal tessellation of the Phoenix Active
Management Area using ordinary directories and existing project file formats.

It does not create a new geospatial file format. It does not replace the Arizona
Department of Water Resources boundary source, property records, survey controls,
permit requirements, or local utility authorization.

## Source boundary rule

The tessellation MUST be derived from a version-pinned Phoenix AMA boundary dataset.

Each tessellation release MUST record:

- source publisher;
- source dataset title;
- source dataset version, revision, or retrieval timestamp;
- coordinate reference system;
- clipping policy for cells intersecting the AMA boundary;
- hex side length in metres;
- grid origin in the declared coordinate reference system;
- geometry revision;
- declared inclusion threshold for partial boundary cells.

The project MUST retain the source reference and the local derivation parameters.
A directory path is an implementation locator, not proof of a legal boundary.

## Root placement

The repository-specific Phoenix anchor registry remains authoritative for anchor
routing. A tessellation release is represented below the selected anchor route:

`eco_restoration_shard/cyboquatic_progress/<utc-date>/hex/`

The root contains an ordinary `README.md`, an ALN policy file, SQL schema and
migration files, language-specific validators, and a `cells/` directory.

## Cell directory identity

Each cell has a stable logical identity:

`phx-ama-<grid-revision>-q<axial-q>-r<axial-r>`

Each cell uses an ordinary directory:

`cells/phx-ama-<grid-revision>-q<axial-q>-r<axial-r>/`

The axial coordinates identify graph topology. They are not latitude/longitude,
not parcel identifiers, not a utility asset identifier, and not a claim of
jurisdiction.

## Required cell files

Each active cell directory MUST contain:

- `README.md`
- `aln/corridor_geometry.aln`
- `sql/cell_invariants.sql`
- `sql/measurements.sql`
- `kotlin/StreamGaugeCsvParser.kt`
- `java/CorridorCalibrationValidator.java`

A cell MAY contain:

- `evidence/` for source manifests, measurement metadata, and review records;
- `tests/` for local test vectors;
- `output/` for derived reports that are reproducible from retained inputs.

No raw personal data, governance DID, public CyberRank information, or machine-control
credential may be placed in the cell directory.

## Neighbor links

A cell directory MAY include a Markdown neighbor ledger:

`neighbors.md`

Each row declares:

- local `anchor_id`;
- local axial coordinate;
- edge index;
- claimed neighbor `anchor_id`;
- expected neighbor axial coordinate;
- reciprocal edge index;
- geometry revision;
- validation status.

Neighbor links are valid only if both cells share:

- `grid_id`;
- `geometry_revision`;
- `basin_crs`;
- corridor identifier where the link is a corridor edge;
- reciprocal opposite-edge claims.

## Boundary-cell policy

A cell whose polygon intersects the Phoenix AMA boundary is categorized as:

- `inside`: its retained area fraction is at or above the declared threshold;
- `partial`: it intersects the boundary but does not meet the retained-area threshold;
- `outside`: it has no retained intersection.

Only `inside` cells may be used as ordinary reference cells unless a study explicitly
includes `partial` cells and records the resulting area weight.

## Directory example

`eco_restoration_shard/cyboquatic_progress/2026-09-14/hex/`
`README.md`
`aln/phoenix_ama_hex_topology.aln`
`sql/phoenix_ama_hex_temporal.sql`
`kotlin/StreamGaugeCsvParser.kt`
`java/CorridorCalibrationValidator.java`
`cells/phx-ama-r1-q17-r-8/README.md`
`cells/phx-ama-r1-q17-r-8/aln/corridor_geometry.aln`
`cells/phx-ama-r1-q17-r-8/sql/cell_invariants.sql`
`cells/phx-ama-r1-q18-r-8/README.md`

## Review rule

A directory convention becomes active only after:

1. the selected Phoenix anchor has an authoritative registry entry;
2. the boundary source and grid derivation parameters are recorded;
3. topology validation passes for all declared shared corridor edges;
4. partial-cell treatment is documented;
5. the change receives human review.
