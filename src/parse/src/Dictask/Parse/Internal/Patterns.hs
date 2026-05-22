-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- | Internal pattern definitions for intent detection.
-- Not exported directly — used by Dictask.Parse.Intent.
module Dictask.Parse.Internal.Patterns where

import Data.Text (Text)

-- | Patterns that indicate a new task is being described.
addTaskPrefixes :: [Text]
addTaskPrefixes =
  [ "i need to"
  , "todo"
  , "add task"
  , "remember to"
  , "don't forget to"
  , "make sure to"
  , "i should"
  , "we need to"
  , "i want to"
  , "i have to"
  , "i must"
  , "note to self"
  , "action item"
  , "task"
  ]

-- | Patterns that indicate a deadline is being set.
deadlinePrefixes :: [Text]
deadlinePrefixes =
  [ "by"
  , "due"
  , "deadline"
  , "before"
  , "until"
  , "no later than"
  , "finish by"
  , "complete by"
  ]

-- | Patterns that indicate task deletion/cancellation.
deletionPrefixes :: [Text]
deletionPrefixes =
  [ "remove task"
  , "delete task"
  , "cancel task"
  , "drop"
  , "remove"
  , "forget about"
  , "never mind"
  , "scratch that"
  ]

-- | Keywords that indicate high urgency.
urgencyKeywords :: [(Text, Double)]
urgencyKeywords =
  [ ("asap", 0.9)
  , ("urgent", 0.9)
  , ("critical", 1.0)
  , ("emergency", 1.0)
  , ("right away", 0.85)
  , ("immediately", 0.95)
  , ("rush", 0.8)
  , ("time sensitive", 0.8)
  ]

-- | Keywords that indicate high importance.
importanceKeywords :: [(Text, Double)]
importanceKeywords =
  [ ("important", 0.8)
  , ("essential", 0.9)
  , ("crucial", 0.9)
  , ("vital", 0.85)
  , ("key", 0.7)
  , ("must", 0.75)
  , ("required", 0.7)
  , ("high priority", 0.85)
  ]

-- | Markers that reduce confidence due to ambiguity.
ambiguityMarkers :: [(Text, Double)]
ambiguityMarkers =
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
