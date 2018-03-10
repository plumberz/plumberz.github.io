import qualified Pipes.Prelude as P
import System.IO
import Control.Concurrent (threadDelay, takeMVar, putMVar, newMVar)
import Control.Concurrent.Async
import Pipes
import Data.HashMap.Strict
import Data.List.Split
import Wordcount (r2s)
-- Asynchronous version that does not output if the main thread has ended
-- By unifying the windowing and the counting we achieve a considerable performance boost,

main :: IO ()
main = runEffect $ P.stdinLn >-> P.map (splitOn " ") >-> r2s >-> timedWindow 5000000

timedWindow t = do
        v <- lift $ newMVar empty
        lift $ async $ timer' t v empty
        wordcount' empty v

timer' w v e = do
    threadDelay w
    c <- takeMVar v
    print $ toList c
    putMVar v e 
    timer' w v e

wordcount' e v = do
    x <- await
    s' <- lift $ takeMVar v
    lift $ putMVar v $ insertWith (+) x 1 s'
    wordcount' e v
