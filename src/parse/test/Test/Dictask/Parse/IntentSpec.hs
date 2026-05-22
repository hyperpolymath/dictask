-- SPDX-License-Identifier: MPL-2.0
module Test.Dictask.Parse.IntentSpec (spec) where

import Test.Hspec
import Dictask.Parse.Intent
import Dictask.Parse.Types

spec :: Spec
spec = do
  describe "parseIntent" $ do
    it "detects 'I need to' as AddTask with high confidence" $ do
      case parseIntent "i need to fix the build pipeline" of
        Just (AddTask, conf, pd) -> do
          isHighConfidence conf `shouldBe` True
          pdTitle pd `shouldBe` "fix the build pipeline"
        _ -> expectationFailure "Expected AddTask intent"

    it "detects 'remember to' as AddTask" $ do
      case parseIntent "remember to buy groceries" of
        Just (AddTask, _, pd) -> pdTitle pd `shouldBe` "buy groceries"
        _ -> expectationFailure "Expected AddTask intent"

    it "detects 'urgent' as SetPriority with very high confidence" $ do
      case parseIntent "urgent fix the security vulnerability" of
        Just (SetPriority, conf, _) ->
          unConfidence conf `shouldSatisfy` (>= 0.9)
        _ -> expectationFailure "Expected SetPriority intent"

    it "detects 'remove task' as DeleteTask with medium confidence" $ do
      case parseIntent "remove task old deployment script" of
        Just (DeleteTask, conf, _) ->
          isHighConfidence conf `shouldBe` False  -- Deletions never high confidence
        _ -> expectationFailure "Expected DeleteTask intent"

    it "falls back to Note for unrecognised text" $ do
      case parseIntent "the weather is nice today" of
        Just (Note, conf, _) ->
          isMediumConfidence conf `shouldBe` True  -- Note is 0.3, on the boundary
        _ -> expectationFailure "Expected Note intent"
