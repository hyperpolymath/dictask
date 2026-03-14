-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- | Resolve natural-language date references from speech transcripts.
--
-- Handles patterns like:
--   "tomorrow"       → concrete date, high confidence
--   "next Friday"    → concrete date, high confidence
--   "next week"      → tentative (which day?), medium confidence
--   "after Easter"   → tentative (holiday lookup needed), low confidence
--   "sometime soon"  → no date, flag as tentative
module Dictask.Parse.DateResolver
  ( -- * Date resolution
    ResolvedDate (..)
  , resolveDate
  , resolveDateFromText
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, addDays, DayOfWeek (..), dayOfWeek)

import Dictask.Parse.Types (Confidence, mkConfidence)

-- | A resolved date with its confidence and tentative flag.
data ResolvedDate = ResolvedDate
  { rdDate       :: Maybe Day    -- ^ Nothing if no date could be resolved
  , rdTentative  :: Bool         -- ^ True if the date is uncertain
  , rdConfidence :: Confidence   -- ^ How confident we are in this resolution
  , rdNote       :: Maybe Text   -- ^ Explanation (e.g. "assumed Monday for 'next week'")
  } deriving (Eq, Show)

-- | Resolve a date expression relative to the current date.
-- Returns a ResolvedDate with confidence and tentative flag.
resolveDate :: Day -> Text -> ResolvedDate
resolveDate today expr =
  let lower = T.strip (T.toLower expr)
  in case lower of
    -- High confidence, concrete dates
    "today" -> ResolvedDate
      { rdDate = Just today
      , rdTentative = False
      , rdConfidence = mkConfidence 0.95
      , rdNote = Nothing
      }

    "tomorrow" -> ResolvedDate
      { rdDate = Just (addDays 1 today)
      , rdTentative = False
      , rdConfidence = mkConfidence 0.95
      , rdNote = Nothing
      }

    -- Medium confidence, assumes start of period
    "next week" -> ResolvedDate
      { rdDate = Just (nextWeekday Monday today)
      , rdTentative = True
      , rdConfidence = mkConfidence 0.6
      , rdNote = Just "Assumed Monday for 'next week'"
      }

    "end of week" -> ResolvedDate
      { rdDate = Just (nextWeekday Friday today)
      , rdTentative = True
      , rdConfidence = mkConfidence 0.7
      , rdNote = Just "Assumed Friday for 'end of week'"
      }

    -- Low confidence, vague
    "soon" -> ResolvedDate
      { rdDate = Nothing
      , rdTentative = True
      , rdConfidence = mkConfidence 0.2
      , rdNote = Just "'Soon' is too vague to assign a date"
      }

    "eventually" -> ResolvedDate
      { rdDate = Nothing
      , rdTentative = True
      , rdConfidence = mkConfidence 0.1
      , rdNote = Just "'Eventually' — no date assigned"
      }

    "sometime" -> ResolvedDate
      { rdDate = Nothing
      , rdTentative = True
      , rdConfidence = mkConfidence 0.15
      , rdNote = Just "'Sometime' — no date assigned"
      }

    -- Named weekdays
    _ | "next monday" `T.isPrefixOf` lower    -> weekdayResult Monday
      | "next tuesday" `T.isPrefixOf` lower   -> weekdayResult Tuesday
      | "next wednesday" `T.isPrefixOf` lower  -> weekdayResult Wednesday
      | "next thursday" `T.isPrefixOf` lower   -> weekdayResult Thursday
      | "next friday" `T.isPrefixOf` lower     -> weekdayResult Friday
      | "next saturday" `T.isPrefixOf` lower   -> weekdayResult Saturday
      | "next sunday" `T.isPrefixOf` lower     -> weekdayResult Sunday

    -- Holiday references — flag for review
      | "after easter" `T.isInfixOf` lower -> ResolvedDate
          { rdDate = Nothing
          , rdTentative = True
          , rdConfidence = mkConfidence 0.3
          , rdNote = Just "Holiday reference 'Easter' — needs calendar lookup"
          }
      | "after christmas" `T.isInfixOf` lower -> ResolvedDate
          { rdDate = Nothing
          , rdTentative = True
          , rdConfidence = mkConfidence 0.3
          , rdNote = Just "Holiday reference 'Christmas' — needs calendar lookup"
          }

    -- Unrecognised
      | otherwise -> ResolvedDate
          { rdDate = Nothing
          , rdTentative = True
          , rdConfidence = mkConfidence 0.2
          , rdNote = Just $ "Could not resolve date from: " <> expr
          }
  where
    weekdayResult dow = ResolvedDate
      { rdDate = Just (nextWeekday dow today)
      , rdTentative = False
      , rdConfidence = mkConfidence 0.85
      , rdNote = Nothing
      }

-- | Find the next occurrence of a given weekday after today.
nextWeekday :: DayOfWeek -> Day -> Day
nextWeekday target today' =
  let todayDow = dayOfWeek today'
      daysUntil = (fromEnum target - fromEnum todayDow + 7) `mod` 7
      offset = if daysUntil == 0 then 7 else daysUntil
  in addDays (fromIntegral offset) today'

-- | Convenience: try to find and resolve a date expression within free text.
-- Looks for common patterns like "by <date>", "due <date>", "before <date>".
resolveDateFromText :: Day -> Text -> Maybe ResolvedDate
resolveDateFromText today text =
  let lower = T.toLower text
      patterns = ["by ", "due ", "before ", "until ", "deadline "]
      extracted = [ T.strip (T.drop (T.length p) after)
                  | p <- patterns
                  , let (_, after) = T.breakOn p lower
                  , p `T.isInfixOf` lower
                  ]
  in case extracted of
    (dateExpr : _) -> Just (resolveDate today dateExpr)
    []             -> Nothing
