module Main where
import Control.Monad (msum)
import Happstack.Server
import Text.ParserCombinators.Parsec
import Text.ParserCombinators.Parsec.Expr
import List
import System.Timeout as S
import ProofParse
import ProofTypes
import ProofSearch

main :: IO ()
main = simpleHTTP nullConf $ app

app :: ServerPart Response
app = do 
  decodeBody (defaultBodyPolicy "/tmp/" (10*10^6) 1000 1000) 
  msum [   dir "checkproof" $ process ]
           
process :: ServerPart Response
process = do 
  methodM POST
  rs <- look "rulesets"
  as <- look "assumptions"
  reqs <- look "reqs"
  p <- look "proof"
  let rs_parsed = parse rulesets "" rs
  let as_parsed = parse assumptions "" as
  case (rs_parsed, as_parsed) of 
    (Right r, Right a) ->
      let pres = parse proof "" p in
      case pres of
        Right pstmts ->
          let res = do_proof r a pstmts "" in
          ok $ toResponse res
        Left e -> ok $ toResponse (show e)
    _ -> ok $ toResponse "bad parse in assumptions/rulesets" --problem parsing

do_proof :: [Ruleset String] -> [Expr String] -> [ProofStmt] -> String -> String
do_proof _ _ [] msg = msg
do_proof rs as (p:ps) msg =
  let try_prove = checkproof 4 (stmt p) rs as in
  case try_prove of
    Just x ->
      case verify_rules_assumptions x (r_deps p) (a_deps p) of
        True -> do_proof rs as ps $ msg ++ "Proved "++(nm p)++"\n"
        False -> msg ++ "Attempt to prove statement "++(nm p)++" with "++(show (r_deps p))++"... failed.\n"
    _ -> msg ++ "Attempt to prove statement "++(nm p)++"... failed.\n"

verify_rules_assumptions :: [Expr String] -> [String] -> [String] -> Bool
verify_rules_assumptions exprs [] [] = True
verify_rules_assumptions exprs r_d [] = match_d rule_deps exprs r_d
verify_rules_assumptions exprs [] a_d = match_d deps exprs a_d
verify_rules_assumptions exprs r_d a_d = (match_d deps exprs a_d) && (match_d rule_deps exprs r_d)

match_d :: (Expr String -> [String]) -> [Expr String] -> [String] -> Bool
match_d f [] m = False
match_d f (x:xs) m = 
  let rules = sort $ filter (\x -> x /= "Free" && x /= "_") (f x) in
  let ms = filter (\f-> f /= "") $ sort m in
  if ms == rules then True else match_d f xs m

f_search :: Int -> Stmt String -> [Expr String] -> [Ruleset String] -> [Expr String] -> Maybe [Expr String]
f_search 0 _ _ _ stmts = Nothing
f_search depth start toprove rulesets stmts = 
  let update = stmts ++ apply_rulesets_stmts stmts rulesets in
  let res = [Expr "_" start (Just ((rule_deps x)++(rule_deps y)), Just (merge_deps (deps x) (deps y))) | (x,y) <- (contains toprove update)] in
  case res of 
    (x:rst) -> Just res
    _ -> f_search (depth - 1) start toprove rulesets $ List.nub update

checkproof :: Int -> Stmt String -> [Ruleset String] -> [Expr String] -> (Maybe [Expr String])
checkproof depth stmt rulesets assumps =
  let equiv = backward_search 1 (Expr "_" stmt (Nothing,Nothing)) assumps rulesets in -- find things equivalent to the goal
  f_search depth stmt equiv rulesets assumps