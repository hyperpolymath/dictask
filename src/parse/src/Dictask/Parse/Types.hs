-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- | Core types for the dictask NLP parser.
-- These mirror the Idris2 ABI definitions in src/interface/abi/
-- and the SQLite schema in schemas/tasks.sql.
module Dictask.Parse.Types
  ( -- * Task types
    Task (..)
  , TaskStatus (..)
  , ReviewState (..)
    -- * Intent types
  , CandidateIntent (..)
  , IntentType (..)
  , ParsedData (..)
    -- * Confidence
  , Confidence (..)
  , mkConfidence
  , isHighConfidence
  , isMediumConfidence
  , isLowConfidence
    -- * Priority
  , PriorityScore (..)
  , mkPriorityScore
  , computePriority
  ) where

import Data.Text (Text)
import Data.Time (UTCTime, Day)
import Data.UUID (UUID)

-- | Confidence score in [0.0, 1.0] range.
-- Enforced by smart constructor 'mkConfidence'.
newtype Confidence = Confidence { unConfidence :: Double }
  deriving (Eq, Ord, Show)

-- | Smart constructor: clamps to [0.0, 1.0]
mkConfidence :: Double -> Confidence
mkConfidence x = Confidence (max 0.0 (min 1.0 x))

-- | >= 0.8: auto-apply
isHighConfidence :: Confidence -> Bool
isHighConfidence (Confidence c) = c >= 0.8

-- | 0.3–0.8: review queue
isMediumConfidence :: Confidence -> Bool
isMediumConfidence (Confidence c) = c >= 0.3 && c < 0.8

-- | < 0.3: log only, do not create candidate
isLowConfidence :: Confidence -> Bool
isLowConfidence (Confidence c) = c < 0.3

-- | Priority score computed from urgency, importance, and deadline proximity.
-- Formula: urgency * 0.5 + importance * 0.3 + deadline_proximity * 0.2
newtype PriorityScore = PriorityScore { unPriorityScore :: Double }
  deriving (Eq, Ord, Show)

-- | Smart constructor: clamps to [0.0, 1.0]
mkPriorityScore :: Double -> PriorityScore
mkPriorityScore x = PriorityScore (max 0.0 (min 1.0 x))

-- | Compute priority from three weighted components.
computePriority :: Double -> Double -> Double -> PriorityScore
computePriority urgency importance deadlineProximity =
  mkPriorityScore (urgency * 0.5 + importance * 0.3 + deadlineProximity * 0.2)

-- | What the speaker intended.
data IntentType
  = AddTask
  | UpdateTask
  | DeleteTask
  | SetDeadline
  | SetPriority
  | AddTag
  | Note
  deriving (Eq, Show, Enum, Bounded)

-- | Task lifecycle status.
data TaskStatus
  = Pending
  | InProgress
  | Done
  | ReviewNeeded
  | Cancelled
  deriving (Eq, Show, Enum, Bounded)

-- | Human review state.
data ReviewState
  = PendingReview
  | Approved
  | Rejected
  deriving (Eq, Show, Enum, Bounded)

-- | Structured data extracted from the transcript segment.
data ParsedData = ParsedData
  { pdTitle            :: Text
  , pdDescription      :: Maybe Text
  , pdDeadline         :: Maybe Day
  , pdDeadlineTentative :: Bool          -- ^ True if date is vague ("after Easter")
  , pdPriorityKeywords :: [Text]         -- ^ e.g. ["urgent", "asap"]
  , pdTags             :: [Text]
  , pdProject          :: Maybe Text
  , pdTargetTaskId     :: Maybe UUID     -- ^ For update/delete: which task
  } deriving (Eq, Show)

-- | A candidate intent extracted from a transcript.
-- Not yet applied to the canonical store — may need review.
data CandidateIntent = CandidateIntent
  { ciId             :: UUID
  , ciTranscriptId   :: UUID
  , ciParserVersion  :: Text
  , ciIntentType     :: IntentType
  , ciRawText        :: Text             -- ^ Original transcript segment
  , ciConfidence     :: Confidence
  , ciParsedData     :: ParsedData
  , ciReviewRequired :: Bool
  , ciAmbiguityNotes :: Maybe Text       -- ^ Why confidence is low
  , ciParsedAt       :: UTCTime
  } deriving (Eq, Show)

-- | A task in the canonical store.
data Task = Task
  { taskId             :: UUID
  , taskTitle          :: Text
  , taskDescription    :: Maybe Text
  , taskStatus         :: TaskStatus
  , taskPriorityScore  :: PriorityScore
  , taskUrgency        :: Double
  , taskImportance     :: Double
  , taskDueDate        :: Maybe Day
  , taskDueDateTentative :: Bool
  , taskTags           :: [Text]
  , taskProject        :: Maybe Text
  , taskSupersedesId   :: Maybe UUID
  , taskDuplicateOfId  :: Maybe UUID
  , taskReviewState    :: ReviewState
  , taskSourceIntentId :: Maybe UUID
  , taskCreatedAt      :: UTCTime
  , taskUpdatedAt      :: UTCTime
  } deriving (Eq, Show)
