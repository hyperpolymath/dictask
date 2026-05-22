-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- | Main intent parser module.
-- Uses megaparsec to extract structured task intents from speech transcripts.
--
-- The parser processes transcript text and produces a list of 'CandidateIntent'
-- values, each with a confidence score. High-confidence intents (>= 0.8) are
-- auto-applied to the canonical store; medium-confidence (0.3–0.8) go to the
-- review queue; low-confidence (< 0.3) are logged only.
module Dictask.Parse.Intent
  ( -- * Parsing
    parseTranscript
  , parseIntent
    -- * Re-exports
  , module Dictask.Parse.Types
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L

import Dictask.Parse.Types

-- | Parser type alias for megaparsec.
type Parser = Parsec Void Text

-- | Parse a full transcript into a list of candidate intents.
-- Each sentence/phrase boundary is checked for task-like patterns.
parseTranscript :: Text -> Text -> [CandidateIntent]
parseTranscript _parserVersion _transcriptText =
  -- STUB: Full implementation will:
  -- 1. Split transcript into sentences/segments
  -- 2. Run each segment through intent pattern matchers
  -- 3. Assign confidence scores based on pattern match quality
  -- 4. Resolve relative dates via DateResolver
  -- 5. Extract priority keywords via Priority module
  -- 6. Return list of CandidateIntents
  []

-- | Parse a single segment for task intent.
-- Returns Nothing if no task-like pattern is detected.
parseIntent :: Text -> Maybe (IntentType, Confidence, ParsedData)
parseIntent segment =
  case parse pIntentDetector "" segment of
    Left _  -> Nothing
    Right r -> Just r

-- | Top-level intent detector parser.
-- Tries each intent pattern in order of specificity.
pIntentDetector :: Parser (IntentType, Confidence, ParsedData)
pIntentDetector = choice
  [ try pAddTaskIntent
  , try pDeadlineIntent
  , try pPriorityIntent
  , try pDeleteIntent
  , pNoteIntent
  ]

-- | Detect "I need to...", "TODO:...", "Add task:...", "Remember to..." patterns.
pAddTaskIntent :: Parser (IntentType, Confidence, ParsedData)
pAddTaskIntent = do
  _ <- choice
    [ string' "i need to "
    , string' "todo "
    , string' "add task "
    , string' "remember to "
    , string' "don't forget to "
    , string' "make sure to "
    , string' "i should "
    , string' "we need to "
    , string' "i want to "
    , string' "i have to "
    ]
  rest <- takeRest
  let title = T.strip rest
  pure
    ( AddTask
    , mkConfidence 0.85
    , ParsedData
        { pdTitle = title
        , pdDescription = Nothing
        , pdDeadline = Nothing
        , pdDeadlineTentative = False
        , pdPriorityKeywords = []
        , pdTags = []
        , pdProject = Nothing
        , pdTargetTaskId = Nothing
        }
    )

-- | Detect deadline-setting patterns: "by Friday", "due next week", etc.
pDeadlineIntent :: Parser (IntentType, Confidence, ParsedData)
pDeadlineIntent = do
  _ <- choice
    [ string' "set deadline "
    , string' "due "
    , string' "by "
    , string' "deadline "
    ]
  rest <- takeRest
  let title = T.strip rest
  pure
    ( SetDeadline
    , mkConfidence 0.7  -- Dates from speech are often tentative
    , ParsedData
        { pdTitle = title
        , pdDescription = Nothing
        , pdDeadline = Nothing  -- Resolved by DateResolver module
        , pdDeadlineTentative = True
        , pdPriorityKeywords = []
        , pdTags = []
        , pdProject = Nothing
        , pdTargetTaskId = Nothing
        }
    )

-- | Detect priority-setting patterns: "urgent", "high priority", "asap".
pPriorityIntent :: Parser (IntentType, Confidence, ParsedData)
pPriorityIntent = do
  kw <- choice
    [ string' "urgent " *> pure "urgent"
    , string' "high priority " *> pure "high_priority"
    , string' "asap " *> pure "asap"
    , string' "critical " *> pure "critical"
    , string' "important " *> pure "important"
    ]
  rest <- takeRest
  let title = T.strip rest
  pure
    ( SetPriority
    , mkConfidence 0.9
    , ParsedData
        { pdTitle = title
        , pdDescription = Nothing
        , pdDeadline = Nothing
        , pdDeadlineTentative = False
        , pdPriorityKeywords = [kw]
        , pdTags = []
        , pdProject = Nothing
        , pdTargetTaskId = Nothing
        }
    )

-- | Detect deletion patterns: "remove task", "delete", "cancel".
pDeleteIntent :: Parser (IntentType, Confidence, ParsedData)
pDeleteIntent = do
  _ <- choice
    [ string' "remove task "
    , string' "delete task "
    , string' "cancel task "
    , string' "drop "
    , string' "remove "
    ]
  rest <- takeRest
  pure
    ( DeleteTask
    , mkConfidence 0.6  -- Deletions always go to review queue
    , ParsedData
        { pdTitle = T.strip rest
        , pdDescription = Nothing
        , pdDeadline = Nothing
        , pdDeadlineTentative = False
        , pdPriorityKeywords = []
        , pdTags = []
        , pdProject = Nothing
        , pdTargetTaskId = Nothing
        }
    )

-- | Fallback: treat unrecognised speech as a general note.
pNoteIntent :: Parser (IntentType, Confidence, ParsedData)
pNoteIntent = do
  rest <- takeRest
  pure
    ( Note
    , mkConfidence 0.3
    , ParsedData
        { pdTitle = T.strip rest
        , pdDescription = Nothing
        , pdDeadline = Nothing
        , pdDeadlineTentative = False
        , pdPriorityKeywords = []
        , pdTags = []
        , pdProject = Nothing
        , pdTargetTaskId = Nothing
        }
    )
