#!/usr/bin/env stack
-- stack runghc --resolver lts-7 --install-ghc --package QuickCheck

import Control.Monad
import Data.Monoid
import Test.QuickCheck

data Optional a = Nada | Only a
  deriving (Eq, Show)

newtype First' a =
  First' { getFirst' :: Optional a }
  deriving (Eq, Show)

instance (Arbitrary a) => Arbitrary (First' a) where
  arbitrary = do
    a <- arbitrary
    frequency [ (1 , return $ First' Nada)
              , (10, return $ First' (Only a)) ]

instance Monoid (First' a) where
  mempty                                  = First' Nada
  mappend (First' (Only x)) _             = First' $ Only x
  mappend (First' Nada) (First' (Only x)) = First' $ Only x
  mappend (First' Nada) (First' Nada)     = First' Nada

firstMappend :: First' a
             -> First' a
             -> First' a
firstMappend = mappend

type FirstMappend =
     First' String
  -> First' String
  -> First' String
  -> Bool

type FstId =
  First' String -> Bool


monoidAssoc :: (Eq m, Monoid m) => m -> m -> m -> Bool
monoidAssoc a b c = (a <> (b <> c)) == ((a <> b) <> c)

monoidLeftIdentity :: (Eq m, Monoid m) => m -> Bool
monoidLeftIdentity a = (mempty <> a) == a

monoidRightIdentity :: (Eq m, Monoid m) => m -> Bool
monoidRightIdentity a = (a <> mempty) == a


main :: IO ()
main = do
  quickCheck (monoidAssoc :: FirstMappend)
  quickCheck (monoidLeftIdentity :: FstId)
  quickCheck (monoidRightIdentity :: FstId)
