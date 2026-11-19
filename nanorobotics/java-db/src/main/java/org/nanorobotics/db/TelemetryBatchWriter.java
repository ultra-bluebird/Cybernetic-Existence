package org.nanorobotics.db;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.time.Instant;
import java.util.List;

public class TelemetryBatchWriter {

    private static final String INSERT_SQL = """
        INSERT INTO telemetry_sample (
            hostdid,
            bostromaddress,
            missionid,
            timestamputc,
            hrv_rmssd_ms,
            hrv_sdnn_ms,
            il6_pg_ml,
            temp_core_c,
            temp_local_c
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """;

    public static final String HOST_DID = "didalnorganic-host";
    public static final String PRIMARY_BOSTROM_ADDRESS = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

    public static final class TelemetryRow {
        public final String hostDid;
        public final String bostromAddress;
        public final String missionId;
        public final Instant timestampUtc;
        public final double hrvRmssdMs;
        public final double hrvSdnnMs;
        public final double il6PgMl;
        public final double tempCoreC;
        public final double tempLocalC;

        public TelemetryRow(
                String hostDid,
                String bostromAddress,
                String missionId,
                Instant timestampUtc,
                double hrvRmssdMs,
                double hrvSdnnMs,
                double il6PgMl,
                double tempCoreC,
                double tempLocalC
        ) {
            this.hostDid = hostDid;
            this.bostromAddress = bostromAddress;
            this.missionId = missionId;
            this.timestampUtc = timestampUtc;
            this.hrvRmssdMs = hrvRmssdMs;
            this.hrvSdnnMs = hrvSdnnMs;
            this.il6PgMl = il6PgMl;
            this.tempCoreC = tempCoreC;
            this.tempLocalC = tempLocalC;
        }
    }

    public void insertBatch(Connection connection, List<TelemetryRow> rows, int batchSize) throws SQLException {
        try (PreparedStatement ps = connection.prepareStatement(INSERT_SQL)) {
            int count = 0;
            for (TelemetryRow row : rows) {
                if (!HOST_DID.equals(row.hostDid) ||
                        !PRIMARY_BOSTROM_ADDRESS.equals(row.bostromAddress)) {
                    throw new IllegalArgumentException("Sovereign binding mismatch for telemetry row");
                }
                ps.setString(1, row.hostDid);
                ps.setString(2, row.bostromAddress);
                ps.setString(3, row.missionId);
                ps.setObject(4, row.timestampUtc);
                ps.setDouble(5, row.hrvRmssdMs);
                ps.setDouble(6, row.hrvSdnnMs);
                ps.setDouble(7, row.il6PgMl);
                ps.setDouble(8, row.tempCoreC);
                ps.setDouble(9, row.tempLocalC);
                ps.addBatch();
                count++;
                if (count % batchSize == 0) {
                    ps.executeBatch();
                }
            }
            if (count % batchSize != 0) {
                ps.executeBatch();
            }
        }
    }
}
