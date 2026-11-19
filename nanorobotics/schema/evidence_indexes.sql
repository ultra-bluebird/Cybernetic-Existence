-- ALN shard tag: SQL_INDEXES_v1

-- Fast lookup of bundles for a given mission.
CREATE INDEX IF NOT EXISTS idx_evidence_bundle_mission_time
    ON evidence_bundle (
        missionid,
        created_at
    );

-- Host-bounded audit queries.
CREATE INDEX IF NOT EXISTS idx_evidence_bundle_host_bostrom_time
    ON evidence_bundle (
        hostdid,
        bostromaddress,
        created_at
    );
