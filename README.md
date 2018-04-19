

# Stream Programming libraries in haskell


Table of Contents
=================


Table of Contents
=================

   * [Intro](#intro)
   * [The Libraries](#the-libraries)
      * [Pipes](#pipes)
         * [Types](#types)
            * [Proxy](#proxy)
            * [Concrete type synonyms](#concrete-type-synonyms)
               * [Effect](#effect)
               * [Producer](#producer)
               * [Consumer](#consumer)
               * [Pipe](#pipe)
               * [Polymorphic synonyms](#polymorphic-synonyms)
         * [Communication](#communication)
         * [Composition](#composition)
      * [Tubes](#tubes)
         * [Intuition](#intuition)
         * [Types](#types-1)
            * [Tube](#tube)
            * [Source](#source)
            * [Sink](#sink)
            * [Channel](#channel)
            * [Pump](#pump)
         * [Utilities](#utilities)

* [Theoretical takeaways](#theoretical-takeaways)
    * [Monad](#monad)
    * [Monad transformer](#monad-transformer)
    * [Lifting](#lifting)
* [Comparison](#comparison)
    * [Pipes](#pipes-1)
    * [Tubes](#tubes-1)
* [Windowed Wordcount with Pipes](#windowed-wordcount-with-pipes)
* [Conclusions](#conclusions)  

# Intro
Research conducted by Luca Lodi and Philippe Scorsolini for the course of "Principles of Programming Languages" at Politecnico di Milano by Professor Pradella Matteo and with the supervision of Riccardo Tommasini.

In this post we'll try to examine two haskell "stream processing" libraries, [Pipes](https://hackage.haskell.org/package/pipes) and[Tubes](https://hackage.haskell.org/package/tubes), investigating whether or not they can be used and/or adapted to perform "stream processing", to be meant as in systems as Flink, Spark Streaming, Kafka and others.

# The Libraries

## Pipes

Pipes *“is a clean and powerful stream processing library that lets you build and connect reusable streaming components”*. Its main focus is clearly to offer the simplest building blocks possible, that can then be used to build more sophisticated streaming abstractions, as can be seen in the rich ecosystem of libraries surrounding pipes.

### Types

#### Proxy

The main component of the library is the monad transformer Proxy. A **monad transformer** is a type constructor which takes a monad as an argument and returns a monad. Through **lifting** one is able to use functions defined in the base monad also in the monad obtained from the monad transformer application.
```haskell
-- Defined in ‘Control.Monad.Trans.Class’
lift :: (Monad m, MonadTrans t) => m a -> t m a

-- Defined in ‘Pipes.Internal’
data Proxy a' a b' b m r
    = Request a' (a  -> Proxy a' a b' b m r )
    | Respond b  (b' -> Proxy a' a b' b m r )
    | M          (m    (Proxy a' a b' b m r))
    | Pure r
instance Monad m => Applicative (Proxy a' a b' b m)
instance Monad m => Functor (Proxy a' a b' b m)
instance Monad m => Monad (Proxy a' a b' b m)
instance (Monad m, Monoid r, Data.Semigroup.Semigroup r) =>
         Monoid (Proxy a' a b' b m r)
instance MFunctor (Proxy a' a b' b) -- Defined in ‘Pipes.Internal’
instance MMonad (Proxy a' a b' b) -- Defined in ‘Pipes.Internal’
instance MonadIO m => MonadIO (Proxy a' a b' b m)
instance MonadTrans (Proxy a' a b' b)
```
A ’Proxy’ receives and sends information both upstream and downstream:

-   **upstream interface**: receives *a* and send *a’*

-   **downstream interface**: send *b* and receives *b’*

-   **m**: the base monad

-   **r**: the return value

#### Concrete type synonyms

Pipes offers many concrete type synonyms for ’Proxy’ specializing further its more generic signature. Defined **X** the empty type, used to close output ends.

##### Effect
```haskell
-- Defined in ‘Pipes.Core’
type Effect = Proxy X () () X :: (* -> *) -> * -> *
```
Which represents an effect in the base monad, modeling a non-streaming component, and can be *run*, converting it back to the base monad through:
```haskell
runEffect :: Monad m => Effect m r -> m r
```
##### Producer
```haskell
type Producer b = Proxy X () () b :: (* -> *) -> * -> *
```
Representing a Proxy producing *b* downstream, models a streaming source.

##### Consumer
```haskell
type Consumer a = Proxy () a () X :: (* -> *) -> * -> *
```
Representing a Proxy consuming *a* from upstream, models a streaming sink.

##### Pipe
```haskell
type Pipe a b = Proxy () a () b :: (* -> *) -> * -> *
```
Representing a Proxy consuming *a* from upstream and producing *b* downstream, models a stream transformation.

##### Polymorphic synonyms

For each of these types synonyms, except for Pipe, also a *polymorphic version* is defined, using the [Rank-N types](https://wiki.haskell.org/Rank-N_types) GHC extension:
```haskell
type Effect' (m :: * -> *) r = forall x' x y' y. Proxy xb ' x y' y m r
type Producer' b (m :: * -> *) r = forall x' x. Proxy x' x () b m r
type Consumer' a (m :: * -> *) r = forall y' y. Proxy () a y' y m r
```
which gives more freedom to some parameters (i.e. this way Pipe can both be seen as Producer’ and Consumer’ which allows to write more easily some of the following signatures)

### Communication

To enforce loose coupling, components can only communicate using two functions:
```haskell
-- Defined in ‘Pipes’
yield :: Monad m => a -> Producer' a m ()
await :: Monad m => Consumer' a m a
```
*yield* is used to send output data, *await* to receive inputs. Producers can only yield, Consumers only await, Pipes can do both and Effects neither yield nor await.

### Composition

Connection between components can be performed in different ways.
```haskell
for :: Monad m => Proxy x' x b' b m a' -> (b -> Proxy x' x c' c m b')
                 -> Proxy x' x c' c m a'              
```
A possible specialization of its signature can be:
```haskell
for :: Monad m => Producer a m r -> (a -> Effect m ()) -> Effect m r
```
Which explains better an example like (**for producer body**), where we loop over *producer* replacing each *yield* in it with *body*, which is a function from the output of the producer to an Effect. The **point-free counterpart** to *for* is (**∼>**) (pronounced *into*) such that:
```haskell
(f ~> g) x = for (f x) g  
```
Similarly we have “**feed**” (**>~**), that fills all the awaits this time with a given source.
```haskell
(>~) :: Monad m => Proxy a' a y' y m b -> Proxy () b y' y m c
               -> Proxy a' a y' y m c
```
e.g. (**draw >∼ p**): loops over *p* replacing each *await* with *draw*.

But the most used way to connect Proxies is surely **>->**:
```haskell
(>->) :: Monad m => Proxy a' a () b m r -> Proxy () b c' c m r
                 -> Proxy a' a c' c m r
```
Which can be used similarly to the Unix pipe operator.

Next we’ll see a basic example produced by mixing various examples in the Pipes’ tutorial , a simple main that gets strings from standard input, maps them to lower case and then prints them to standard output, showing the implementations of some parts of Pipes.Prelude.
```haskell
import Pipes
import Data.Text

stdinLn :: Producer String IO ()            -- as defined in Pipes.Prelude
stdinLn = do
  eof <- lift isEOF        -- 'lift' an 'IO' action from the base monad
  unless eof $ do
      str <- lift getLine
      yield str            -- 'yield' the 'String'
      stdinLn              -- Loop

stdoutLn :: Consumer String IO ()           -- as defined in Pipes.Prelude
stdoutLn = do
  str <- await                     -- 'await' a 'String'
  x   <- lift $ try $ putStrLn str
  case x of
      -- Gracefully terminate if we got a broken pipe error
      Left e@(G.IOError { G.ioe_type = t}) ->
          lift $ unless (t == G.ResourceVanished) $ throwIO e
      -- Otherwise loop
      Right () -> stdoutLn
-- forever :: Applicative f => f a -> f b  
-- from Control.Monad

map' f = forever $ do                       -- as defined in Pipes.Prelude
  x <- await
  yield (f x)
```
When all the *awaits* and *yield* have been handled, the resulting Proxy can be run, removing the lifts and returning the underlying base monad.
```haskell
main :: IO ()
main = runEffect $ stdinLn >->
                    map' (unpack . toLower . pack) >->  -- pack :: String -> Text,
                              -- unpack :: Text -> String viceversa
                    stdoutLn
```
Applying a monad transformer to a monad returns a monad, as we already said, so obviously results can be composed using the usual *bind* operator (>>=).

## Tubes

This report considers tubes-2.1.1.0, a stream programming library based on the concept of duality, inspired by Pipes.

### Intuition

Tubes bring stream programming capabilities into haskell. In particular it respond to the need of process in a series of stages (pipelining) a possibly infinite stream of elements. This is useful when the sequence of elements can't be hold in memory, but must be processed in chunks. Stream programming push this concept to its limit by having chunk of exactly one element.

In the pipeline analogy, each stage is a Tube, and the composition of Tubes (itself a Tube) is the final pipeline. Tube has 3 specializations: Source, Channel, Sink. As suggested by names, a Tube usually is the composition of a Source (generate elements), optionally some Channels (process / transform elements) and a Sink (simply process the element).

For example a Source continuosly reads input from console, then a Channel maps those strings to numbers, another Channel filter those numbers by a predicate, and finally a Sink output those numbers to the console.

```haskell
runTube $  -- compose and execute the Tube computation
	sample prompt -- Source that continuosly read input from console
	>< map reverse -- Channel that transform by a function
	>< filter (odd . length) -- Channel that filter by a predicate
	>< pour display -- Sink that output strings to console
```

(```><```) is the Tube composition operator.
```map``` and ```filter``` are imported from ```Tubes.Util```.

### Types

The library is based on 2 main types: the tube monad, and the dual pump comonad.

#### Tube
A tube represent a computation that can **await** elements from upstream and **yield** elements to downstream.
```haskell
Tube a b m r
```
 A general tube awaits elements of type **a**, yields elements of type **b**, performing a computation **m** that return a result of type **r**.
Tubes can be composed using the (```><```) operator, to obtain a new tube.
Is possible to obtain a monad ```m r``` from a ```Tube () () m r``` using the ```runTube``` function, or get a value from a tube that yield data with the ```reduce :: Monad m => (b -> a -> b) -> b -> Tube () a m () -> m b``` function.  
The library provide 3 **subclasses** of tube type: **source**, **channel**, **sink**.

#### Source
```haskell
Source (m :: * -> *) a = Source {sample :: Tube () a m ()}
```
Sources are a specialization of Tube that can only ```yield``` elements downstream.
The ```sample``` function is used to get the ```Tube``` corresponding to a ```Source```.
A source can be synchronously merged with another using the ```merge :: Monad m => Source m a -> Source m a -> Source m a```. In this case the resoulting Source will yield elements from the two Sources (alternating), untill they both have no elements left.

#### Sink
```haskell
Sink (m :: * -> *) a = Sink {pour :: Tube a () m ()}
```
In symmetry with the ```Source```, ```Sink``` is a specialization of ```Tube``` that can only await elements.
```Pour``` is used to obtain the corresponding ```Tube``` from a ```Sink```.
Since ```Sink``` is both a ```Contravariant``` functor and a ```Semigroup```, it is possible to map transformations over its inputs or be merged together beside another ```Sink```.

#### Channel
```haskell
Channel (m :: * -> *) a b = Channel {tune :: Tube a b m ()}
```
```Channel``` is a Tube that can convert values, while performing a monadic computation.
While it can independently ```await``` and ```yield``` elements, it can be considered as an ```Arrow``` if it yields exactly once after awaiting.

#### Pump
```haskell
(Comonad w) => Pump b a w r
```
Pumps are the dual of Tubes, they can ```send``` elements of type ```b``` and ```recv``` (receive) elements of type ```a```.
Pumps are internally used in order to run Tubes (```runTube```), since Pump's ```send``` and ```recv``` match with Tube's ```await``` and ```yield```.
Pumps can also be used in order to process streams (```lfold```, ```stream``` functions).

### Utilities

One particularly useful feature of the library is a set of function that ease the creation of Sources, Channels, and Sinks.

Among them:

- ```map```, ```filter```, ```drop```, ```take```, ```takewhile``` create a Tube that works like the corrisponding functions in Prelude, but on a stream rather than a list.
- ```prompt``` is a Source that continuosly yield strings read from the console input
- ```display``` is a Sink that continuosly output the awaited element to the console.
- ```each``` yield each element in a foldable
- ```every``` is like each, but return the element wrapped in a ```Maybe```.

## Theoretical takeaways

If you are not familiar with haskell's theoretical concepts this chapter offer a brief recap of the main ones to grasp in order to understand the components of these libraries.
The concepts are presented in an intuitive rather than formal way. For a more formal explanation you can read the referred resources.

#### Monad
Monads represents computations that can wrap values and potentially have side effects.
For example reading a character from a file is a computation with side effect (```IO Char``` monad).
Computations (monads) can be composed to obtain new more complex computations.
Many types of monads exists, to represent particular properties of computations. For example computation with input/output side-effects are represented as ```IO``` monads, while computations that wrap a state are based on the ```State``` monad.

[Monads in pictures](http://adit.io/posts/2013-04-17-functors,_applicatives,_and_monads_in_pictures.html)

#### Monad transformer
Different monad types correspond to different computation's properties (or behaviour).
But many times programmer would like a computation to display properties from multiple monad types at once, without have to declare a new monad type.
Monad transformers solve this issue by providing a way to compose monad behaviours, to create complex ones.
Monad transformers extend a monad's behaviour by adding on top the one related to the transformer's monad.
For example we can apply the ```StateT``` transformer (```State``` monad transformer) to a ```IO``` monad, to obtain a computation that wraps a state but also have I/O side effects.

[Monad transformers](http://book.realworldhaskell.org/read/monad-transformers.html)

#### Lifting
Lifting is a concept that help generalize a function to work with monads, or in other settings.
```haskell
plus :: [Int] -> [Int] -> [Int]
plus = liftM2 (+)
-- plus [1,2,3] [3,6,9] ---> [4,7,10, 5,8,11, 6,9,12]
```
For example ```liftM2 (+)``` maps the ```+``` function to a new one, able to work with monads that are instances of ```Liftable```.
Lists represent non deterministic computations, and thus the lift of ```+``` is a function that return the list of all possible sums of the 2 lists.

The ```lift``` concept comes handy also in the case of monad transformers.
In fact, in addition to map pure functions to work with monads, ```lift``` can also map function between inner monads to work with the transformed (outer) monad.
For example ```liftIO``` map a function that returns an ```IO``` monad to return an IO monad encapsulated in other monad transformers.

[Haskell lift](https://wiki.haskell.org/Lifting)

## Comparison

Since Tubes is inspired by Pipes, many base types and functions of the library have a corresponding on in the other library.

| *Pipes*  	| *Tubes*                                            	|
|----------	|----------------------------------------------------	|
| ```Proxy```    	| ```Tube``` 	|
| ```Producer``` 	| ```Source```                                             	|
| ```Pipe```     	| ```Channel```                                            	|
| ```Consumer``` 	| ```Sink```                                               	|
| ```Effect```   	| ```Tube () () m r```                                     	|

Note that unlike ```Proxy```, ```Tube``` is mono-directional.

The communication between Proxy / Tube use the very same primitives ```yield``` and ```await``` with the same semantic.

Both the libraries reimplement the basic operations on lists (```map```, ```filter```, ...) containted in ```Prelude``` in terms of ```Proxy``` / ```Tube```. Pipes define these functions in ```Pipes.Prelude```, Tubes inside ```Tubes.Util```.

In order to show the similarities in the concepts and the small differences in these two libraries, we implemented a Map-Reduce flavoured batch word count using both of them, taking advantage of the stream programming paradigm offered which allowed us to adopt a dataflow approach to the problem, pipelining the steps of the computation.

Notice that:
- Both the programs read a textual test file, pass that to a Produce / Source that read chucks of data, get the words, map the words to lowercase, then reduce the outputs of the pipeline incrementing the value of a map corresponding to that word.

- Both the programs use the ```map``` and the ```fold```/```reduce``` utils, that has a similar syntax and semantic with respect to the Prelude version.

- The composition follows a similar linear structure: ```... >-> ... >-> ...``` (Pipes) vs ```... >< ... >< ...``` (Tubes).

#### Pipes
```haskell
import qualified Pipes.Prelude as P
import Data.List.Split
import Pipes
import Control.Monad (forever)
import Data.HashMap.Strict
import Data.Char (isAlphaNum)
import Data.Text (pack, unpack, toLower)
import System.IO
--
-- wordcount mapReduce-style, only benefit is to reduce memory consumption
--

main :: IO ()
main =  withFile "test-text.txt" ReadMode $
    \file -> runEffect (P.fold (\x a -> insertWith (+) a 1 x)      -- insert into the state map, adding one each time
                        empty  -- the empty map
                        (show . toList)   -- at the end it produces a String
                        (P.fromHandle file >->
                            P.map (splitOn " ") >->  -- splits the strings received and     produces a list of the words                           
                            forever (await >>= each) >->     -- each unpacks the elements of the list received by awaiting
                            P.map (filter isAlphaNum) >->     -- strip all non alphanumeric characters
                            P.map (unpack . toLower . pack)   -- use toLower from Text to convert a string to lowercase
                            )
                        )
        >>= putStrLn

```

#### Tubes
```haskell
import Prelude hiding (map, filter, reduce)
import qualified Prelude as P
import Control.Monad (unless, liftM)
import Control.Monad.IO.Class (liftIO, MonadIO)
import Tubes
import System.IO
import Data.Char (toLower, isAlphaNum)
import qualified Data.HashMap.Strict as Map
--
-- wordcount mapReduce-style, only benefit is to reduce memory consumption
--

-- read a word from a file handle,
-- a word is a non-empty sequence of alphanumeric characters.
hGetWord :: Handle -> IO String
hGetWord handle = go [] where
    go :: String -> IO String
    go word = do
        eof <- hIsEOF $ handle
        if not eof then do
            c <- hGetChar handle
            if not $ isAlphaNum c then do -- any not alphanum is separator
                if not (null word) then do
                    return word
                else go word
            else do
                let word' = word ++ [c]
                go word'
        else do
            return word

-- a Source that continuosly yields words  read from a file handle.
wordsFromFile :: MonadIO m => Handle -> Source m String
wordsFromFile handle = Source $ do
    eof <- liftIO $ hIsEOF handle                                 
    unless eof $ do   
        w <- liftIO $ hGetWord handle
        yield w
        sample $ wordsFromFile handle

-- Open a test file and print to console a map (word : count).
main :: IO ()
main = do
    handle <- openFile "test-text.txt" ReadMode
    let words = (sample $ wordsFromFile handle) >< (map $ liftM toLower) -- read words and convert to lowercase
    wcount <- reduce countWords Map.empty words
    print $ show wcount
    where
        countWords m word = Map.insertWith (+) word 1 m -- increment the map value for the corresponding word, or initialize word ounter to 1
```

## Windowed Wordcount with Pipes
**How to run the code is explained [here](code/HOW_TO_RUN.md)**

We'll here describe the various attempt we made to try to create a simple timed "_wordcount_" example as the one that can be found on the examples of many stream processing engine (such as [Flink](https://ci.apache.org/projects/flink/flink-docs-release-1.4/quickstart/setup_quickstart.html)), given a tumbling window of 5 seconds and an input stream of lines of text, returns at every triggering of the window a map (word, count) where count is the number of times a certain word has been seen during the elapsed time and assuming the input data arriving in the correct order.

Firstly in the large ecosystem of libraries surrounding Pipes we found [pipes-concurrent](https://hackage.haskell.org/package/pipes-concurrency-2.0.9/docs/Pipes-Concurrent.html#v:recv), which provides "_Asynchronous communication between pipes_" and makes possible the adoption of an actor model approach.
Therefore the [first attempt](code/Wordcount.hs) was to try to implement our wordcount using pipes-concurrent the result was quite promising at first, by passing manually strings to standard input everything seemed to work properly, but after a while we noticed that the concurrent  access to the shared mailbox used to communicate between the two pieces of the pipe in certain cases didn't behave as expected, resulting in the window never triggering if the input stream kept coming at a really high rate (e.g. "**yes | ./Wordcount**"), not respecting the chosen reporting policy.
In fact we was feeding into the mailbox a _Maybe Char_, so that a _Nothing_ could be sent by a timer running on a different thread and interpreted by the consumer downstream as a signal of the triggering of the window. We tried to adopt the approach of "[ The CQL continuous query language: semantic foundations and query execution](https://link.springer.com/article/10.1007%2Fs00778-004-0147-z)" by dividing the computation in s2r (stream to relation), r2r (relation to relation), r2s (relation to stream), forcing to start the execution of the part counting the words seen only after the window was triggered, accumulating all the input upstream and then passing them down. This approach due to the incremental nature of our task represented a huge performance overhead, for this reason in the following examples we looked for different approaches and opted for merging the s2r and r2r-_ish_ part into a single accumulator, that will be triggered by a timer and so yield downward its result at the desired time (obviously more or less the desired time, due to the fact, that no guarantees are given on the upper bound of the _thread delay_ ). This choice as said was due to the nature of this specific example, whereas in cases where the whole window has to  be known at the moment of the r2r operation it could surely still be applied. But the main issue remains how to trigger the window evaluation at the right time.

Therefore in the  [second attempt](code/wordcount_flink_v1.hs) we didn't use pipes-concurrent anymore, instead we tried a to use the standard [clock library](https://hackage.haskell.org/package/time-1.9.1/docs/Data-Time-Clock.html) from haskell, which obviously does not guarantees the exactness of the time returned by its **getCurrentTime** function, seen that it returns the system clock time, which can be modified by the user or adjusted by the system in any moment, but still, assuming an ideal situation, would be enough to prove what we are trying to show.
The result where good, it kept the pace of **yes**, but this time the low rate inputs were the problem. The triggering of the window was achieved by taking the time before receiving a new input and checking after having received it, if the desired time from the last triggering had passed. Clearly this approach brought to the thread indefinitely waiting for a new input and never be able to yield downward even if the window should have been triggered. This problem arose because we were checking the time at each new tuple and we were not able to trigger it from the outside, but we were still able to use the component as a Pipe and connect it to following Proxies.

These considerations brought to the [third version](code/wordcount_flink_v2.hs), in which thanks to the use of [MVars](https://hackage.haskell.org/package/base-4.10.1.0/docs/Control-Concurrent-MVar.html) we separated the timer from the counter in two different threads, so that every time the timer is triggered, the timer prints the map contained in the shared MVar and resets it. Being the main thread the one awaiting for inputs and the timer's secondary thread not a Pipe, we didn't manage to yield downstream the result of the counting allowing it to be used for further computation, breaking this way the composability at the core of the library. Has to be said that in the same way as we did, the function _fold_ in the Prelude of Pipes does not produce a Pipe and cannot be further composed, so it seems to be accepted this sort of behavior, even if it doesn't fit well in the framework of the usual stream processing definition.

## Conclusions

In the end, with respect to the initial question we where trying to investigate, so whether or not the stream programming paradigm of the two libraries we have taken in consideration could easily be adapted to perform stream computing tasks, given their current implementations, the answer we can give is "not so easily". The semantic of stream processing as in the aforementioned distributed frameworks is hard to implement in these libraries and often a question of tradeoffs one is willing to accept. Hint of this difficulty is the great complexity of such systems that obviously surpass the complexity of a simple library as the ones we've taken in consideration. For sure the programming paradigm this kind of libraries offer is quite similar to the ones offered by the API of the various stream engine or big data framework nowadays, but the underlying architecture of these two libraries has been thought much more for batch jobs than for streaming ones and so the concept of time is completely missing and difficult to plug in, the main focus is on memory usage and single thread performance and not concurrency, even when specific libraries built on top of these exists as for pipes.
