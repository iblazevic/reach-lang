module Reach.EmbeddedFiles where

import Data.ByteString (ByteString)
import Data.FileEmbed

z3_runtime_smt2 :: ByteString
z3_runtime_smt2 = $(embedFile "./z3/z3-runtime.smt2")

stdlib_sol :: ByteString
stdlib_sol = $(embedFile "./sol/stdlib.sol")

stdlib_rsh :: ByteString
stdlib_rsh = $(embedFile "./rsh/stdlib.rsh")