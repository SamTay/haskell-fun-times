# Basic Libraries

Captain Obvious once said "Data structures are very important".
It's true. Computers are fast, but CPUs aren't getting much faster.
The structures we choose to represent data directly affect
the speed and memory involved in processing data.

### 28.2 Benchmarking with Criterion
Criterion is an easy-to-use library for measuring performance of libraries and arbitrary functions.
It can output concise raw data on the terminal, or nice graphs in HTML.
See an example at [bench.hs](./bench.hs).
Just remember to run it with `-O` or `-O2`:
```
stack ghc -- -O2 bench.hs
./bench
```
(Note that `stack runghc` is an "interactive" mode that ignores the optimization flag `-O`.)

Criterion offers `whnf` and `nf` for evaluating to weak head normal form and normal form respectively:
```haskell
defaultMain :: [Benchmark] -> IO ()
whnf :: (a -> b) -> a -> Benchmarkable
nf   :: Control.DeepSeq.NFData b
     => (a -> b) -> a -> Benchmarkable
```
Notice we pass the function and its argument separately,
so the result is not shared across benchmarking samples.
In the `bench.hs` example above, we only need `whnf`
because `!!` and `!?` don't return a data constructor until they've already done their work
(the bit in the recursive call).
To use `nf` we need to write our own `NFData` instance (there are examples in the deepseq library).

#### More on whnf and nf
We should use `whnf` when the first data constructor is an indicator
that the work we're profiling is done. This happens pretty often.

One example when `whnf` is insufficient is for functions using *guarded recursion*,
where a data constructor is interposed between steps, such as `map (+1)`
(`:` is between each recursion step for `map`).

Unlike `map` which is always guarded, `foldr` can result in guarded *or* unguarded recursion
depending on the folding function.

### 28.3 Profilng your programs
To profile a program with GHC, first read the [GHC User Guide](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/profiling.html).
This book is actually better used as a reference in this section
for what tools and commands to use for different tasks, so no notes are necessary.

### 28.4 Constant applicative forms
CAFs are expressions that have no free variables and are held in memory
to be shared with all other expressions in a module.
They can be literal values or partially-applied functions,
so long as the arguments aren't named.
The sharing can increase speed by avoiding re-evaluation,
but can become memory intensive very quickly.
This is rarely a problem in real code since most large amounts of data usually come from elsewhere.
If we do see too much memory usage, check for a large CAF like `largeCAF` below:
```haskell
-- CAF.hs
module Main where

largeCAF :: [Integer]
largeCAF = map (+1) [1..]

notCAF :: [Integer] -> [Integer]
notCAF x = map (+1) x

stillCAF :: [Integer] -> [Integer]
stillCAF = map (+1)

main :: IO ()
main = do
  print $ largeCAF !! 1000
  print $ largeCAF !! 9000
  print $ notCAF [1..] !! 1000
  print $ notCAF [1..] !! 9000
  print $ stillCAF [1..] !! 1000
  print $ stillCAF [1..] !! 9000
```
Then we can view profiling results with these commands:
```shell
$ stack ghc -- -prof -fprof-auto -rtsopts -O2 CAF.hs
$ ./CAF +RTS -hc -p
$ cat CAF.prof 
COST CENTRE MODULE  %time %alloc

largeCAF    Main     75.0   38.6
notCAF      Main     25.0   21.2
main        Main      0.0   17.9
stillCAF    Main      0.0   21.2
                                                     individual      inherited
COST CENTRE MODULE                no.     entries  %time %alloc   %time %alloc

MAIN        MAIN                   46          0    0.0    0.0   100.0  100.0
 main       Main                   93          0    0.0    0.5     0.0    0.5
 CAF        Main                   91          0    0.0    0.0   100.0   98.4
  stillCAF  Main                   96          1    0.0    0.0     0.0    0.0
  largeCAF  Main                   94          1   75.0   38.6    75.0   38.6
  main      Main                   92          1    0.0   17.4    25.0   59.9
   stillCAF Main                   97          0    0.0   21.2     0.0   21.2
   notCAF   Main                   95          1   25.0   21.2    25.0   21.2
 CAF        GHC.IO.Handle.FD       88          0    0.0    0.9     0.0    0.9
 CAF        GHC.IO.Encoding        84          0    0.0    0.1     0.0    0.1
 CAF        GHC.IO.Handle.Text     83          0    0.0    0.0     0.0    0.0
 CAF        GHC.Conc.Signal        80          0    0.0    0.0     0.0    0.0
 CAF        GHC.IO.Encoding.Iconv  69          0    0.0    0.0     0.0    0.0
```

We see that **pointfree top-level declarations are CAFs**, while pointful ones are not.
This is important to keep in mind; in particular for lists, which in Haskell
are as much control structures as data structures.
It's *very cheap* in GHC to construct and throw away lists.
It can affect how much memory is used in *total*,
but when it's not a CAF,
it won't stay in the heap constantly which can lead to higher peak memory usage.

### 28.5 Map
Map is defined in the Data.Map module of the
[*containers*](http://hackage.haskell.org/package/containers) library as
```haskell
data Map k a
  = Bin {-# UNPACK #-} !Size !k a !(Map k a) !(Map k a)
  | Tip
type Size = Int
```

Data.Map.Map **excels** at looking up by key,
however if you are using Int as a key type, you're probably better off
with HashMap, IntMap, or Vector.

### 28.6 Set
Set also lives in *containers*. It's like Map, but it's only the *key* part of *key,value* pairs.
Or, just ordered values.
It is equivalent to a Map type with unit values, so it has the same pros and cons as Map.
```haskell
data Set a
  = Bin {-# UNPACK #-} !Size !a !(Set a) !(Set a)
  | Tip

type Size = Int
```

### 28.7 Sequence
Sequence, also from *containers*, is built on finger trees and appends cheaply on front and back.
```haskell
newtype Seq a = Seq (FingerTree (Elem a))

-- Elem is so elements and nodes can be
-- distinguished in the types of the
-- implementation. Don't sweat it.
newtype Elem a = Elem { getElem :: a }

data FingerTree a
  = Empty
  | Single a
  | Deep {-# UNPACK #-} !Int !(Digit a)
         (FingerTree (Node a)) !(Digit a)
```
Updates (cons and append) to both ends of the data structure are where Sequence excels.
If you don't need that and just need consing on the front,
the normal list can compete with this option, especially
when the lists are small.
Also, Sequence is a persistent data structure like Map, so the memory density
isn't as good as it is with Vector.

### 28.8 Vector
The Vector type lives in the *vectors* library.
Vectors are "efficient arrays". According to Chris, the Array type is rarely used in Haskell,
and we almost always want Vector, which is a slice wrapper of Array:
```haskell
-- | Boxed vectors, supporting efficient slicing.
data Vector a = Vector {-# UNPACK #-} !Int
                       {-# UNPACK #-} !Int
                       {-# UNPACK #-} !(Array a)
    deriving ( Typeable )
```
Vectors come in boxed, unboxed, immutable, mutable, and storable flavors -- but the plain version
is most common.
"Boxed" vectors can reference any datatype we want,
while "unboxed" represents raw values without pointer indirection,
which can save a lot of memory but is limited to types like
Bool, Char, Double, Float, Int, Word, etc.
Recall newtypes don't introduce pointer indirection, so unboxable types are closed under newtyping.

You want a vector when

- you need memory efficiency close to theoretical maximum
- data access is almost exclusively by indexing via Int values
- you want uniform access times for each element in the structure
- you construct a Vector *once* and read it many times (or use mutable version for ongoing updates)
- you want efficient slicing

#### Updating vectors
In general persistent vectors are not great at handling ongoing updates,
however sometimes **loop fusion** can alleviate this.
Fusion, accomplished via [GHC Rules](https://wiki.haskell.org/GHC/Using_rules),
means that the compiler can fuse several loops into one megaloop and do it in one pass:
```haskell
import qualified Data.Vector as V

testV :: Int -> V.Vector Int
testV n =
  V.map (+n) $ V.map (+n) $
    V.map (+n) $ V.map (+n)
    (V.fromList [1..10000])

-- turns into

testV :: Int -> V.Vector Int
testV n =
  V.map ( (+n) . (+n)
        . (+n) . (+n) ) (V.fromList [1..10000])

```

However, this won't be best for all situations.
Sometimes we need to update certain elements selectively;
for this, we can use the batch operator `//`:
```haskell
batchList :: Int -> V.Vector Int
batchList n = vec // updates
  where updates = fmap (\n -> (n, 0)) [0..n]
```
This is super quick. Also, compiling the `updates` first and then passing to the batch operation
is about 500-1000x faster than calling `//` for each element in the `updates` list.
If you're going to use the batch, make sure you batch!
Furthermore, this can be speeded up by 1.4% by putting the updates in a Vector themselves,
in which case we use `V.unsafeUpdate` instead of `V.//`.

#### Mutable Vectors
We can squeeze even more performance out of vectors, when necessary, by using mutation.
Here are two different methods, IO and ST:
```haskell
import Control.Monad.Primitive
import Control.Monad.ST
import Criterion.Main
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as MV
import qualified Data.Vector.Generic.Mutable as GM

mutableUpdateIO :: Int -> IO (MV.MVector RealWorld Int)
mutableUpdateIO n = do
  mvec <- GM.new (n+1)
  go n mvec
  where go 0 v = return v
        go n v = (MV.write v n 0) >> go (n-1) v

mutableUpdateST :: Int -> V.Vector Int
mutableUpdateST n = runST $ do
  mvec <- GM.new (n+1)
  go n mvec
  where go 0 v = V.freeze v
        go n v = (MV.write v n 0) >> go (n-1) v
```
and the performance results of all these methods, updating a 10,000 element list:

Variant | Microseconds
--- | ---
slow | 133,600
batchList | 244
batchVector | 176
mutableUpdateST | 32
mutableUpdateIO | 19

ST is slightly slower than the IO version due to the freezing and unfreezing. The biggest
improvement is from not being an idiot.

ST works by unfreezing data, mutating it, and then refreezing it so that it cannot be mutated further,
and thus manages to maintain referential transparency.
Under the hood it looks like a primitive `GHC.Prim.State# s -> (# GHC.Prim.State# s, a #)` type.
The state `s` is not the actual thing we're mutating, and has no value level witness.
The `s` type enables `ST` to enforce at compile-time that the mutable references to persistent
immutable data structures are kept within the `ST` monad, using a trick called
*existential quantification*.

The thaws and freezes from dipping in and out of ST are costly - if it has to happen often,
it is probably better to just use `IO`.

### 28.9 String types
#### String
`String`s in Haskell are okay for demonstrations or toy programs, but the memory usage
for large strings can get out of control rapidly, and most operations
on them have times proportional to the length of the list.

#### Text
`Text` is good for when we have plain text and need better memory usage performance
and more efficient indexing into the string. However, Text is encoded as
UTF-16, and while this is faster, it can be unexpected since UTF-8 is vastly
more popular.

#### ByteString
ByteStrings are not necessarily strings/text, but a sequence of bytes represented
as a vector of Word8 values. Note that text on a computer is obviously always
made up of bytes, but needs an encoding in order to be "read" as text (such as
the common ASCII, UTF-8, UTF-16, etc.). As we mentioned, Text uses size 16 to
read larger chunks at a time, increasing performance.

The downside to ByteString is that it encompasses byte data that might not be
"readable" text, which can be a problem if you don't want to permit non-text
byte sequences.

Note that in most cases **Data.ByteString.Char8** is not what you're looking for,
as it doesn't support Unicode, and is **only** for ASCII data.

#### ByteString vs. Text
Sometimes you'll choose ByteString over Text if you want to keep incoming UTF-8
encoded data in UTF-8, instead of encoding/decoding it out of Text.

### 28.10 Chapter Exercises

1. [Difference list](./DList.hs): **note** right now benchmarks don't show improvement:

  ```
  benchmarking concat list
  time                 55.59 ms   (54.99 ms .. 56.29 ms)
                       1.000 R²   (0.999 R² .. 1.000 R²)
  mean                 54.90 ms   (54.64 ms .. 55.19 ms)
  std dev              492.0 μs   (304.4 μs .. 812.6 μs)

  benchmarking concat dlist
  time                 55.12 ms   (54.74 ms .. 55.39 ms)
                       1.000 R²   (1.000 R² .. 1.000 R²)
  mean                 54.87 ms   (54.49 ms .. 55.06 ms)
  std dev              513.6 μs   (83.54 μs .. 905.2 μs)
  ```
2. [A simple queue](./Queue.hs): **note** right now benchmarks don't show improvement:

  ```
  benchmarking pop/push list
  time                 52.62 ms   (52.21 ms .. 52.94 ms)
                       1.000 R²   (1.000 R² .. 1.000 R²)
  mean                 52.46 ms   (52.10 ms .. 52.71 ms)
  std dev              533.0 μs   (345.8 μs .. 838.3 μs)

  benchmarking pop/push queue
  time                 248.4 ms   (241.4 ms .. 260.9 ms)
                       0.999 R²   (0.993 R² .. 1.000 R²)
  mean                 244.8 ms   (237.5 ms .. 248.8 ms)
  std dev              7.094 ms   (465.4 μs .. 9.180 ms)
  variance introduced by outliers: 16% (moderately inflated)
  ```
