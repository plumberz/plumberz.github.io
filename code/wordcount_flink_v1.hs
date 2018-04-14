import qualified Pipes.Prelude as P
import System.IO
import Data.Time.Clock
import Control.Concurrent (forkOS, threadDelay, takeMVar, putMVar, newMVar)
import Control.Concurrent.Async
import Pipes
import Pipes.Concurrent
import Data.HashMap.Strict
import Data.List.Split
import Wordcount

-- synchronous version, no output if no input after window passed
--
-- splitting windowing and counting in 2 steps brings to a major decrease in performance
-- the major problem is the synchronous execution of the windowing part and the wordcount part

main = do
    hSetBuffering stdout NoBuffering
    runEffect $ P.stdinLn >-> 
                    P.map (splitOn " ") >-> 
                    r2s >->
                    windowCount 5 >-> 
                    r2s >-> P.map show >-> P.stdoutLn


windowCount w = do 
    t0 <- lift getCurrentTime
    loop (realToFrac w) t0 empty where 
        loop w last s = do
            x <- lift getCurrentTime
            el <- await
            let diff = diffUTCTime x last
            if diff <= w
                then loop w last $! insertWith (+) el 1 s
                else do
                    yield $ toList s
                    loop w x empty
