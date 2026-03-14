-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- | Confidence scoring and ambiguity handling.
--
-- Confidence thresholds:
--   High   (>= 0.8): Auto-apply to canonical store
--   Medium (0.3–0.8): Queue for human review
--   Low    (< 0.3):  Log only, do not create task candidate
--
-- Ambiguity sources:
--   - Vague deadlines ("maybe next week", "after Easter")
--   - Tentative language ("I might need to", "possibly")
--   - Contradictory context ("do that but also don't")
--   - Incomplete sentences (transcription cut off)
module Dictask.Parse.Confidence
  ( -- * Confidence adjustment
    adjustConfidence
  , confidenceFromPatternMatch
  , penaliseAmbiguity
    -- * Review routing
  , shouldAutoApply
  , shouldReview
  , shouldLogOnly
  , routeIntent
  , ReviewRoute (..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T

import Dictask.Parse.Types

-- | Where an intent should be routed based on confidence.
data ReviewRoute
  = AutoApply      -- ^ >= 0.8: apply directly
  | HumanReview    -- ^ 0.3–0.8: queue for review
  | LogOnly        -- ^ < 0.3: log, don't create candidate
  deriving (Eq, Show)

-- | Route an intent based on its confidence score.
routeIntent :: Confidence -> ReviewRoute
routeIntent c
  | isHighConfidence c  = AutoApply
  | isMediumConfidence c = HumanReview
  | otherwise           = LogOnly

-- | Convenience: should this confidence level auto-apply?
shouldAutoApply :: Confidence -> Bool
shouldAutoApply = isHighConfidence

-- | Convenience: should this confidence level go to review?
shouldReview :: Confidence -> Bool
shouldReview = isMediumConfidence

-- | Convenience: should this confidence level be logged only?
shouldLogOnly :: Confidence -> Bool
shouldLogOnly = isLowConfidence

-- | Adjust confidence based on intent type.
-- Deletions are always penalised (never auto-apply).
-- Priority keywords boost confidence.
adjustConfidence :: IntentType -> Confidence -> Confidence
adjustConfidence DeleteTask c = mkConfidence (min 0.7 (unConfidence c))  -- Cap at 0.7, always review
adjustConfidence SetDeadline c = mkConfidence (unConfidence c * 0.9)     -- Dates are often tentative
adjustConfidence _ c = c

-- | Compute base confidence from pattern match quality.
-- Takes the number of matched keywords and total segment length.
confidenceFromPatternMatch :: Int -> Int -> Confidence
confidenceFromPatternMatch matchedKeywords segmentLength
  | segmentLength <= 0 = mkConfidence 0.0
  | otherwise = mkConfidence (fromIntegral matchedKeywords / fromIntegral (max 1 segmentLength) * 5.0)

-- | Penalise confidence for ambiguity markers in the text.
-- Returns the adjusted confidence and a note explaining the penalty.
penaliseAmbiguity :: Text -> Confidence -> (Confidence, Maybe Text)
penaliseAmbiguity text conf =
  let ambiguityMarkers =
        [ ("maybe", 0.15)
        , ("possibly", 0.15)
        , ("i think", 0.10)
        , ("not sure", 0.20)
        , ("might", 0.10)
        , ("could", 0.05)
        , ("perhaps", 0.15)
        , ("i guess", 0.20)
        , ("sometime", 0.10)
        , ("eventually", 0.10)
        ]
      lowerText = T.toLower text
      penalties = [ (marker, penalty)
                  | (marker, penalty) <- ambiguityMarkers
                  , marker `T.isInfixOf` lowerText
                  ]
      totalPenalty = sum (map snd penalties)
      adjustedConf = mkConfidence (unConfidence conf - totalPenalty)
      notes = if null penalties
              then Nothing
              else Just $ "Ambiguity detected: " <> T.intercalate ", " (map fst penalties)
  in (adjustedConf, notes)
