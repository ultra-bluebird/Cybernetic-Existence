-- Migration 025: CyberRank Tier 3 eligibility audit surface (metadata only).
-- Stores procedural eligibility check results and consent-epoch references.
-- Never stores raw signals, biometrics, or personal payloads; local-first.

CREATE TABLE IF NOT EXISTS cyberrank_tier3_eligibility_records (
    eligibility_record_id TEXT PRIMARY KEY,
    subject_reference      TEXT NOT NULL,          -- opaque local reference only
    assessed_at            TEXT NOT NULL,          -- ISO-8601 date-time
    policy_version         TEXT NOT NULL,
    consent_epoch          INTEGER NOT NULL CHECK (consent_epoch >= 0),
    outcome                TEXT NOT NULL CHECK (outcome IN (
                               'eligible_pending_review',
                               'not_eligible',
                               'insufficient_evidence'
                           )),
    contains_sensitive_payload INTEGER NOT NULL DEFAULT 0 CHECK (contains_sensitive_payload = 0)
);

CREATE TABLE IF NOT EXISTS cyberrank_tier3_eligibility_checks (
    eligibility_record_id TEXT NOT NULL REFERENCES cyberrank_tier3_eligibility_records(eligibility_record_id),
    check_id              TEXT NOT NULL,
    status                TEXT NOT NULL CHECK (status IN ('pass', 'fail', 'not_applicable')),
    evidence_digest       TEXT,                    -- hex digest of local evidence metadata
    PRIMARY KEY (eligibility_record_id, check_id)
);

CREATE INDEX IF NOT EXISTS idx_tier3_assessed_at
    ON cyberrank_tier3_eligibility_records (assessed_at);
CREATE INDEX IF NOT EXISTS idx_tier3_consent_epoch
    ON cyberrank_tier3_eligibility_records (consent_epoch);
