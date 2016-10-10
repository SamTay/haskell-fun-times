import System.Environment
import System.Directory
import System.IO
import Data.List

type Command = [String] -> IO ()

main = do
  (command:args) <- getArgs
  let (Just action) = lookup command dispatch
  action args


dispatch :: [(String, Command)]
dispatch = [("add", add)
           ,("view", view)
           ,("remove", remove)
           ]

add :: Command
add [filename, todoItem] = appendFile filename (todoItem ++ "\n")

view :: Command
view [filename] = do
  contents <- readFile filename
  putStrLn $ unlines $ zipWith (\n line -> show n ++ ": " ++ line) [1..] (lines contents)

remove :: Command
remove [filename, x] = do
  contents <- readFile filename
  let todoItems = lines contents
      index     = (read x :: Int) + 1

  (tempName, tempHandle) <- openTempFile "." "temp"
  hPutStr tempHandle $ unlines $ delete (todoItems !! index) todoItems
  hClose tempHandle
  removeFile filename
  renameFile tempName filename
