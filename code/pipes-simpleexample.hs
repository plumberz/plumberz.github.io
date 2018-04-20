import Pipes
import qualified Pipes.Prelude as P
import System.IO
import Data.Text (pack, unpack, toLower)
import Control.Monad (forever, unless)
import Control.Exception (try, throwIO)
import qualified GHC.IO.Exception as G

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

main = runEffect $ stdinLn >-> map' (unpack . toLower . pack) >-> stdoutLn
