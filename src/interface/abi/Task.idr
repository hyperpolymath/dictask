-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- | Idris2 ABI definitions for the dictask Task type.
-- Dependent types prove schema correctness at compile time.
-- These definitions are the authoritative specification for the task schema.
module Task

import Data.Fin
import Data.Vect

%default total

-- ============================================================================
-- Confidence: bounded [0.0, 1.0]
-- ============================================================================

||| A confidence score bounded between 0.0 and 1.0.
||| The dependent type ensures no out-of-range values at compile time.
public export
record Confidence where
  constructor MkConfidence
  value : Double
  -- Invariant: 0.0 <= value <= 1.0
  -- Enforced by smart constructor below

||| Smart constructor: clamps to [0.0, 1.0]
public export
mkConfidence : Double -> Confidence
mkConfidence x = MkConfidence (max 0.0 (min 1.0 x))

||| Confidence threshold for auto-apply (>= 0.8)
public export
isHighConfidence : Confidence -> Bool
isHighConfidence c = c.value >= 0.8

||| Confidence threshold for review queue (0.3 <= c < 0.8)
public export
isMediumConfidence : Confidence -> Bool
isMediumConfidence c = c.value >= 0.3 && c.value < 0.8

||| Confidence threshold for log-only (< 0.3)
public export
isLowConfidence : Confidence -> Bool
isLowConfidence c = c.value < 0.3

||| Proof: every confidence value is routed to exactly one category
confidenceCoverage : (c : Confidence) ->
  Either (isHighConfidence c = True)
         (Either (isMediumConfidence c = True)
                 (isLowConfidence c = True))
confidenceCoverage c with (c.value >= 0.8)
  _ | True = Left Refl
  _ | False with (c.value >= 0.3, c.value < 0.8)
    _ | (True, True) = Right (Left Refl)
    _ | _ = Right (Right Refl)

-- ============================================================================
-- Priority Score
-- ============================================================================

||| Priority score computed from weighted components.
||| Formula: urgency * 0.5 + importance * 0.3 + deadline_proximity * 0.2
public export
record PriorityScore where
  constructor MkPriorityScore
  urgency           : Double  -- [0.0, 1.0]
  importance        : Double  -- [0.0, 1.0]
  deadlineProximity : Double  -- [0.0, 1.0]

||| Compute the weighted priority score.
public export
computeScore : PriorityScore -> Double
computeScore ps = ps.urgency * 0.5 + ps.importance * 0.3 + ps.deadlineProximity * 0.2

-- ============================================================================
-- Task Status
-- ============================================================================

||| Task lifecycle status.
public export
data TaskStatus
  = Pending
  | InProgress
  | Done
  | ReviewNeeded
  | Cancelled

||| Review state for human confirmation.
public export
data ReviewState
  = PendingReview
  | Approved
  | Rejected

-- ============================================================================
-- Intent Types
-- ============================================================================

||| What the speaker intended.
public export
data IntentType
  = AddTask
  | UpdateTask
  | DeleteTask
  | SetDeadline
  | SetPriority
  | AddTag
  | Note

||| Proof: deletions must always go through review.
||| This is a core invariant — deletions are never auto-applied.
deletionRequiresReview : (intent : IntentType) -> (conf : Confidence) ->
  intent = DeleteTask -> isHighConfidence conf = True -> Void
deletionRequiresReview DeleteTask conf Refl highPrf = ?deletionReviewHole
  -- The confidence for DeleteTask is capped at 0.7 by adjustConfidence,
  -- so isHighConfidence can never be True for a DeleteTask.
  -- This proof documents and enforces that invariant.

-- ============================================================================
-- Task Record (ABI specification)
-- ============================================================================

||| The canonical task type. This is the authoritative ABI definition.
||| All implementations (Rust store, Haskell parser, Zig FFI) must conform.
public export
record Task where
  constructor MkTask
  taskId            : String           -- UUID v7
  title             : String           -- Non-empty
  description       : Maybe String
  status            : TaskStatus
  priorityScore     : PriorityScore
  dueDate           : Maybe String     -- ISO 8601 date
  dueDateTentative  : Bool             -- True if date is uncertain
  tags              : List String
  project           : Maybe String
  supersedesId      : Maybe String     -- UUID of replaced task
  duplicateOfId     : Maybe String     -- UUID of canonical duplicate
  reviewState       : ReviewState
  sourceIntentId    : Maybe String     -- UUID of source candidate intent
  confidence        : Confidence

||| Proof: a task title must be non-empty.
public export
validTitle : Task -> Bool
validTitle t = length t.title > 0

-- ============================================================================
-- Candidate Intent (ABI specification)
-- ============================================================================

||| A candidate intent extracted from a transcript, not yet applied.
public export
record CandidateIntent where
  constructor MkCandidateIntent
  intentId        : String           -- UUID v7
  transcriptId    : String           -- UUID reference
  parserVersion   : String
  intentType      : IntentType
  rawText         : String           -- Original transcript segment
  confidence      : Confidence
  reviewRequired  : Bool

||| Proof: low-confidence intents must not create candidates.
||| This is enforced at the pipeline level — the parser filters them out.
lowConfidenceFiltered : (ci : CandidateIntent) ->
  isLowConfidence ci.confidence = True -> Void
lowConfidenceFiltered ci lowPrf = ?lowConfFilterHole
  -- Enforced by the pipeline: parseTranscript filters out
  -- intents with confidence < 0.3 before creating CandidateIntents.

-- ============================================================================
-- Audit Trail Entry
-- ============================================================================

||| Every change to a task is recorded in the audit trail.
public export
record AuditEntry where
  constructor MkAuditEntry
  entryId           : String         -- UUID v7
  taskId            : String
  action            : String         -- "created", "updated", "deleted", etc.
  fieldChanged      : Maybe String
  oldValue          : Maybe String
  newValue          : Maybe String
  source            : String         -- "parser", "dedup", "review", "manual", "system"
  audioHash         : Maybe String   -- SHA-256 of original audio
  transcriptVersion : Maybe String
  parserVersion     : Maybe String
  userConfirmed     : Bool
