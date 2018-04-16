import Prelude hiding (map, filter, reduce)
import qualified Prelude as P
import Control.Monad (unless, liftM)
import Control.Monad.IO.Class (liftIO, MonadIO)
import Tubes
import System.IO
import Data.Char (toLower, isAlphaNum)
import qualified Data.HashMap.Strict as Map

hGetWord :: Handle -> IO String
hGetWord handle = go [] where
    go :: String -> IO String
    go word = do
        eof <- hIsEOF $ handle
        if not eof then do
            c <- (liftM toLower) $ hGetChar handle
            if not $ isAlphaNum c then do -- any not alphanum is separator
                if not (null word) then do
                    return word
                else go word
            else do
                let word' = word ++ [c]
                go word'
        else do
            return word

wordsFromFile :: MonadIO m => Handle -> Source m String
wordsFromFile handle = Source $ do
    eof <- liftIO $ hIsEOF handle                                 
    unless eof $ do   
        w <- liftIO $ hGetWord handle 
        yield w
        sample $ wordsFromFile handle

main :: IO ()
main = do
    handle <- openFile "test-text.txt" ReadMode
    let words = sample $ wordsFromFile handle
    wcount <- reduce countWords Map.empty words
    print $ show wcount 
    where
        countWords m word = Map.insertWith (+) word 1 m -- increment the map value for the corresponding word, or initialize word ounter to 1 
