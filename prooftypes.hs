-- Define proof data types, and helper methods

module ProofTypes where
import Prelude
import List

data Expr a = Expr {_id :: String, body :: Stmt a, justification :: (Maybe [String], Maybe [String])}
  deriving (Eq)
data Stmt a = Op a (Stmt a) (Stmt a) | Var a | Free a
  deriving (Eq)
data Rule a = Rule {condition :: Stmt a, conclusion :: Stmt a}
  deriving (Show, Eq)
data Ruleset a =  Ruleset {name :: String, set :: [Rule a]}
  deriving (Show, Eq)

-- Get the name of a statement leaf
val :: Stmt String -> String
val stmt =
  case stmt of
    Var a -> a
    Free a -> a
    otherwise -> "STATEMENT" -- should not happen
    
-- Get statement depth
depth :: Stmt a -> Int
depth stmt =
  case stmt of
    Var a -> 0
    Free a -> 0
    Op op a b -> 1 + max (depth a) (depth b)

--Get assumptions assosiated with statement
deps :: Expr String -> [String]
deps expr =
  case justification expr of
    (_, Just a) -> List.nub $ filter (\a -> a /= "_") (a++[_id expr])
    (_, Nothing) -> [_id expr]

rule_deps :: Expr String -> [String]
rule_deps expr =
  case justification expr of
    (Just a, _) -> a
    (Nothing,_) -> []

--Merge two lists of statement assumptions
merge_deps :: [String] -> [String] -> [String]
merge_deps one two = List.nub $ one ++ two 

pairwise_combine :: [Expr String] -> [Expr String]
pairwise_combine facts =
  facts ++ [Expr "_" (Op "," (body x) (body y)) (Just ((rule_deps x)++(rule_deps y)), Just (merge_deps (deps x) (deps y))) | x <- facts, y <- facts]

show_stmt :: Stmt String -> String
show_stmt stmt = 
  case stmt of
    (Op o a (Var "NOP")) -> o++(show_stmt a)
    (Op o a b) -> (show_stmt a) ++ o ++ (show_stmt b)
    (Var a) -> a
    (Free a) -> a
    
show_expr :: Expr String -> String
show_expr expr =
  filter (\c -> c /= '\"') $ (show_stmt $ body expr)++" by rule(s) "++
    (show (rule_deps expr))++" and assumption(s) "++(show (deps expr))

--Helpers for displaying rules
instance (Show s) => Show (Expr s) where
  show expr = (show (_id expr)) ++ " : " ++ (show (body expr)) ++ " | " ++ (show (justification expr)) ++ "\n"

instance (Show s) => Show (Stmt s) where
  show stmt =
    case stmt of
      (Op op a b) -> "(" ++ (show a) ++" "++(show op) ++" "++(show b) ++ ")"
      (Var a) -> (show a)
      (Free a) -> "_"++(show a)