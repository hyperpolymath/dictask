-- SPDX-License-Identifier: PMPL-1.0-or-later
module Test.Dictask.Parse.DateResolverSpec (spec) where

import Test.Hspec
import Data.Time (fromGregorian)
import Dictask.Parse.DateResolver
import Dictask.Parse.Types (unConfidence)

spec :: Spec
spec = do
  let today = fromGregorian 2026 3 13  -- A Friday

  describe "resolveDate" $ do
    it "resolves 'today' to current date with high confidence" $ do
      let result = resolveDate today "today"
      rdDate result `shouldBe` Just today
      rdTentative result `shouldBe` False
      unConfidence (rdConfidence result) `shouldSatisfy` (>= 0.9)

    it "resolves 'tomorrow' to next day" $ do
      let result = resolveDate today "tomorrow"
      rdDate result `shouldBe` Just (fromGregorian 2026 3 14)

    it "marks 'next week' as tentative" $ do
      let result = resolveDate today "next week"
      rdTentative result `shouldBe` True

    it "returns no date for 'soon'" $ do
      let result = resolveDate today "soon"
      rdDate result `shouldBe` Nothing
      rdTentative result `shouldBe` True
      unConfidence (rdConfidence result) `shouldSatisfy` (< 0.3)

    it "flags holiday references for review" $ do
      let result = resolveDate today "after easter"
      rdDate result `shouldBe` Nothing
      rdTentative result `shouldBe` True
