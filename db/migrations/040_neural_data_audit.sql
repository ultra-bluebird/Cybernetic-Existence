CREATE TABLE consent_event (
  event_id TEXT PRIMARY KEY,
  consent_id TEXT NOT NULL,
  subject_reference TEXT NOT NULL,
  event_kind TEXT NOT NULL CHECK (
    event_kind IN ('granted', 'amended', 'revoked', 'expired')
  ),
  revocation_epoch INTEGER NOT NULL CHECK (revocation_epoch >= 0),
  issued_at TEXT NOT NULL,
  evidence_reference TEXT NOT NULL,
  prior_event_id TEXT REFERENCES consent_event(event_id)
);

CREATE TABLE data_access_audit (
  audit_id TEXT PRIMARY KEY,
  consent_id TEXT NOT NULL,
  subject_reference TEXT NOT NULL,
  purpose TEXT NOT NULL,
  recipient TEXT NOT NULL,
  data_class TEXT NOT NULL CHECK (
    data_class IN (
      'local_only',
      'derived_local',
      'aggregate_release_candidate'
    )
  ),
  requested_epoch INTEGER NOT NULL CHECK (requested_epoch >= 0),
  decision TEXT NOT NULL CHECK (
    decision IN ('allowed_local', 'denied', 'quarantined')
  ),
  decision_reason TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  artifact_reference TEXT
);

CREATE TABLE derived_artifact (
  artifact_id TEXT PRIMARY KEY,
  consent_id TEXT NOT NULL,
  source_epoch INTEGER NOT NULL CHECK (source_epoch >= 0),
  purpose TEXT NOT NULL,
  data_class TEXT NOT NULL,
  retention_deadline TEXT NOT NULL,
  re_evaluation_status TEXT NOT NULL CHECK (
    re_evaluation_status IN (
      'current',
      'requires_review',
      'quarantined',
      'deleted'
    )
  ),
  created_at TEXT NOT NULL
);

CREATE VIEW current_consent_epoch AS
SELECT
  consent_id,
  MAX(revocation_epoch) AS effective_epoch
FROM consent_event
GROUP BY consent_id;

CREATE VIEW artifacts_requiring_re_evaluation AS
SELECT
  a.artifact_id,
  a.consent_id,
  a.source_epoch,
  c.effective_epoch,
  a.re_evaluation_status
FROM derived_artifact a
JOIN current_consent_epoch c
  ON c.consent_id = a.consent_id
WHERE a.source_epoch <> c.effective_epoch
  AND a.re_evaluation_status = 'current';
