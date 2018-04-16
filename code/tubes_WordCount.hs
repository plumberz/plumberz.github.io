import Prelude hiding (map, filter, reduce)
import qualified Prelude as P

import Data.Semigroup
import Control.Monad (unless)

import Tubes
import Control.Monad.IO.Class (MonadIO, liftIO)
import System.IO

import Data.Char (toLower, isSpace, isAlphaNum)
import qualified Data.HashMap.Strict as Map

charsFromFile :: MonadIO m => Handle -> Source m Char
charsFromFile handle = Source $ do
    eof <- liftIO . hIsEOF $ handle
    unless eof $ do
        c <- liftIO $ hGetChar handle
        yield c
        sample $ charsFromFile handle


split_words :: Monad m => Char -> Channel m Char String 
split_words separator = Channel $ go [] where
    go w_acc = do
        c <- await
        if c == separator then do
            unless (null w_acc) $ yield (reverse w_acc)
            go []
        else do
            let w_acc' = c : w_acc
            go w_acc'

validChar :: Char -> Bool
validChar c = (c==' ') || (isAlphaNum c)

word2KV w = (w,1)

tube handle = sample (charsFromFile handle)
    >< map toLower
    >< filter validChar 
    >< tune (split_words ' ')
    >< map word2KV  

main :: IO ()
main = do
    handle <- openFile "test-text.txt" ReadMode
    let t = tube handle
    wc <- reduce (\ m (k,v) -> Map.insertWith (+) k v m) Map.empty t
    print $ show wc
