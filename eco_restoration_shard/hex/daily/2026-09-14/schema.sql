PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA trusted_schema = OFF;

CREATE TABLE IF NOT EXISTS canal_node (
    canal_node_id TEXT PRIMARY KEY NOT NULL
        CHECK (length(trim(canal_node_id)) BETWEEN 1 AND 128),
    node_type TEXT NOT NULL
        CHECK (node_type IN ('canal', 'drain', 'wetland_inlet', 'retention_basin')),
    maximum_energyreq_j REAL NOT NULL
        CHECK (maximum_energyreq_j > 0.0 AND maximum_energyreq_j <= 1000000000.0),
    maximum_abs_delta_vt REAL NOT NULL
        CHECK (maximum_abs_delta_vt > 0.0 AND maximum_abs_delta_vt <= 1000.0),
    minimum_battery_soc REAL NOT NULL
        CHECK (minimum_battery_soc >= 0.0 AND minimum_battery_soc <= 1.0),
    minimum_renewable_fraction REAL NOT NULL
        CHECK (minimum_renewable_fraction >= 0.0 AND minimum_renewable_fraction <= 1.0),
    maximum_harm_risk REAL NOT NULL
        CHECK (maximum_harm_risk >= 0.0 AND maximum_harm_risk <= 1.0),
    active INTEGER NOT NULL DEFAULT 1
        CHECK (active IN (0, 1))
);

CREATE TABLE IF NOT EXISTS ker_assessment (
    ker_assessment_id INTEGER PRIMARY KEY,
    knowledge_factor REAL NOT NULL
        CHECK (knowledge_factor >= 0.0 AND knowledge_factor <= 1.0),
    eco_impact_value REAL NOT NULL
        CHECK (eco_impact_value >= 0.0 AND eco_impact_value <= 1.0),
    harm_risk REAL NOT NULL
        CHECK (harm_risk >= 0.0 AND harm_risk <= 1.0),
    assessed_at_utc TEXT NOT NULL
        CHECK (
            assessed_at_utc GLOB '????-??-??T??:??:??Z'
            AND length(assessed_at_utc) = 20
        ),
    review_state TEXT NOT NULL
        CHECK (review_state IN ('provisional', 'reviewed', 'rejected'))
);

CREATE TABLE IF NOT EXISTS fog_media (
    media_class TEXT PRIMARY KEY NOT NULL
        CHECK (
            media_class IN (
                'known_safe',
                'unmodeled_media',
                'pfas_suspected',
                'hazardous_material',
                'unknown'
            )
        ),
    requires_manual_review INTEGER NOT NULL
        CHECK (requires_manual_review IN (0, 1)),
    physical_dispatch_prohibited INTEGER NOT NULL
        CHECK (physical_dispatch_prohibited IN (0, 1)),
    CHECK (
        NOT (
            media_class = 'hazardous_material'
            AND physical_dispatch_prohibited != 1
        )
    )
);

INSERT OR IGNORE INTO fog_media (
    media_class,
    requires_manual_review,
    physical_dispatch_prohibited
) VALUES
    ('known_safe', 0, 0),
    ('unmodeled_media', 1, 0),
    ('pfas_suspected', 1, 0),
    ('hazardous_material', 1, 1),
    ('unknown', 1, 0);

CREATE TABLE IF NOT EXISTS workload_telemetry (
    workload_id TEXT PRIMARY KEY NOT NULL
        CHECK (length(trim(workload_id)) BETWEEN 1 AND 128),
    canal_node_id TEXT NOT NULL,
    task_type TEXT NOT NULL
        CHECK (
            task_type IN (
                'debris_skim',
                'sediment_dredge',
                'biofilm_scrub',
                'aerator_drive'
            )
        ),
    mass_kg REAL NOT NULL
        CHECK (mass_kg > 0.0 AND mass_kg <= 100000.0),
    distance_m REAL NOT NULL
        CHECK (distance_m >= 0.0 AND distance_m <= 100000.0),
    duty_seconds REAL NOT NULL
        CHECK (duty_seconds > 0.0 AND duty_seconds <= 86400.0),
    rated_power_w REAL NOT NULL
        CHECK (rated_power_w > 0.0 AND rated_power_w <= 10000000.0),
    motor_efficiency REAL NOT NULL
        CHECK (motor_efficiency > 0.0 AND motor_efficiency <= 1.0),
    baseline_voltage_v REAL NOT NULL
        CHECK (baseline_voltage_v > 0.0 AND baseline_voltage_v <= 5000.0),
    internal_resistance_ohm REAL NOT NULL
        CHECK (internal_resistance_ohm >= 0.0 AND internal_resistance_ohm <= 100.0),
    battery_soc REAL NOT NULL
        CHECK (battery_soc >= 0.0 AND battery_soc <= 1.0),
    renewable_fraction REAL NOT NULL
        CHECK (renewable_fraction >= 0.0 AND renewable_fraction <= 1.0),
    media_class TEXT NOT NULL,
    energyreq_j REAL NOT NULL
        CHECK (energyreq_j > 0.0 AND energyreq_j <= 1000000000.0),
    delta_vt REAL NOT NULL
        CHECK (delta_vt >= 0.0 AND delta_vt <= 1000.0),
    ker_assessment_id INTEGER NOT NULL,
    operator_approved INTEGER NOT NULL DEFAULT 0
        CHECK (operator_approved IN (0, 1)),
    dispatch_state TEXT NOT NULL DEFAULT 'held'
        CHECK (dispatch_state IN ('held', 'review_required', 'approved', 'rejected')),
    recorded_at_utc TEXT NOT NULL
        CHECK (
            recorded_at_utc GLOB '????-??-??T??:??:??Z'
            AND length(recorded_at_utc) = 20
        ),
    FOREIGN KEY (canal_node_id)
        REFERENCES canal_node(canal_node_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    FOREIGN KEY (media_class)
        REFERENCES fog_media(media_class)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    FOREIGN KEY (ker_assessment_id)
        REFERENCES ker_assessment(ker_assessment_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_workload_telemetry_node_time
    ON workload_telemetry(canal_node_id, recorded_at_utc DESC);

CREATE INDEX IF NOT EXISTS idx_workload_telemetry_dispatch_state
    ON workload_telemetry(dispatch_state, recorded_at_utc DESC);

CREATE INDEX IF NOT EXISTS idx_workload_telemetry_media
    ON workload_telemetry(media_class, recorded_at_utc DESC);

CREATE TRIGGER IF NOT EXISTS enforce_workload_node_limits_before_insert
BEFORE INSERT ON workload_telemetry
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN (
            SELECT active
            FROM canal_node
            WHERE canal_node_id = NEW.canal_node_id
        ) != 1
        THEN RAISE(ABORT, 'inactive or unknown Canal node')
    END;

    SELECT CASE
        WHEN NEW.energyreq_j > (
            SELECT maximum_energyreq_j
            FROM canal_node
            WHERE canal_node_id = NEW.canal_node_id
        )
        THEN RAISE(ABORT, 'energyreqJ exceeds Canal node limit')
    END;

    SELECT CASE
        WHEN NEW.delta_vt > (
            SELECT maximum_abs_delta_vt
            FROM canal_node
            WHERE canal_node_id = NEW.canal_node_id
        )
        THEN RAISE(ABORT, 'deltaVt exceeds Canal node limit')
    END;

    SELECT CASE
        WHEN NEW.battery_soc < (
            SELECT minimum_battery_soc
            FROM canal_node
            WHERE canal_node_id = NEW.canal_node_id
        )
        THEN RAISE(ABORT, 'battery state of charge below Canal node limit')
    END;

    SELECT CASE
        WHEN NEW.renewable_fraction < (
            SELECT minimum_renewable_fraction
            FROM canal_node
            WHERE canal_node_id = NEW.canal_node_id
        )
        THEN RAISE(ABORT, 'renewable fraction below Canal node limit')
    END;

    SELECT CASE
        WHEN (
            SELECT harm_risk
            FROM ker_assessment
            WHERE ker_assessment_id = NEW.ker_assessment_id
        ) > (
            SELECT maximum_harm_risk
            FROM canal_node
            WHERE canal_node_id = NEW.canal_node_id
        )
        THEN RAISE(ABORT, 'KER harm risk exceeds Canal node limit')
    END;

    SELECT CASE
        WHEN NEW.operator_approved = 1
         AND NEW.dispatch_state = 'approved'
         AND (
            NEW.media_class != 'known_safe'
            OR (
                SELECT knowledge_factor
                FROM ker_assessment
                WHERE ker_assessment_id = NEW.ker_assessment_id
            ) < 0.75
            OR (
                SELECT eco_impact_value
                FROM ker_assessment
                WHERE ker_assessment_id = NEW.ker_assessment_id
            ) < 0.55
            OR (
                SELECT harm_risk
                FROM ker_assessment
                WHERE ker_assessment_id = NEW.ker_assessment_id
            ) > 0.30
         )
        THEN RAISE(ABORT, 'FOG or KER policy requires manual review')
    END;
END;

CREATE TRIGGER IF NOT EXISTS enforce_workload_node_limits_before_update
BEFORE UPDATE OF
    canal_node_id,
    energyreq_j,
    delta_vt,
    battery_soc,
    renewable_fraction,
    media_class,
    ker_assessment_id,
    operator_approved,
    dispatch_state
ON workload_telemetry
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NEW.energyreq_j > (
            SELECT maximum_energyreq_j
            FROM canal_node
            WHERE canal_node_id = NEW.canal_node_id
        )
        THEN RAISE(ABORT, 'energyreqJ exceeds Canal node limit')
    END;

    SELECT CASE
        WHEN NEW.delta_vt > (
            SELECT maximum_abs_delta_vt
            FROM canal_node
            WHERE canal_node_id = NEW.canal_node_id
        )
        THEN RAISE(ABORT, 'deltaVt exceeds Canal node limit')
    END;

    SELECT CASE
        WHEN NEW.operator_approved = 1
         AND NEW.dispatch_state = 'approved'
         AND NEW.media_class != 'known_safe'
        THEN RAISE(ABORT, 'unmodeled or restricted FOG media cannot be approved automatically')
    END;
END;
