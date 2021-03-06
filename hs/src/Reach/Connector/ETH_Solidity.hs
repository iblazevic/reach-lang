module Reach.Connector.ETH_Solidity (connect_eth) where

import Control.Monad
import Control.Monad.ST
import Data.Aeson
import Data.Aeson.Encode.Pretty
import qualified Data.ByteString.Char8 as B
import qualified Data.ByteString.Lazy.Char8 as LB
import qualified Data.HashMap.Strict as HM
import Data.List (find, foldl', intersperse)
import qualified Data.Map.Strict as M
import Data.STRef
import qualified Data.Set as S
import qualified Data.Text as T
import Data.Text.Prettyprint.Doc
import Reach.AST
import Reach.CollectTypes
import Reach.Connector
import Reach.EmbeddedFiles
import Reach.STCounter
import Reach.Type
import Reach.Util
import Reach.Version
import System.Exit
import System.FilePath
import System.IO.Temp
import System.Process

--- Pretty helpers

vsep_with_blank :: [Doc a] -> Doc a
vsep_with_blank l = vsep $ intersperse emptyDoc l

--- Solidity helpers

solNum :: Show n => n -> Doc a
solNum i = pretty $ "uint256(" ++ show i ++ ")"

solBraces :: Doc a -> Doc a
solBraces body = braces (nest 2 $ hardline <> body <> space)

data SolFunctionLike a
  = SFL_Constructor
  | SFL_Function Bool (Doc a)
solFunctionLike :: SolFunctionLike a -> [Doc a] -> Doc a -> Doc a -> Doc a
solFunctionLike sfl args ret body =
  sflp <+> ret' <+> solBraces body
  where
    ret' = ext' <> ret
    (ext', sflp) =
      case sfl of
        SFL_Constructor ->
          (emptyDoc, solApply "constructor" args)
        SFL_Function ext name ->
          (ext'', "function" <+> solApply name args)
          where ext'' = if ext then "external " else " "

solFunction :: Doc a -> [Doc a] -> Doc a -> Doc a -> Doc a
solFunction name =
  solFunctionLike (SFL_Function False name)

solContract :: String -> Doc a -> Doc a
solContract s body = "contract" <+> pretty s <+> solBraces body

solVersion :: Doc a
solVersion = "pragma solidity ^0.7.0;"

solStdLib :: Doc a
solStdLib = pretty $ B.unpack stdlib_sol

solApply :: Doc a -> [Doc a] -> Doc a
solApply f args = f <> parens (hcat $ intersperse (comma <> space) args)

solRequire :: Doc a -> Doc a
solRequire a = solApply "require" [a]

solBinOp :: String -> Doc a -> Doc a -> Doc a
solBinOp o l r = l <+> pretty o <+> r

solEq :: Doc a -> Doc a -> Doc a
solEq = solBinOp "=="

solAnd :: Doc a -> Doc a -> Doc a
solAnd = solBinOp "&&"

solBytesLength :: Doc a -> Doc a
solBytesLength x = "bytes(" <> x <> ").length"

solSet :: Doc a -> Doc a -> Doc a
solSet x y = solBinOp "=" x y <> semi

solIf :: Doc a -> Doc a -> Doc a -> Doc a
solIf c t f = "if" <+> parens c <+> solBraces t <> hardline <> "else" <+> solBraces f

solDecl :: Doc a -> Doc a -> Doc a
solDecl n ty = ty <+> n

solStruct :: Doc a -> [(Doc a, Doc a)] -> Doc a
solStruct name fields = "struct" <+> name <+> solBraces (vsep $ map (<> semi) $ map (uncurry solDecl) fields)

--- Runtime helpers

solMsg_evt :: Pretty i => i -> Doc a
solMsg_evt i = "e" <> pretty i

solMsg_arg :: Pretty i => i -> Doc a
solMsg_arg i = "a" <> pretty i

solMsg_fun :: Pretty i => i -> Doc a
solMsg_fun i = "m" <> pretty i

solLoop_fun :: Pretty i => i -> Doc a
solLoop_fun i = "l" <> pretty i

solLastBlockDef :: Doc a
solLastBlockDef = "_last"

solLastBlock :: Doc a
solLastBlock = "_a." <> solLastBlockDef

solBlockNumber :: Doc a
solBlockNumber = "uint256(block.number)"

solHash :: [Doc a] -> Doc a
solHash a = solApply "uint256" [solApply "keccak256" [solApply "abi.encode" a]]

solArraySet :: Int -> Doc a
solArraySet i = "array_set" <> pretty i

--- Compiler

type VarMap a = M.Map DLVar (Doc a)

data SolCtxt a = SolCtxt
  { ctxt_handler_num :: Int
  , ctxt_varm :: VarMap a
  , ctxt_emit :: Doc a
  , ctxt_typei :: M.Map SLType Int
  , ctxt_typem :: M.Map SLType (Doc a)
  , ctxt_deployMode :: DeployMode
  }

instance Semigroup (SolCtxt a) where
  --- FIXME maybe merge the maps?
  _ <> x = x

solRawVar :: DLVar -> Doc a
solRawVar (DLVar _ _ _ n) = pretty $ "v" ++ show n

solMemVar :: DLVar -> Doc a
solMemVar dv = "_f." <> solRawVar dv

solArgVar :: DLVar -> Doc a
solArgVar dv = "_a." <> solRawVar dv

solVar :: SolCtxt a -> DLVar -> Doc a
solVar ctxt v =
  case M.lookup v (ctxt_varm ctxt) of
    Just x -> x
    Nothing -> impossible $ "unbound var " ++ show v

solType :: SolCtxt a -> SLType -> Doc a
solType ctxt t =
  case M.lookup t $ ctxt_typem ctxt of
    Nothing -> impossible "cannot map sol type"
    Just x -> x

solTypeI :: SolCtxt a -> SLType -> Int
solTypeI ctxt t =
  case M.lookup t $ ctxt_typei ctxt of
    Nothing -> impossible "cannot map sol type"
    Just x -> x

mustBeMem :: SLType -> Bool
mustBeMem = \case
  T_Null -> False
  T_Bool -> False
  T_UInt256 -> False
  T_Bytes -> True
  T_Address -> False
  T_Fun {} -> impossible "fun"
  T_Array {} -> True
  T_Tuple {} -> True
  T_Obj {} -> True
  T_Forall {} -> impossible "forall"
  T_Var {} -> impossible "var"
  T_Type {} -> impossible "type"

data ArgMode
  = AM_Call
  | AM_Memory
  | AM_Event

solArgLoc :: ArgMode -> Doc a
solArgLoc = \case
  AM_Call -> " calldata"
  AM_Memory -> " memory"
  AM_Event -> ""

solArgType :: SolCtxt a -> ArgMode -> SLType -> Doc a
solArgType ctxt am t = solType ctxt t <> loc_spec
  where
    loc_spec = if mustBeMem t then solArgLoc am else ""

solArgDecl :: SolCtxt a -> ArgMode -> DLVar -> Doc a
solArgDecl ctxt am dv@(DLVar _ _ t _) = solDecl (solRawVar dv) (solArgType ctxt am t)

solCon :: DLConstant -> Doc a
solCon = \case
  DLC_Null -> "void"
  DLC_Bool True -> "true"
  DLC_Bool False -> "false"
  DLC_Int i -> solNum i
  DLC_Bytes s -> dquotes $ pretty $ B.unpack s

solArg :: SolCtxt a -> DLArg -> Doc a
solArg ctxt = \case
  DLA_Var v -> solVar ctxt v
  DLA_Con c -> solCon c
  DLA_Array _ as -> brackets $ hsep $ punctuate comma $ map (solArg ctxt) as
  da@(DLA_Tuple as) -> solApply (solType ctxt (argTypeOf da)) $ map (solArg ctxt) as
  da@(DLA_Obj m) -> solApply (solType ctxt (argTypeOf da)) $ map ((solArg ctxt) . snd) $ M.toAscList m
  DLA_Interact {} -> impossible "consensus interact"

solPrimApply :: PrimOp -> [Doc a] -> Doc a
solPrimApply = \case
  ADD -> binOp "+"
  SUB -> binOp "-"
  MUL -> binOp "*"
  DIV -> binOp "/"
  MOD -> binOp "%"
  PLT -> binOp "<"
  PLE -> binOp "<="
  PEQ -> binOp "=="
  PGE -> binOp ">="
  PGT -> binOp ">"
  LSH -> binOp "<<"
  RSH -> binOp ">>"
  BAND -> binOp "&"
  BIOR -> binOp "|"
  BXOR -> binOp "^"
  IF_THEN_ELSE -> \case
    [c, t, f] -> c <+> "?" <+> t <+> ":" <+> f
    _ -> impossible $ "emitSol: ITE wrong args"
  BYTES_EQ -> \case
    [x, y] ->
      solAnd
        (solEq (solBytesLength x) (solBytesLength y))
        (solEq (solHash [x]) (solHash [y]))
    _ -> impossible $ "emitSol: BYTES_EQ wrong args"
  BALANCE -> \_ -> "address(this).balance"
  TXN_VALUE -> \_ -> "msg.value"
  where
    binOp op = \case
      [l, r] -> solBinOp op l r
      _ -> impossible $ "emitSol: bin op args"

solExpr :: SolCtxt a -> Doc a -> DLExpr -> Doc a
solExpr ctxt sp = \case
  DLE_Arg _ a -> solArg ctxt a <> sp
  DLE_Impossible at msg -> expect_throw at msg
  DLE_PrimOp _ p args ->
    (solPrimApply p $ map (solArg ctxt) args) <> sp
  DLE_ArrayRef _ _ ae _ ie ->
    (solArg ctxt ae) <> brackets (solArg ctxt ie) <> sp
  DLE_ArraySet _ _ ae _ ie ve ->
    (solApply (solArraySet (solTypeI ctxt (argTypeOf ae))) $ map (solArg ctxt) [ae, ie, ve]) <> sp
  DLE_TupleRef _ ae i ->
    (solArg ctxt ae) <> ".elem" <> pretty i <> sp
  DLE_ObjectRef _ oe f ->
    (solArg ctxt oe) <> "." <> pretty f <> sp
  DLE_Interact {} -> impossible "consensus interact"
  DLE_Digest _ args ->
    (solHash $ map (solArg ctxt) args) <> sp
  DLE_Transfer _ _ who amt ->
    solTransfer ctxt who amt <> sp
  DLE_Claim _ _ ct a -> check <> sp
    where
      check = case ct of
        CT_Assert -> impossible "assert"
        CT_Assume -> require
        CT_Require -> require
        CT_Possible -> impossible "possible"
        CT_Unknowable {} -> impossible "unknowable"
      require = solRequire (solArg ctxt a)
  DLE_Wait {} -> emptyDoc
  DLE_PartSet _ _ a -> (solArg ctxt a) <> sp

solTransfer :: SolCtxt a -> DLArg -> DLArg -> Doc a
solTransfer ctxt who amt =
  (solArg ctxt who) <> "." <> solApply "transfer" [solArg ctxt amt]

solEvent :: SolCtxt a -> Int -> [DLVar] -> Doc a
solEvent ctxt which args =
  "event" <+> solApply (solMsg_evt which) (solDecl "_bal" (solType ctxt T_UInt256) : map (solArgDecl ctxt AM_Event) args) <> semi

solEventEmit :: SolCtxt a -> Int -> [DLVar] -> Doc a
solEventEmit ctxt which msg =
  "emit" <+> solApply (solMsg_evt which) (balancep : map (solVar ctxt) msg) <> semi
  where
    balancep = solPrimApply BALANCE []

data HashMode
  = HM_Set
  | HM_Check Int
  deriving (Eq, Show)

solHashState :: SolCtxt a -> HashMode -> [DLVar] -> Doc a
solHashState ctxt hm svs = solHash $ (solNum which_num) : which_last : (map (solVar ctxt) svs)
  where
    (which_last, which_num) =
      case hm of
        HM_Set -> (solBlockNumber, ctxt_handler_num ctxt)
        HM_Check prev -> (solLastBlock, prev)

solAsn :: SolCtxt a -> DLAssignment -> [Doc a]
solAsn ctxt (DLAssignment m) = map ((solArg ctxt) . snd) $ M.toAscList m

data SolTailRes a = SolTailRes (SolCtxt a) (Doc a)

instance Semigroup (SolTailRes a) where
  (SolTailRes ctxt_x xp) <> (SolTailRes ctxt_y yp) = SolTailRes (ctxt_x <> ctxt_y) (xp <> hardline <> yp)

solCom :: (SolCtxt a -> k -> SolTailRes a) -> SolCtxt a -> PLCommon k -> SolTailRes a
solCom iter ctxt = \case
  PL_Return _ -> SolTailRes ctxt emptyDoc
  PL_Let _ PL_Once dv de k -> iter ctxt' k
    where
      ctxt' = ctxt {ctxt_varm = M.insert dv de' $ ctxt_varm ctxt}
      de' = parens $ solExpr ctxt emptyDoc de
  PL_Let _ PL_Many dv de k -> SolTailRes ctxt dv_set <> iter ctxt k
    where
      dv_set = solSet (solMemVar dv) (solExpr ctxt emptyDoc de)
  PL_Eff _ de k -> SolTailRes ctxt dv_run <> iter ctxt k
    where dv_run = solExpr ctxt semi de
  PL_Var _ _ k -> iter ctxt k
  PL_Set _ dv da k -> SolTailRes ctxt dv_set <> iter ctxt k
    where
      dv_set = solSet (solMemVar dv) (solArg ctxt da)
  PL_LocalIf _ ca t f k -> SolTailRes ctxt (solIf ca' t' f') <> iter ctxt k
    where
      ca' = solArg ctxt ca
      SolTailRes _ t' = solPLTail ctxt t
      SolTailRes _ f' = solPLTail ctxt f

solPLTail :: SolCtxt a -> PLTail -> SolTailRes a
solPLTail ctxt (PLTail m) = solCom solPLTail ctxt m

solCTail :: SolCtxt a -> CTail -> SolTailRes a
solCTail ctxt = \case
  CT_Com m -> solCom solCTail ctxt m
  CT_Seqn _ p k -> ptr <> solCTail ctxt' k
    where
      ptr@(SolTailRes ctxt' _) = solPLTail ctxt p
  CT_If _ ca t f -> SolTailRes ctxt' $ solIf (solArg ctxt ca) t' f'
    where
      SolTailRes ctxt'_t t' = solCTail ctxt t
      SolTailRes ctxt'_f f' = solCTail ctxt f
      ctxt' = ctxt'_t <> ctxt'_f
  CT_Wait _ svs ->
    SolTailRes ctxt $
      vsep
        [ ctxt_emit ctxt
        , solSet ("current_state") (solHashState ctxt HM_Set svs)
        ]
  CT_Jump _ which svs asn ->
    SolTailRes ctxt $
      vsep
        [ ctxt_emit ctxt
        , solApply (solLoop_fun which) [solApply (solMsg_arg which) ((map (solVar ctxt) svs) ++ (solAsn ctxt asn))] <> semi
        ]
  CT_Halt _ ->
    SolTailRes ctxt $
      vsep
        [ ctxt_emit ctxt
        , solSet ("current_state") ("0x0")
        , solApply "selfdestruct" ["msg.sender"] <> semi
        ]

solFrame :: SolCtxt a -> Int -> S.Set DLVar -> (Doc a, Doc a)
solFrame ctxt i sim = if null fs then (emptyDoc, emptyDoc) else (frame_defp, frame_declp)
  where
    framei = pretty $ "_F" ++ show i
    frame_declp = (framei <+> "memory _f") <> semi
    frame_defp = solStruct framei fs
    fs = map mk_field $ S.elems sim
    mk_field dv@(DLVar _ _ t _) =
      ((solRawVar dv), (solType ctxt t))

manyVars_m :: (a -> S.Set DLVar) -> PLCommon a -> S.Set DLVar
manyVars_m iter = \case
  PL_Return {} -> mempty
  PL_Let _ lc dv _ k -> mdv <> iter k
    where
      mdv = case lc of
        PL_Once -> mempty
        PL_Many -> S.singleton dv
  PL_Eff _ _ k -> iter k
  PL_Var _ dv k -> S.insert dv $ iter k
  PL_Set _ _ _ k -> iter k
  PL_LocalIf _ _ t f k -> manyVars_p t <> manyVars_p f <> iter k

manyVars_p :: PLTail -> S.Set DLVar
manyVars_p (PLTail m) = manyVars_m manyVars_p m

manyVars_c :: CTail -> S.Set DLVar
manyVars_c = \case
  CT_Com m -> manyVars_m manyVars_c m
  CT_Seqn _ p c -> manyVars_p p <> manyVars_c c
  CT_If _ _ t f -> manyVars_c t <> manyVars_c f
  CT_Wait {} -> mempty
  CT_Jump {} -> mempty
  CT_Halt {} -> mempty

solCTail_top :: SolCtxt a -> Int -> [DLVar] -> Maybe [DLVar] -> CTail -> (SolCtxt a, Doc a, Doc a, Doc a)
solCTail_top ctxt which vs mmsg ct = (ctxt'', frameDefn, frameDecl, ct')
  where
    argsm = M.fromList $ map (\v -> (v, solArgVar v)) vs
    mvars = manyVars_c ct
    mvarsm = M.fromList $ map (\v -> (v, solMemVar v)) $ S.toList mvars
    (frameDefn, frameDecl) = solFrame ctxt' which mvars
    SolTailRes ctxt'' ct' = solCTail ctxt' ct
    emitp = case mmsg of
      Just msg ->
        solEventEmit ctxt'_pre which msg
      Nothing ->
        emptyDoc
    ctxt' = ctxt'_pre {ctxt_emit = emitp}
    ctxt'_pre =
      ctxt
        { ctxt_handler_num = which
        , ctxt_varm = mvarsm <> argsm <> (ctxt_varm ctxt)
        }

solArgDefn :: SolCtxt a -> Int -> ArgMode -> [DLVar] -> (Doc a, [Doc a])
solArgDefn ctxt which am vs = (argDefn, argDefs)
  where
    argDefs = [solDecl "_a" ((solMsg_arg which) <> solArgLoc am)]
    argDefn = solStruct (solMsg_arg which) ntys
    ntys = mgiven ++ v_ntys
    mgiven = case am of
      AM_Call -> [(solLastBlockDef, (solType ctxt T_UInt256))]
      _ -> []
    v_ntys = map go vs
    go dv@(DLVar _ _ t _) = ((solRawVar dv), (solType ctxt t))

solHandler :: SolCtxt a -> Int -> CHandler -> Doc a
solHandler ctxt_top which (C_Handler _at interval fs prev svs msg ct) =
  vsep [evtDefn, argDefn, frameDefn, funDefn]
  where
    vs = svs ++ msg
    ctxt_from = ctxt_top {ctxt_varm = fromm <> (ctxt_varm ctxt_top)}
    (ctxt, frameDefn, frameDecl, ctp) = solCTail_top ctxt_from which vs (Just msg) ct
    evtDefn = solEvent ctxt which msg
    (argDefn, argDefs) = solArgDefn ctxt which am vs
    ret = "payable"
    (hashCheck, am, sfl) =
      case (which, ctxt_deployMode ctxt_top) of
        (1, DM_firstMsg) ->
          (emptyDoc, AM_Memory, SFL_Constructor)
        _ ->
          (hcp, AM_Call, SFL_Function True (solMsg_fun which))
          where hcp = (solRequire $ solEq ("current_state") (solHashState ctxt (HM_Check prev) svs)) <> semi
    funDefn = solFunctionLike sfl argDefs ret body
    body =
      vsep
        [ hashCheck
        , frameDecl
        , fromCheck
        , timeoutCheck
        , ctp
        ]
    (fromm, fromCheck) =
      case fs of
        FS_Join from -> ((M.singleton from "msg.sender"), emptyDoc)
        FS_Again from -> (mempty, (solRequire $ solEq ("msg.sender") (solVar ctxt from)) <> semi)
    timeoutCheck = solRequire (solBinOp "&&" int_fromp int_top) <> semi
      where
        CBetween from to = interval
        int_fromp = check True from
        int_top = check False to
        check sign mv =
          case mv of
            [] -> "true"
            mvs -> solBinOp (if sign then ">=" else "<") solBlockNumber (foldl' (solBinOp "+") solLastBlock (map (solArg ctxt) mvs))
solHandler ctxt_top which (C_Loop _at svs msg ct) =
  vsep [argDefn, frameDefn, funDefn]
  where
    vs = svs ++ msg
    (ctxt_fin, frameDefn, frameDecl, ctp) = solCTail_top ctxt_top which vs Nothing ct
    (argDefn, argDefs) = solArgDefn ctxt_fin which AM_Memory vs
    ret = "internal"
    funDefn = solFunction (solLoop_fun which) argDefs ret body
    body = vsep [frameDecl, ctp]

solHandlers :: SolCtxt a -> CHandlers -> Doc a
solHandlers ctxt (CHandlers hs) = vsep_with_blank $ map (uncurry (solHandler ctxt)) $ M.toList hs

_solDefineType1 :: (SLType -> ST s (Doc a)) -> Int -> Doc a -> SLType -> ST s ((Doc a), (Doc a))
_solDefineType1 getTypeName i name = \case
  T_Null -> base
  T_Bool -> base
  T_UInt256 -> base
  T_Bytes -> base
  T_Address -> base
  T_Fun {} -> impossible "fun in ct"
  T_Forall {} -> impossible "forall in pl"
  T_Var {} -> impossible "var in pl"
  T_Array t sz -> do
    tn <- getTypeName t
    let me = tn <> brackets (pretty sz)
    let memem = me <> " memory"
    let args =
          [ solDecl "arr" memem
          , solDecl "idx" "uint256"
          , solDecl "val" tn
          ]
    let ret = "internal" <+> "returns" <+> parens (solDecl "arrp" memem)
    let ref arr idx = arr <> brackets (idx)
    let assign idx val = (ref "arrp" idx) <+> "=" <+> val <> semi
    let body =
          vsep
            [ ("for" <+> parens ("uint256 i = 0" <> semi <+> "i <" <+> (pretty sz) <> semi <+> "i++")
                 <> solBraces (assign "i" (ref "arr" "i")))
            , assign "idx" "val"
            ]
    let set_defn = solFunction (solArraySet i) args ret body
    return $ (me, set_defn)
  T_Tuple ats -> do
    atsn <- mapM getTypeName ats
    return $ (name, solStruct name $ (flip zip) atsn $ map (pretty . ("elem" ++) . show) ([0 ..] :: [Int]))
  T_Obj tm -> do
    tmn <- mapM getTypeName tm
    return $ (name, solStruct name $ map (\(k, v) -> (pretty k, v)) $ M.toAscList tmn)
  T_Type {} -> impossible "type in pl"
  where
    base = impossible "base"

_solDefineType :: STCounter s -> STRef s (M.Map SLType Int) -> STRef s (M.Map SLType (Maybe (Doc a, Doc a))) -> SLType -> ST s (Doc a)
_solDefineType tcr timr tmr t = do
  tm <- readSTRef tmr
  case M.lookup t tm of
    Just (Just x) -> return $ fst x
    Just Nothing -> impossible $ "recursive type: " ++ show t
    Nothing -> do
      tn <- incSTCounter tcr
      modifySTRef timr $ M.insert t tn
      modifySTRef tmr $ M.insert t $ Nothing
      let n = pretty $ "T" ++ show tn
      (tr, def) <- _solDefineType1 (_solDefineType tcr timr tmr) tn n t
      modifySTRef tmr $ M.insert t $ Just (tr, def)
      return $ tr

solDefineTypes :: S.Set SLType -> (M.Map SLType Int, M.Map SLType (Doc a), Doc a)
solDefineTypes ts = (tim, M.map fst tm, vsep $ map snd $ M.elems tm)
  where
    base_typem =
      M.fromList
        [ (T_Null, "void")
        , (T_Bool, "bool")
        , (T_UInt256, "uint256")
        , (T_Bytes, "bytes")
        , (T_Address, "address payable")
        ]
    base_tm = M.map (\t -> Just (t, emptyDoc)) base_typem
    tm = M.map (maybe (impossible "unfinished type") id) tmm
    (tim, tmm) = runST $ do
      tcr <- newSTCounter 0
      timr <- newSTRef mempty
      tmr <- newSTRef base_tm
      mapM_ (_solDefineType tcr timr tmr) $ S.toList ts
      liftM2 (,) (readSTRef timr) (readSTRef tmr)

solPLProg :: PLProg -> (ConnectorInfo, Doc a)
solPLProg (PLProg _ (PLOpts {..}) _ (CPProg at hs)) =
  (cinfo, vsep_with_blank $ [preamble, solVersion, solStdLib, ctcp])
  where
    ctcp =
      solContract "ReachContract is Stdlib" $
        ctcbody
    (typei, typem, typesp) = solDefineTypes $ cts hs
    ctxt =
      SolCtxt
        { ctxt_typem = typem
        , ctxt_typei = typei
        , ctxt_handler_num = 0
        , ctxt_emit = emptyDoc
        , ctxt_varm = mempty
        , ctxt_deployMode = plo_deployMode
        }
    ctcbody = vsep_with_blank $ [state_defn, consp, typesp, solHandlers ctxt hs]
    consp =
      case plo_deployMode of
        DM_constructor ->
          solFunctionLike SFL_Constructor [] "payable" consbody
          where
            SolTailRes _ consbody = solCTail ctxt (CT_Wait at [])
        DM_firstMsg ->
          emptyDoc
    cinfo = M.fromList [ ("deployMode", T.pack $ show plo_deployMode) ]
    state_defn = "uint256 current_state;"
    preamble =
      vsep
        [ "// Automatically generated with Reach" <+> (pretty versionStr)
        , "pragma experimental ABIEncoderV2" <> semi
        ]

data CompiledSolRec = CompiledSolRec
  { csrAbi :: T.Text
  , csrCode :: T.Text
  , csrOpcodes :: T.Text
  }

instance FromJSON CompiledSolRec where
  parseJSON = withObject "CompiledSolRec" $ \o -> do
    ctcs <- o .: "contracts"
    case find (":ReachContract" `T.isSuffixOf`) (HM.keys ctcs) of
      Just ctcKey -> do
        ctc <- ctcs .: ctcKey
        abit <- ctc .: "abi"
        codebodyt <- ctc .: "bin"
        opcodest <- ctc .: "opcodes"
        return
          CompiledSolRec
            { csrAbi = abit
            , csrCode = codebodyt
            , csrOpcodes = opcodest
            }
      Nothing ->
        fail "Expected contracts object to have a key with suffix ':ReachContract'"

extract :: ConnectorInfo -> Value -> Either String ConnectorResult
extract cinfo v = case fromJSON v of
  Error e -> Left e
  Success CompiledSolRec {..} ->
    case eitherDecode (LB.pack (T.unpack csrAbi)) of
      Left e -> Left e
      Right (csrAbi_parsed :: Value) ->
        Right $
        M.fromList
            [ ( "ETH"
              , M.union
                (M.fromList
                  [ ("ABI", csrAbi_pretty)
                  , --- , ("Opcodes", T.unlines $ "" : (T.words $ csrOpcodes))
                    ("Bytecode", "0x" <> csrCode)
                  ])
                cinfo
              )
            ]
        where
          csrAbi_pretty = T.pack $ LB.unpack $ encodePretty' cfg csrAbi_parsed
          cfg = defConfig {confIndent = Spaces 2, confCompare = compare}

compile_sol :: ConnectorInfo -> FilePath -> IO ConnectorResult
compile_sol cinfo solf = do
  (ec, stdout, stderr) <-
    readProcessWithExitCode "solc" ["--optimize", "--combined-json", "abi,bin,opcodes", solf] []
  let show_output = "STDOUT:\n" ++ stdout ++ "\nSTDERR:\n" ++ stderr ++ "\n"
  case ec of
    ExitFailure _ -> die $ "solc failed:\n" ++ show_output
    ExitSuccess ->
      case (eitherDecode $ LB.pack stdout) of
        Right v ->
          case extract cinfo v of
            Right cr -> return cr
            Left err ->
              die $
                "failed to extract valid output from solc:\n" ++ show_output
                  ++ "Decode:\n"
                  ++ err
                  ++ "\n"
        Left err ->
          die $
            "solc failed to produce valid output:\n" ++ show_output
              ++ "Decode:\n"
              ++ err
              ++ "\n"

connect_eth :: Connector
connect_eth outnMay pl = case outnMay of
  Just outn -> go (outn "sol")
  Nothing -> withSystemTempDirectory "reachc-sol" $ \dir ->
    go (dir </> "compiled.sol")
  where
    go :: FilePath -> IO ConnectorResult
    go solf = do
      let (cinfo, sol) = solPLProg pl
      writeFile solf (show sol)
      compile_sol cinfo solf
