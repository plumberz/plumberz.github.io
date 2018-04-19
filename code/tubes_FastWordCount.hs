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
