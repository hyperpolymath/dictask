-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- | Internal tokeniser for splitting transcripts into parseable segments.
-- Not exported directly — used by Dictask.Parse.Intent.
module Dictask.Parse.Internal.Tokeniser
  ( -- * Tokenisation
    splitIntoSegments
  , normaliseSegment
  ) where

import Data.Char (isSpace, toLower)
import Data.Text (Text)
import qualified Data.Text as T

-- | Split a transcript into sentence-like segments.
-- Uses period, question mark, exclamation mark, and long pauses as boundaries.
splitIntoSegments :: Text -> [Text]
splitIntoSegments = filter (not . T.null) . map T.strip . T.splitOn "."

-- | Normalise a segment for pattern matching:
-- lowercase, collapse whitespace, strip leading/trailing spaces.
normaliseSegment :: Text -> Text
normaliseSegment = T.unwords . T.words . T.toLower . T.strip
