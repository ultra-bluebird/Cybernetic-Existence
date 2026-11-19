-- Repository: mk-bluebird/Augmented-Hub, and mk-bluebird/Skynet
-- Filename: world_save/+worldSQL/claimed_period_projection.sql
-- SPDX-License-Identifier: MIT OR Apache-2.0
-- SOVEREIGN-ATTRIBUTION:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Document credit only.
-- No acceptance, publication, or operation is authorized.
-- Apply ONCE after worldsaves.sql.
-- The host must stop and roll back on any error.

PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;

CREATE TEMP TABLE ws_projection_guard (
    requirement TEXT PRIMARY KEY,
    passed INTEGER NOT NULL CHECK (passed = 1)
) STRICT, WITHOUT ROWID;

INSERT INTO ws_projection_guard VALUES (
    'base_profile',
    CASE WHEN EXISTS (
        SELECT 1
        FROM ws_meta
        WHERE local_scope = 'local'
          AND schema_version = '1.0.0'
          AND event_profile = 'world-save-sql-events-1'
    ) THEN 1 ELSE 0 END
);

INSERT INTO ws_projection_guard VALUES (
    'commitment_columns',
    CASE WHEN (
        SELECT COUNT(*)
        FROM pragma_table_info('ws_commitment')
        WHERE name IN (
            'commitment_revision',
            'lifecycle',
            'claimed_from_seconds',
            'claimed_until_seconds'
        )
    ) = 4 THEN 1 ELSE 0 END
);

INSERT INTO ws_projection_guard VALUES (
    'horizon_columns',
    CASE WHEN (
        SELECT COUNT(*)
        FROM pragma_table_info('v_ws_resource_horizon')
        WHERE name IN (
            'commitment_revision',
            'supported_periods',
            'starts_at',
            'supported_through'
        )
    ) = 4 THEN 1 ELSE 0 END
);

INSERT INTO ws_projection_guard VALUES (
    'period_columns',
    CASE WHEN (
        SELECT COUNT(*)
        FROM pragma_table_info('v_ws_resource_periods')
        WHERE name IN (
            'commitment_revision',
            'start_seconds',
            'end_seconds',
            'result'
        )
    ) = 4 THEN 1 ELSE 0 END
);

INSERT INTO ws_projection_guard VALUES (
    'summary_columns',
    CASE WHEN (
        SELECT COUNT(*)
        FROM pragma_table_info('v_ws_release_summary')
        WHERE name IN (
            'schema_version',
            'event_profile',
            'sovereign_attribution',
            'attribution_use',
            'revision',
            'historical_acceptance_recorded',
            'attribution',
            'lifecycle',
            'current_support',
            'original_baseline_revision',
            'baseline_revision',
            'commitment_revision'
        )
    ) = 12 THEN 1 ELSE 0 END
);

CREATE VIEW v_ws_claimed_period_coverage AS
WITH basis AS (
    SELECT
        c.commitment_revision,
        c.lifecycle AS commitment_lifecycle,
        c.claimed_from_seconds,
        c.claimed_until_seconds,
        h.supported_periods,
        h.starts_at AS prefix_start_seconds,
        h.supported_through AS prefix_end_seconds,

        CASE
            WHEN c.claimed_from_seconds IS NOT NULL
             AND c.claimed_until_seconds IS NOT NULL
             AND c.claimed_from_seconds < c.claimed_until_seconds
            THEN 1 ELSE 0
        END AS finite_claim_established,

        EXISTS (
            SELECT 1
            FROM v_ws_resource_periods p
            WHERE p.commitment_revision = c.commitment_revision
              AND p.result = 'F'
              AND c.claimed_from_seconds IS NOT NULL
              AND c.claimed_until_seconds IS NOT NULL
              AND p.start_seconds < c.claimed_until_seconds
              AND p.end_seconds > c.claimed_from_seconds
        ) AS modeled_failure_overlaps_claim,

        EXISTS (
            SELECT 1
            FROM v_ws_resource_periods p
            WHERE p.commitment_revision = c.commitment_revision
              AND p.result = 'F'
              AND h.supported_periods > 0
              AND h.starts_at IS NOT NULL
              AND h.supported_through IS NOT NULL
              AND p.start_seconds < h.supported_through
              AND p.end_seconds > h.starts_at
        ) AS failure_inside_passing_prefix

    FROM ws_commitment c
    LEFT JOIN v_ws_resource_horizon h
        USING (commitment_revision)
),
checked_basis AS (
    SELECT
        basis.*,
        CASE
            WHEN failure_inside_passing_prefix THEN 'F'
            WHEN supported_periods IS NULL
              OR supported_periods < 0 THEN 'U'
            WHEN supported_periods > 0
             AND (
                 prefix_start_seconds IS NULL
                 OR prefix_end_seconds IS NULL
                 OR prefix_start_seconds >= prefix_end_seconds
             ) THEN 'U'
            ELSE 'P'
        END AS horizon_basis_state
    FROM basis
),
containment AS (
    SELECT
        checked_basis.*,

        CASE
            WHEN horizon_basis_state <> 'P'
              OR finite_claim_established = 0
              OR supported_periods IS NULL
            THEN 'unknown'
            WHEN supported_periods = 0
            THEN 'not_contained'
            WHEN prefix_start_seconds IS NULL
              OR prefix_end_seconds IS NULL
            THEN 'unknown'
            WHEN prefix_start_seconds <= claimed_from_seconds
             AND prefix_end_seconds >= claimed_until_seconds
            THEN 'contained'
            ELSE 'not_contained'
        END AS prefix_containment,

        CASE
            WHEN horizon_basis_state <> 'P'
              OR finite_claim_established = 0
              OR supported_periods IS NULL
            THEN NULL
            WHEN supported_periods = 0
            THEN 0
            WHEN prefix_start_seconds IS NULL
              OR prefix_end_seconds IS NULL
            THEN NULL
            ELSE MAX(
                0,
                MIN(claimed_until_seconds, prefix_end_seconds)
                - MAX(claimed_from_seconds, prefix_start_seconds)
            )
        END AS passing_prefix_overlap_seconds

    FROM checked_basis
)
SELECT
    containment.*,

    CASE
        WHEN finite_claim_established = 0 THEN 'U'
        WHEN modeled_failure_overlaps_claim THEN 'F'
        WHEN horizon_basis_state <> 'P' THEN 'U'
        WHEN commitment_lifecycle <> 'sealed' THEN 'U'
        WHEN prefix_containment = 'contained' THEN 'P'
        ELSE 'U'
    END AS claimed_period_resource_result,

    CASE
        WHEN finite_claim_established = 0
        THEN 'finite_claim_period_not_established'
        WHEN modeled_failure_overlaps_claim
        THEN 'modeled_failure_within_claimed_period'
        WHEN horizon_basis_state <> 'P'
        THEN 'horizon_basis_inconsistent_or_incomplete'
        WHEN commitment_lifecycle <> 'sealed'
        THEN 'commitment_snapshot_not_sealed'
        WHEN prefix_containment = 'contained'
        THEN 'claimed_period_inside_passing_prefix'
        ELSE 'full_claim_not_substantiated_by_passing_prefix'
    END AS reason,

    CASE
        WHEN finite_claim_established = 1
         AND passing_prefix_overlap_seconds IS NOT NULL
        THEN
            claimed_until_seconds
            - claimed_from_seconds
            - passing_prefix_overlap_seconds
    END AS seconds_not_substantiated_by_passing_prefix,

    'declared_resource_model_not_actual_service_verification'
        AS evidence_scope

FROM containment;

CREATE VIEW v_ws_evidence_continuity_projection AS
SELECT
    '1.0.0' AS projection_schema_version,
    s.schema_version AS source_schema_version,
    s.event_profile,
    s.sovereign_attribution,
    s.attribution_use,
    s.revision,
    s.historical_acceptance_recorded,
    s.attribution AS current_attribution,
    s.lifecycle,
    s.current_support,
    s.original_baseline_revision,
    s.baseline_revision,
    s.commitment_revision,

    c.claimed_from_seconds,
    c.claimed_until_seconds,

    COALESCE(c.prefix_containment, 'unknown')
        AS claimed_period_prefix_containment,

    COALESCE(c.claimed_period_resource_result, 'U')
        AS claimed_period_resource_result,

    COALESCE(c.reason, 'no_current_commitment_selected')
        AS claimed_period_reason,

    c.passing_prefix_overlap_seconds,
    c.seconds_not_substantiated_by_passing_prefix,
    c.modeled_failure_overlaps_claim,
    c.horizon_basis_state,

    'not_evaluated' AS claim_specific_publication_approval

FROM v_ws_release_summary s
LEFT JOIN v_ws_claimed_period_coverage c
    USING (commitment_revision);

DROP TABLE ws_projection_guard;
COMMIT;
