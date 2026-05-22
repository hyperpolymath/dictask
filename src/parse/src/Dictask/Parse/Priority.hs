-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- | Priority scoring for task intents.
--
-- Formula: priority_score = urgency * 0.5 + importance * 0.3 + deadline_proximity * 0.2
--
-- Urgency is derived from keywords like "urgent", "asap", "critical".
-- Importance is derived from keywords like "important", "key", "essential".
-- Deadline proximity is computed from how close the due date is.
module Dictask.Parse.Priority
  ( -- * Keyword detection
    detectUrgency
  , detectImportance
    -- * Deadline proximity
  , deadlineProximity
    -- * Full scoring
  , scorePriority
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, diffDays)

import Dictask.Parse.Types (PriorityScore, computePriority)

-- | Detect urgency from keywords in the text.
-- Returns a value in [0.0, 1.0].
detectUrgency :: Text -> Double
detectUrgency text =
  let lower = T.toLower text
      urgencyKeywords =
        [ ("asap", 0.9)
        , ("urgent", 0.9)
        , ("critical", 1.0)
        , ("emergency", 1.0)
        , ("right away", 0.85)
        , ("immediately", 0.95)
        , ("as soon as possible", 0.9)
        , ("rush", 0.8)
        , ("time sensitive", 0.8)
        , ("today", 0.7)
        ]
      matches = [ score | (kw, score) <- urgencyKeywords, kw `T.isInfixOf` lower ]
  in case matches of
    []    -> 0.0
    xs    -> maximum xs

-- | Detect importance from keywords in the text.
-- Returns a value in [0.0, 1.0].
detectImportance :: Text -> Double
detectImportance text =
  let lower = T.toLower text
      importanceKeywords =
        [ ("important", 0.8)
        , ("essential", 0.9)
        , ("key", 0.7)
        , ("crucial", 0.9)
        , ("vital", 0.85)
        , ("must", 0.75)
        , ("need to", 0.6)
        , ("have to", 0.6)
        , ("required", 0.7)
        , ("high priority", 0.85)
        ]
      matches = [ score | (kw, score) <- importanceKeywords, kw `T.isInfixOf` lower ]
  in case matches of
    []    -> 0.0
    xs    -> maximum xs

-- | Compute deadline proximity score from days until due date.
-- Returns a value in [0.0, 1.0].
-- Closer deadlines get higher scores.
deadlineProximity :: Day -> Maybe Day -> Double
deadlineProximity _today Nothing = 0.0
deadlineProximity today (Just dueDate) =
  let daysLeft = diffDays dueDate today
  in if daysLeft <= 0 then 1.0         -- Overdue
     else if daysLeft <= 1 then 0.95   -- Due today/tomorrow
     else if daysLeft <= 3 then 0.8    -- Due within 3 days
     else if daysLeft <= 7 then 0.6    -- Due within a week
     else if daysLeft <= 14 then 0.4   -- Due within 2 weeks
     else if daysLeft <= 30 then 0.2   -- Due within a month
     else 0.1                          -- Due later

-- | Score priority for a text segment with optional deadline.
-- Combines urgency, importance, and deadline proximity.
scorePriority :: Day -> Text -> Maybe Day -> PriorityScore
scorePriority today text maybeDueDate =
  let urgency    = detectUrgency text
      importance = detectImportance text
      proximity  = deadlineProximity today maybeDueDate
  in computePriority urgency importance proximity
