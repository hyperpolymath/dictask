-- SPDX-License-Identifier: PMPL-1.0-or-later
module Main (main) where

import Test.Hspec

import qualified Test.Dictask.Parse.IntentSpec as IntentSpec
import qualified Test.Dictask.Parse.ConfidenceSpec as ConfidenceSpec
import qualified Test.Dictask.Parse.DateResolverSpec as DateResolverSpec
import qualified Test.Dictask.Parse.DedupSpec as DedupSpec

main :: IO ()
main = hspec $ do
  describe "Intent Parser" IntentSpec.spec
  describe "Confidence Scoring" ConfidenceSpec.spec
  describe "Date Resolver" DateResolverSpec.spec
  describe "Deduplication" DedupSpec.spec
