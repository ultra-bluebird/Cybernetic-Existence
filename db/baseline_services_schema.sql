-- Filename: db/baseline_services_schema.sql
CREATE TABLE IF NOT EXISTS baseline_services (
    service_id          TEXT PRIMARY KEY,
    service_code        TEXT NOT NULL,
    location_zone       TEXT NOT NULL,
    availability_state  TEXT NOT NULL CHECK (availability_state IN ('AVAILABLE', 'DEGRADED', 'UNAVAILABLE')),
    fallback_code       TEXT,
    updated_at          TEXT NOT NULL,
    
    -- STRICT PROHIBITION: The following fields must NEVER exist in this table.
    -- If a migration attempts to add them, the schema lint will fail.
    CONSTRAINT no_identity_fields CHECK (
        service_id NOT LIKE '%person%' AND
        service_id NOT LIKE '%did%' AND
        service_id NOT LIKE '%bio%'
    )
);

-- View for routing: explicitly excludes any join to identity or contribution tables.
CREATE VIEW v_baseline_routing AS
SELECT service_code, location_zone, availability_state, fallback_code
FROM baseline_services
WHERE availability_state != 'UNAVAILABLE';
