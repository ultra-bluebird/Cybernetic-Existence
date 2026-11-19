-- ALN shard tag: SQL_INDEXES_v1

-- Composite index to support per-host, per-address, per-mission scans in time order.
CREATE INDEX IF NOT EXISTS idx_nanoswarmmissionlog_host_bostrom_mission_time
    ON nanoswarmmissionlog (
        hostdid,
        bostromaddress,
        missionid,
        eventtimeutc
    );

-- Daily summary queries use hostdid, bostromaddress, date(eventtimeutc).
CREATE INDEX IF NOT EXISTS idx_nanoswarmmissionlog_host_bostrom_date
    ON nanoswarmmissionlog (
        hostdid,
        bostromaddress,
        date(eventtimeutc)
    );
