-- SPDX-License-Identifier: PMPL-1.0-or-later
module Test.Dictask.Parse.DedupSpec (spec) where

import Test.Hspec
import Dictask.Parse.Dedup

spec :: Spec
spec = do
  describe "normaliseTitle" $ do
    it "lowercases and strips punctuation" $
      normaliseTitle "Fix the BUILD!!" `shouldBe` "fix the build"

    it "collapses whitespace" $
      normaliseTitle "  fix   the   build  " `shouldBe` "fix the build"

  describe "titleSimilarity" $ do
    it "returns 1.0 for identical titles" $
      titleSimilarity "fix the build" "fix the build" `shouldBe` 1.0

    it "returns > 0.5 for similar titles" $
      titleSimilarity "fix the build pipeline" "fix build pipeline"
        `shouldSatisfy` (> 0.5)

    it "returns low similarity for unrelated titles" $
      titleSimilarity "fix the build" "buy groceries"
        `shouldSatisfy` (< 0.3)

  describe "checkDuplicate" $ do
    it "detects exact duplicates" $ do
      let existing = [("id-1", "Fix the build", Just "dictask")]
      let result = checkDuplicate "Fix the build" (Just "dictask") existing
      drAction result `shouldBe` ExactDuplicate

    it "detects semantic duplicates" $ do
      let existing = [("id-1", "Fix the build pipeline", Nothing)]
      let result = checkDuplicate "Fix build pipeline" Nothing existing
      drAction result `shouldBe` SemanticDuplicate

    it "returns NoDuplicate for unrelated tasks" $ do
      let existing = [("id-1", "Buy groceries", Nothing)]
      let result = checkDuplicate "Fix the build" Nothing existing
      drAction result `shouldBe` NoDuplicate
