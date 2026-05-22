-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Canonical task store schema for dictask
-- SQLite with WAL mode and JSON1 extension

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ============================================================================
-- Core tables
-- ============================================================================

-- Audio recordings ingested from the portable recorder
CREATE TABLE IF NOT EXISTS audio_files (
    id                TEXT PRIMARY KEY,        -- UUID v7
    file_path         TEXT NOT NULL,           -- path in local archive
    original_filename TEXT NOT NULL,           -- original name on recorder
    sha256_hash       TEXT NOT NULL UNIQUE,    -- content-addressable dedup
    file_size_bytes   INTEGER NOT NULL,
    duration_seconds  REAL,                    -- audio duration (if extractable)
    recorded_at       TEXT,                    -- recording timestamp (if available)
    ingested_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    cloud_backup_state TEXT NOT NULL DEFAULT 'pending'
        CHECK (cloud_backup_state IN ('pending', 'uploading', 'uploaded', 'quarantined', 'failed')),
    cloud_backup_url  TEXT,
    retry_count       INTEGER NOT NULL DEFAULT 0,
    metadata_json     TEXT                     -- extensible metadata (JSON1)
);

-- Transcripts produced by ASR engines
CREATE TABLE IF NOT EXISTS transcripts (
    id                TEXT PRIMARY KEY,        -- UUID v7
    audio_file_id     TEXT NOT NULL REFERENCES audio_files(id),
    engine_name       TEXT NOT NULL,           -- 'whisper' or 'vosk'
    engine_version    TEXT NOT NULL,           -- e.g. 'large-v3', '0.3.45'
    transcript_text   TEXT NOT NULL,           -- full transcript
    segments_json     TEXT,                    -- word-level timing (JSON1)
    language_detected TEXT,                    -- ISO 639-1 code
    transcribed_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    quality_score     REAL                     -- 0.0–1.0, engine-reported confidence
);

-- Candidate intents extracted by the Haskell parser
CREATE TABLE IF NOT EXISTS candidate_intents (
    id                TEXT PRIMARY KEY,        -- UUID v7
    transcript_id     TEXT NOT NULL REFERENCES transcripts(id),
    parser_version    TEXT NOT NULL,           -- dictask-parse version
    intent_type       TEXT NOT NULL
        CHECK (intent_type IN ('add_task', 'update_task', 'delete_task', 'set_deadline', 'set_priority', 'add_tag', 'note')),
    raw_text          TEXT NOT NULL,           -- original text segment
    confidence        REAL NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    parsed_data_json  TEXT NOT NULL,           -- structured extraction (JSON1)
    review_required   INTEGER NOT NULL DEFAULT 0,  -- boolean: 1 if needs human review
    parsed_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Canonical task store — single source of truth
CREATE TABLE IF NOT EXISTS tasks (
    id                TEXT PRIMARY KEY,        -- UUID v7
    title             TEXT NOT NULL,
    description       TEXT,
    status            TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'in_progress', 'done', 'review_needed', 'cancelled')),
    priority_score    REAL NOT NULL DEFAULT 0.0,  -- urgency*0.5 + importance*0.3 + deadline_proximity*0.2
    urgency           REAL NOT NULL DEFAULT 0.0,  -- 0.0–1.0
    importance        REAL NOT NULL DEFAULT 0.0,  -- 0.0–1.0
    due_date          TEXT,                    -- ISO 8601 date
    due_date_tentative INTEGER NOT NULL DEFAULT 0,  -- boolean: 1 if date is uncertain
    tags_json         TEXT DEFAULT '[]',       -- JSON array of tag strings
    project           TEXT,
    supersedes_task_id TEXT REFERENCES tasks(id),
    duplicate_of_task_id TEXT REFERENCES tasks(id),
    review_state      TEXT NOT NULL DEFAULT 'pending_review'
        CHECK (review_state IN ('pending_review', 'approved', 'rejected')),
    source_intent_id  TEXT REFERENCES candidate_intents(id),
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- ============================================================================
-- Audit trail
-- ============================================================================

-- Every change to the tasks table is logged here
CREATE TABLE IF NOT EXISTS audit_log (
    id                TEXT PRIMARY KEY,        -- UUID v7
    task_id           TEXT NOT NULL REFERENCES tasks(id),
    action            TEXT NOT NULL
        CHECK (action IN ('created', 'updated', 'deleted', 'merged', 'superseded', 'reviewed', 'auto_applied')),
    field_changed     TEXT,                    -- which field changed (NULL for create/delete)
    old_value         TEXT,
    new_value         TEXT,
    source            TEXT NOT NULL
        CHECK (source IN ('parser', 'dedup', 'review', 'manual', 'system')),
    confidence        REAL,                    -- confidence at time of action
    user_confirmed    INTEGER NOT NULL DEFAULT 0,  -- boolean: 1 if human confirmed
    audio_hash        TEXT,                    -- SHA-256 of original audio
    transcript_version TEXT,
    parser_version    TEXT,
    timestamp         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- ============================================================================
-- Review queue
-- ============================================================================

CREATE TABLE IF NOT EXISTS review_queue (
    id                TEXT PRIMARY KEY,        -- UUID v7
    intent_id         TEXT NOT NULL REFERENCES candidate_intents(id),
    task_id           TEXT REFERENCES tasks(id),   -- NULL if task not yet created
    review_reason     TEXT NOT NULL
        CHECK (review_reason IN ('low_confidence', 'semantic_duplicate', 'deletion', 'deadline_change', 'contradictory', 'tentative_date')),
    presented_at      TEXT,                    -- when shown to user
    resolved_at       TEXT,                    -- when user decided
    resolution        TEXT
        CHECK (resolution IN ('approved', 'rejected', 'modified', 'deferred') OR resolution IS NULL),
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- ============================================================================
-- Pipeline state tracking
-- ============================================================================

CREATE TABLE IF NOT EXISTS pipeline_runs (
    id                TEXT PRIMARY KEY,        -- UUID v7
    audio_file_id     TEXT NOT NULL REFERENCES audio_files(id),
    stage             TEXT NOT NULL
        CHECK (stage IN ('ingest', 'backup', 'transcribe', 'parse', 'normalise', 'dedup', 'review', 'apply', 'views', 'notify')),
    status            TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'completed', 'failed', 'skipped')),
    started_at        TEXT,
    completed_at      TEXT,
    error_message     TEXT,
    retry_count       INTEGER NOT NULL DEFAULT 0,
    idempotency_key   TEXT NOT NULL            -- ensures reprocessing produces same result
);

-- ============================================================================
-- Indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority_score DESC);
CREATE INDEX IF NOT EXISTS idx_tasks_review_state ON tasks(review_state);
CREATE INDEX IF NOT EXISTS idx_audit_log_task_id ON audit_log(task_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_review_queue_resolution ON review_queue(resolution);
CREATE INDEX IF NOT EXISTS idx_candidate_intents_confidence ON candidate_intents(confidence);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_stage ON pipeline_runs(audio_file_id, stage);
CREATE INDEX IF NOT EXISTS idx_audio_files_hash ON audio_files(sha256_hash);

-- ============================================================================
-- Triggers for automatic updated_at
-- ============================================================================

CREATE TRIGGER IF NOT EXISTS tasks_updated_at
    AFTER UPDATE ON tasks
    FOR EACH ROW
BEGIN
    UPDATE tasks SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
    WHERE id = NEW.id;
END;
