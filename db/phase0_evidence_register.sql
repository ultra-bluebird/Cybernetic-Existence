-- Filename: db/phase0_evidence_register.sql
CREATE TABLE IF NOT EXISTS phase0_evidence_register (
    claim_id            TEXT PRIMARY KEY,
    claim_type          TEXT NOT NULL CHECK (claim_type IN (
                            'verified_fact', 'project_policy', 
                            'legal_proposal', 'engineering_hypothesis', 'assumption'
                        )),
    source_type         TEXT NOT NULL CHECK (source_type IN (
                            'statute', 'regulation', 'official_guidance', 
                            'standard', 'peer_reviewed', 'project_artifact'
                        )),
    jurisdiction_site   TEXT NOT NULL,
    version_pub_date    TEXT NOT NULL, -- ISO8601
    direct_support      TEXT NOT NULL, -- Exact statement supported
    applicability_limits TEXT NOT NULL, -- Climate, equipment, legal scope
    knowledge_factor    REAL NOT NULL CHECK (knowledge_factor >= 0.0 AND knowledge_factor <= 1.0),
    required_validation TEXT NOT NULL, -- Field test, legal review, etc.
    review_date         TEXT NOT NULL, -- ISO8601
    evidence_hex        TEXT NOT NULL  -- Hash of the source document
);
