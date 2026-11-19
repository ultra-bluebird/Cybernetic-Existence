package org.nanorobotics.db;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.time.Instant;
import java.util.List;

public class NanoswarmMissionLogBatchWriter {

    private static final String INSERT_SQL = """
        INSERT INTO nanoswarmmissionlog (
            hostdid,
            bostromaddress,
            missionid,
            eventtimeutc,
            roh,
            lifeforcechi,
            densityrisk,
            thermodutyrisk,
            neurorightsmargin,
            ecoimpactscore,
            safetyverdict,
            evidencebundleid
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """;

    public static final String HOST_DID = "didalnorganic-host";
    public static final String PRIMARY_BOSTROM_ADDRESS = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

    public static final class MissionLogRow {
        public final String hostDid;
        public final String bostromAddress;
        public final String missionId;
        public final Instant eventTimeUtc;
        public final double roh;
        public final double lifeforceChi;
        public final double densityRisk;
        public final double thermoDutyRisk;
        public final double neurorightsMargin;
        public final double ecoImpactScore;
        public final String safetyVerdict;
        public final String evidenceBundleId;

        public MissionLogRow(
                String hostDid,
                String bostromAddress,
                String missionId,
                Instant eventTimeUtc,
                double roh,
                double lifeforceChi,
                double densityRisk,
                double thermoDutyRisk,
                double neurorightsMargin,
                double ecoImpactScore,
                String safetyVerdict,
                String evidenceBundleId
        ) {
            this.hostDid = hostDid;
            this.bostromAddress = bostromAddress;
            this.missionId = missionId;
            this.eventTimeUtc = eventTimeUtc;
            this.roh = roh;
            this.lifeforceChi = lifeforceChi;
            this.densityRisk = densityRisk;
            this.thermoDutyRisk = thermoDutyRisk;
            this.neurorightsMargin = neurorightsMargin;
            this.ecoImpactScore = ecoImpactScore;
            this.safetyVerdict = safetyVerdict;
            this.evidenceBundleId = evidenceBundleId;
        }
    }

    public void insertBatch(Connection connection, List<MissionLogRow> rows, int batchSize) throws SQLException {
        try (PreparedStatement ps = connection.prepareStatement(INSERT_SQL)) {
            int count = 0;
            for (MissionLogRow row : rows) {
                if (!HOST_DID.equals(row.hostDid) ||
                        !PRIMARY_BOSTROM_ADDRESS.equals(row.bostromAddress)) {
                    throw new IllegalArgumentException("Sovereign binding mismatch for mission log row");
                }
                ps.setString(1, row.hostDid);
                ps.setString(2, row.bostromAddress);
                ps.setString(3, row.missionId);
                ps.setObject(4, row.eventTimeUtc);
                ps.setDouble(5, row.roh);
                ps.setDouble(6, row.lifeforceChi);
                ps.setDouble(7, row.densityRisk);
                ps.setDouble(8, row.thermoDutyRisk);
                ps.setDouble(9, row.neurorightsMargin);
                ps.setDouble(10, row.ecoImpactScore);
                ps.setString(11, row.safetyVerdict);
                ps.setString(12, row.evidenceBundleId);
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
