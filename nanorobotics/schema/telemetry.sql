-- ALN shard tag: JDBC_BATCH_OPERATIONS_v1

CREATE TABLE IF NOT EXISTS telemetry_sample (
    id                BIGSERIAL PRIMARY KEY,
    hostdid           TEXT        NOT NULL,
    bostromaddress    TEXT        NOT NULL,
    missionid         TEXT        NOT NULL,
    timestamputc      TIMESTAMPTZ NOT NULL,
    hrv_rmssd_ms      DOUBLE PRECISION NOT NULL,
    hrv_sdnn_ms       DOUBLE PRECISION NOT NULL,
    il6_pg_ml         DOUBLE PRECISION NOT NULL,
    temp_core_c       DOUBLE PRECISION NOT NULL,
    temp_local_c      DOUBLE PRECISION NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_telemetry_sample_host_bostrom_time
    ON telemetry_sample (hostdid, bostromaddress, timestamputc);
