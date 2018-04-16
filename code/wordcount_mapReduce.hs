import qualified Pipes.Prelude as P
import Data.List.Split
import Pipes
import Control.Monad (forever)
import Data.HashMap.Strict
import Data.Text (pack, unpack, toLower)
import System.IO
--
-- wordcount mapReduce-style, only benefit is to reduce memory consumption
--

main :: IO ()
main =  withFile "test-text.txt" ReadMode $ \file -> runEffect (P.fold (\x a -> insertWith (+) a 1 x) 
                        empty 
                        (show . toList) 
                        (P.fromHandle file >-> 
                            P.map (splitOn " ") >-> 
                            forever (await >>= each) >->
                            P.map (unpack . toLower . pack)
                            )
                        )
        >>= putStrLn
