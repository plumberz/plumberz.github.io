module Wordcount (
    s2r,
    r2s,
    wordcount,
    timer) where
import qualified Pipes.Prelude as P
import System.IO
import Control.Concurrent (forkOS, threadDelay, takeMVar, putMVar, newMVar)
import System.Timeout
import Control.Monad (forever)
import Control.Concurrent.Async
import Pipes
import Pipes.Concurrent
import Data.Time.Clock
import Data.HashMap.Strict
import Data.List.Split

-- asynchronous version of wordcount, but relies on the fact that the timer allows to 

s2r e = loop e where
            loop s' = do
                tic <- await
                case tic of
                    Nothing -> do
                        yield s'
                        loop e
                    Just x -> loop $! mappend s' $ return x

wordcount = forever $ await >>= (yield . toList . fromListWith (+))

r2s = forever $ await >>= each

timer :: Int -> Proxy x' x () (Maybe a) IO ()
timer t = do
    lift $ threadDelay t
    yield Nothing 


main :: IO ()
main = do
    (output, input) <- spawn unbounded
    t1 <- async $ do
                runEffect $ P.stdinLn >->
                            P.map (splitOn " ") >-> 
                            r2s >-> 
                            P.map (\x -> (x,1)) >->
                            P.map Just >->
                            toOutput output
                performGC
    t2 <- async $ do 
                runEffect $ forever (timer 5000000) >-> toOutput output
                performGC
    runEffect $ fromInput input >-> 
                        s2r [] >-> 
                        wordcount >-> 
                        r2s >->
                        P.map show >-> P.stdoutLn

