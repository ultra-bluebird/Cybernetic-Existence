PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS canal_nodes (
    node_id TEXT PRIMARY KEY,
    node_pseudonym TEXT NOT NULL UNIQUE,
    active_consent INTEGER NOT NULL CHECK (active_consent IN (0, 1)),
    purpose_text TEXT NOT NULL CHECK (length(purpose_text) BETWEEN 10 AND 500),
    retention_until TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fog_observations (
    observation_id INTEGER PRIMARY KEY,
    node_id TEXT NOT NULL,
    observed_at TEXT NOT NULL,
    media_classification TEXT NOT NULL CHECK (
        media_classification IN (
            'freshwater',
            'brackish_water',
            'wastewater',
            'stormwater',
            'sediment',
            'unknown'
        )
    ),
    fog_state TEXT NOT NULL CHECK (fog_state IN ('FOG', 'CLEAR', 'UNKNOWN')),
    confidence REAL NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    measurement_completeness REAL NOT NULL CHECK (
        measurement_completeness >= 0.0 AND measurement_completeness <= 1.0
    ),
    flow_m3_s REAL NOT NULL CHECK (flow_m3_s >= 0.0 AND flow_m3_s <= 1000.0),
    water_temperature_c REAL NOT NULL CHECK (
        water_temperature_c >= -5.0 AND water_temperature_c <= 60.0
    ),
    measurement_quality REAL NOT NULL CHECK (
        measurement_quality >= 0.0 AND measurement_quality <= 1.0
    ),
    knowledge_k REAL NOT NULL CHECK (knowledge_k >= 0.0 AND knowledge_k <= 1.0),
    ecological_value_e REAL NOT NULL CHECK (
        ecological_value_e >= 0.0 AND ecological_value_e <= 1.0
    ),
    harm_risk_r REAL NOT NULL CHECK (harm_risk_r >= 0.0 AND harm_risk_r <= 1.0),
    provenance_text TEXT NOT NULL CHECK (length(provenance_text) BETWEEN 10 AND 1000),
    route TEXT NOT NULL CHECK (
        route IN ('KNOWN_MEDIA', 'FOG_REVIEW', 'QUARANTINED_INPUT', 'REJECTED_INPUT')
    ),
    route_code TEXT NOT NULL CHECK (length(route_code) BETWEEN 3 AND 80),
    explanation_text TEXT NOT NULL CHECK (length(explanation_text) BETWEEN 10 AND 1000),
    review_status TEXT NOT NULL CHECK (
        review_status IN ('REVIEW_REQUIRED', 'PENDING_REVIEW', 'REVIEWED', 'REJECTED')
    ),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (node_id) REFERENCES canal_nodes(node_id)
);

CREATE TABLE IF NOT EXISTS fog_audit_events (
    audit_event_id INTEGER PRIMARY KEY,
    observation_id INTEGER NOT NULL,
    event_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_type TEXT NOT NULL CHECK (
        event_type IN ('CREATED', 'ROUTED', 'CONSENT_REVOKED', 'REVIEW_OPENED', 'APPEAL_REQUESTED')
    ),
    actor_role TEXT NOT NULL CHECK (
        actor_role IN ('OPERATOR', 'REVIEWER', 'DATA_STEWARD', 'APPEALS_COORDINATOR')
    ),
    event_summary TEXT NOT NULL CHECK (length(event_summary) BETWEEN 10 AND 500),
    FOREIGN KEY (observation_id) REFERENCES fog_observations(observation_id)
);

CREATE INDEX IF NOT EXISTS idx_fog_observations_node_time
    ON fog_observations(node_id, observed_at DESC);

CREATE INDEX IF NOT EXISTS idx_fog_observations_review_status
    ON fog_observations(review_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_fog_observations_route
    ON fog_observations(route, observed_at DESC);

CREATE INDEX IF NOT EXISTS idx_fog_audit_observation_time
    ON fog_audit_events(observation_id, event_at DESC);

CREATE VIEW IF NOT EXISTS records_needing_human_review AS
SELECT
    o.observation_id,
    n.node_pseudonym,
    o.observed_at,
    o.media_classification,
    o.fog_state,
    o.route,
    o.route_code,
    o.knowledge_k,
    o.ecological_value_e,
    o.harm_risk_r,
    o.explanation_text,
    o.review_status
FROM fog_observations AS o
JOIN canal_nodes AS n ON n.node_id = o.node_id
WHERE o.review_status IN ('REVIEW_REQUIRED', 'PENDING_REVIEW')
   OR o.route IN ('FOG_REVIEW', 'QUARANTINED_INPUT', 'REJECTED_INPUT')
   OR o.harm_risk_r > 0.30
ORDER BY o.observed_at DESC, o.observation_id DESC;

SELECT
    observation_id,
    node_pseudonym,
    observed_at,
    route,
    route_code,
    explanation_text
FROM records_needing_human_review
ORDER BY observed_at DESC;
