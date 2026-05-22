-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- | Deduplication engine for candidate intents and existing tasks.
--
-- Deduplication policy:
--   Exact match:      Same title + same project → auto-merge
--   Semantic similar: Similar title, different wording → flag for review
--   Recurring:        Same pattern across recordings → link with supersedes
module Dictask.Parse.Dedup
  ( -- * Deduplication
    DedupResult (..)
  , DedupAction (..)
  , checkDuplicate
  , normaliseTitle
  , titleSimilarity
  ) where

import Data.Char (isAlphaNum, isSpace, toLower)
import Data.Text (Text)
import qualified Data.Text as T

import Dictask.Parse.Types (Confidence, mkConfidence)

-- | What action to take after dedup check.
data DedupAction
  = NoDuplicate          -- ^ No match found, create new task
  | ExactDuplicate       -- ^ Exact match, auto-merge
  | SemanticDuplicate    -- ^ Similar but not exact, flag for review
  | RecurringTask        -- ^ Same pattern, link as supersedes
  deriving (Eq, Show)

-- | Result of a dedup check.
data DedupResult = DedupResult
  { drAction     :: DedupAction
  , drConfidence :: Confidence    -- ^ How confident we are this is a duplicate
  , drMatchedId  :: Maybe Text    -- ^ ID of the matched existing task (if any)
  , drNote       :: Maybe Text    -- ^ Explanation
  } deriving (Eq, Show)

-- | Check if a new intent duplicates an existing task.
-- Takes the new title/project and a list of existing (id, title, project) triples.
checkDuplicate :: Text -> Maybe Text -> [(Text, Text, Maybe Text)] -> DedupResult
checkDuplicate newTitle newProject existingTasks =
  let normNew = normaliseTitle newTitle
      candidates = [ (eid, sim, eproject)
                   | (eid, etitle, eproject) <- existingTasks
                   , let sim = titleSimilarity normNew (normaliseTitle etitle)
                   , sim > 0.5
                   ]
  in case candidates of
    [] -> DedupResult NoDuplicate (mkConfidence 1.0) Nothing Nothing
    ((eid, sim, eproject) : _)
      | sim >= 0.95 && newProject == eproject -> DedupResult
          { drAction = ExactDuplicate
          , drConfidence = mkConfidence sim
          , drMatchedId = Just eid
          , drNote = Just "Exact title + project match"
          }
      | sim >= 0.7 -> DedupResult
          { drAction = SemanticDuplicate
          , drConfidence = mkConfidence sim
          , drMatchedId = Just eid
          , drNote = Just $ "Similar title (similarity: " <> T.pack (show sim) <> ")"
          }
      | otherwise -> DedupResult
          { drAction = NoDuplicate
          , drConfidence = mkConfidence 1.0
          , drMatchedId = Nothing
          , drNote = Nothing
          }

-- | Normalise a title for comparison:
-- lowercase, strip punctuation, collapse whitespace.
normaliseTitle :: Text -> Text
normaliseTitle = T.unwords . T.words . T.filter (\c -> isAlphaNum c || isSpace c) . T.toLower

-- | Compute similarity between two normalised titles.
-- Uses Jaccard similarity on word sets.
-- Returns a value in [0.0, 1.0].
titleSimilarity :: Text -> Text -> Double
titleSimilarity a b =
  let wordsA = T.words a
      wordsB = T.words b
      intersection = length [ w | w <- wordsA, w `elem` wordsB ]
      union' = length wordsA + length wordsB - intersection
  in if union' == 0 then 1.0
     else fromIntegral intersection / fromIntegral union'
