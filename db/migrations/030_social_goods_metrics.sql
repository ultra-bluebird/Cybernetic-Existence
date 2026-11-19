-- Migration 030: Social-goods metric claim ledger (aggregate metadata only).
-- Claims reference aggregate evidence by digest; no row-level observations,
-- no location traces, and no personal data are stored here. Local-first.

CREATE TABLE IF NOT EXISTS social_goods_metric_claims (
    claim_id           TEXT PRIMARY KEY,
    metric_id          TEXT NOT NULL,
    asserted_at        TEXT NOT NULL,              -- ISO-8601 date-time
    window_start       TEXT NOT NULL,
    window_end         TEXT NOT NULL,
    value              REAL NOT NULL,
    unit               TEXT NOT NULL,
    aggregation_method TEXT,
    privacy_accounting_ref TEXT,                   -- DP budget record reference
    review_status      TEXT NOT NULL CHECK (review_status IN (
                           'pending_external_review',
                           'accepted',
                           'rejected'
                       )),
    contains_sensitive_payload INTEGER NOT NULL DEFAULT 0 CHECK (contains_sensitive_payload = 0)
);

CREATE TABLE IF NOT EXISTS social_goods_claim_provenance (
    claim_id        TEXT NOT NULL REFERENCES social_goods_metric_claims(claim_id),
    provenance_ref  TEXT NOT NULL,                 -- opaque digest / ledger ref
    PRIMARY KEY (claim_id, provenance_ref)
);

CREATE INDEX IF NOT EXISTS idx_sg_claims_metric
    ON social_goods_metric_claims (metric_id, window_start);
