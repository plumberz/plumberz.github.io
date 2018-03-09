Introduction
============

Pipes *“is a clean and powerful stream processing library that lets you build and connect reusable streaming components”*. Its main focus is clearly to offer the simplest building blocks possible, that can then be used to build more sophisticated streaming abstractions, as can be seen in the rich ecosystem of libraries surrounding pipes.

Types
=====

Proxy
-----

The main component of the library is the monad transformer Proxy. A monad transformer is a type constructor which takes a monad as an argument and returns a monad. Through *lifting* one is able to utilize functions defined in the base monad also in the obtained monad.

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

A ’Proxy’ receives and sends information both upstream and downstream:

-   *upstream interface*: receives *a* and send *a’*

-   *downstream interface*: send *b* and receives *b’*

-   *m*: the base monad

-   *r*: the return value

Concrete type synonyms
----------------------

Pipes offers many concrete type synonyms for ’Proxy’ specializing further its more generic signature. Defined X the empty type, used to close output ends.

### 

<span>Effect</span>

    -- Defined in ‘Pipes.Core’
    type Effect = Proxy X () () X :: (* -> *) -> * -> * 

Which represents an effect in the base monad, modeling a non-streaming component, and can be *run*, converting it back to the base monad through:

    runEffect :: Monad m => Effect m r -> m r 

### 

<span>Producer</span>

    type Producer b = Proxy X () () b :: (* -> *) -> * -> *

Representing a Proxy producing *b* downstream, models a streaming source.

### 

<span>Consumer</span>

    type Consumer a = Proxy () a () X :: (* -> *) -> * -> *

Representing a Proxy consuming *a* from upstream, models a streaming sink.

### 

<span>Pipe</span>

    type Pipe a b = Proxy () a () b :: (* -> *) -> * -> *

Representing a Proxy consuming *a* from upstream and producing *b* downstream, models a stream transformation.

Polymorphic synonyms
--------------------

For each of these types synonyms, except for Pipe, also a *polymorphic version* is defined, using the *Rank-N types* GHC extension:

    type Effect' (m :: * -> *) r = forall x' x y' y. Proxy x' x y' y m r
    type Producer' b (m :: * -> *) r = forall x' x. Proxy x' x () b m r
    type Consumer' a (m :: * -> *) r = forall y' y. Proxy () a y' y m r

which gives more freedom to some parameters (i.e. this way Pipe can both be seen as Producer’ and Consumer’ which allows to write more easily some of the following signatures)

Communication
-------------

To enforce loose coupling, components can only communicate using two functions:

    -- Defined in ‘Pipes’
    yield :: Monad m => a -> Producer' a m () 
    await :: Monad m => Consumer' a m a

*yield* is used to send output data, *await* to receive inputs. Producers can only yield, Consumers only await, Pipes can do both and Effects neither yield nor await.

Composition
-----------

Connection between components can be performed in different ways.

    for :: Monad m => Proxy x' x b' b m a' -> (b -> Proxy x' x c' c m b') 
                     -> Proxy x' x c' c m a'              

A possible specialization of its signature can be:

    for :: Monad m => Producer a m r -> (a -> Effect m ()) -> Effect m r

which explains better an example like (*for producer body*), where we loop over *producer* replacing each *yield* in it with *body*, which is a function from the output of the producer to an Effect. The point-free counterpart to *for* is (∼&gt;) (pronounced *into*) such that:

    (f ~> g) x = for (f x) g  

Similarly we have “feed”, that fills all the awaits this time with a given source.

    ($>~) :: Monad m => Proxy a' a y' y m b -> Proxy () b y' y m c 
                   -> Proxy a' a y' y m c

e.g. (draw >∼ p): loops over *p* replacing each *await* with *draw*.

    (>->) :: Monad m => Proxy a' a () b m r -> Proxy () b c' c m r 
                     -> Proxy a' a c' c m r

Which can be used to compose Pipes, similarly to the Unix pipe operator. Next we’ll see a basic example composed by mixing various examples in the pipes’ tutorial , a simple main that gets strings from standard input, maps them to lower case and then prints them to standard output, showing the implementations of some parts of Pipes.Prelude.

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

When all the *awaits* and *yield* have been handled, the resulting Proxy can be run, removing the lifts and returning the underlying base monad.

    main :: IO ()
    main = runEffect $ stdinLn >-> 
                    map' (unpack . toLower . pack) >->  -- pack :: String -> Text,
                                                  -- unpack :: Text -> String viceversa
                    stdoutLn

Applying a monad transformer to a monad returns a monad, as we already said, so obviously results can be composed using the usual *bind* operator &gt; &gt; =.
