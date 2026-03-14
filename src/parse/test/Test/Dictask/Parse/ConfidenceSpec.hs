-- SPDX-License-Identifier: PMPL-1.0-or-later
module Test.Dictask.Parse.ConfidenceSpec (spec) where

import Test.Hspec
import Dictask.Parse.Types
import Dictask.Parse.Confidence

spec :: Spec
spec = do
  describe "Confidence thresholds" $ do
    it "0.9 is high confidence" $
      isHighConfidence (mkConfidence 0.9) `shouldBe` True

    it "0.5 is medium confidence" $
      isMediumConfidence (mkConfidence 0.5) `shouldBe` True

    it "0.1 is low confidence" $
      isLowConfidence (mkConfidence 0.1) `shouldBe` True

    it "clamps values above 1.0" $
      unConfidence (mkConfidence 1.5) `shouldBe` 1.0

    it "clamps values below 0.0" $
      unConfidence (mkConfidence (-0.5)) `shouldBe` 0.0

  describe "Review routing" $ do
    it "high confidence routes to AutoApply" $
      routeIntent (mkConfidence 0.9) `shouldBe` AutoApply

    it "medium confidence routes to HumanReview" $
      routeIntent (mkConfidence 0.5) `shouldBe` HumanReview

    it "low confidence routes to LogOnly" $
      routeIntent (mkConfidence 0.1) `shouldBe` LogOnly

  describe "Ambiguity penalisation" $ do
    it "penalises 'maybe' by 0.15" $ do
      let (adjusted, _) = penaliseAmbiguity "maybe I should do this" (mkConfidence 0.9)
      unConfidence adjusted `shouldSatisfy` (< 0.9)

    it "does not penalise clear text" $ do
      let (adjusted, notes) = penaliseAmbiguity "fix the build now" (mkConfidence 0.9)
      unConfidence adjusted `shouldBe` 0.9
      notes `shouldBe` Nothing

  describe "Intent-type adjustment" $ do
    it "caps DeleteTask confidence at 0.7" $ do
      let adjusted = adjustConfidence DeleteTask (mkConfidence 0.95)
      unConfidence adjusted `shouldSatisfy` (<= 0.7)
