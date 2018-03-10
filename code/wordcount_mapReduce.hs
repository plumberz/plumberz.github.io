import qualified Pipes.Prelude as P
import Data.List.Split
import Pipes
import Control.Monad (forever)
import Data.HashMap.Strict
--
-- wordcount mapReduce-style, only benefit is to reduce memory consumption
--

main :: IO ()
main = runEffect (P.fold (\x a -> insertWith (+) a 1 x) 
                        empty 
                        (show . toList) 
                        (P.stdinLn >-> 
                            P.map (splitOn " ") >-> 
                            forever (await >>= each)
                            )
                        ) 
        >>= putStrLn
