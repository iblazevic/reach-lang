module Reach.Verify.Knowledge (verify_knowledge) where

import qualified Algorithm.Search as G
import Data.IORef
import Data.List.Extra
import qualified Data.Map.Strict as M
import Data.Monoid
import qualified Data.Set as S
import Data.Text.Prettyprint.Doc
import Reach.AST
import Reach.IORefRef
import Reach.Pretty ()
import Reach.Util
import Reach.Verify.Shared
import System.Directory
import System.IO

--- Knowledge Graph & Queries
data Point
  = P_Var DLVar
  | P_Con
  | P_Interact SLPart String
  | P_Part SLPart
  deriving (Eq, Ord, Show)

instance Pretty Point where
  pretty (P_Var v) = pretty v
  pretty (P_Con) = "con"
  pretty (P_Interact p m) = pretty p <> "." <> pretty m
  pretty (P_Part p) = pretty p

data KCtxt = KCtxt
  { ctxt_mlog :: Maybe Handle
  , ctxt_loglvl :: IORefRef Int
  , ctxt_res_succ :: IORef Int
  , ctxt_res_fail :: IORef Int
  , ctxt_ps :: [SLPart]
  , ctxt_back_ptrs :: S.Set Point
  , ctxt_kg :: IORefRef (M.Map Point (S.Set Point))
  }

inc :: IORef Int -> IO ()
inc r = modifyIORef r (1 +)

klog :: KCtxt -> String -> IO ()
klog ctxt msg =
  case ctxt_mlog ctxt of
    Nothing -> mempty
    Just h -> do
      lvl <- readIORefRef $ ctxt_loglvl ctxt
      hPutStrLn h $ (replicate lvl ' ') <> msg

ctxtNewScope :: KCtxt -> IO a -> IO a
ctxtNewScope ctxt m =
  paramIORefRef (ctxt_kg ctxt) $ do
    let llr = (ctxt_loglvl ctxt)
    paramIORefRef llr $ do
      modifyIORefRef llr (1 +)
      m

ctxt_restrict :: KCtxt -> SLPart -> KCtxt
ctxt_restrict ctxt who = ctxt {ctxt_ps = [who]}

ctxt_add_back :: KCtxt -> DLArg -> KCtxt
ctxt_add_back ctxt a = ctxt {ctxt_back_ptrs = ctxt_back_ptrs ctxt <> all_points a}

know1 :: KCtxt -> Point -> Point -> IO ()
know1 ctxt from to = do
  klog ctxt $ show $ pretty to <+> "->" <+> pretty from
  let f = \case
        Nothing -> Just $ S.singleton from
        Just x -> Just $ S.insert from x
  modifyIORefRef (ctxt_kg ctxt) (M.alter f to)

query1 :: KCtxt -> SLPart -> Point -> IO (Maybe [Point])
query1 ctxt who what = do
  klog ctxt $ show $ "$" <+> pretty what <+> "->" <+> pretty who <+> "?"
  kg <- readIORefRef $ ctxt_kg ctxt
  let look p = case M.lookup p kg of
        Just c -> c
        Nothing -> mempty
  return $ G.dfs look (== (P_Part who)) what

query :: KCtxt -> SrcLoc -> [SLCtxtFrame] -> SLPart -> S.Set Point -> IO ()
query ctxt at f who whats = do
  let whatsl = S.toList whats
  mpaths <- mapM (query1 ctxt who) whatsl
  let good = inc $ ctxt_res_succ ctxt
  let bad = inc $ ctxt_res_fail ctxt
  let disp1 _ Nothing = mempty
      disp1 what (Just path) =
        --- FIXME we could keep some extra information, like the
        --- binding origin from SMT to say why these variables are
        --- connected.
        putStrLn $ "  " ++ show (hcat $ punctuate " -> " $ map pretty (what : path))
  let disp = do
        cwd <- getCurrentDirectory
        putStrLn $ "Verification failed:"
        putStrLn $ "  of theorem " ++ "unknowable(" ++ show who ++ ", " ++ show (hcat $ punctuate " , " $ map pretty whatsl) ++ ")"
        putStrLn $ redactAbsStr cwd $ "  at " ++ show at
        mapM_ (putStrLn . ("  " ++) . show) f
        putStrLn $ ""
        mapM_ (uncurry disp1) $ zip whatsl mpaths
  case getAll $ mconcatMap (All . (maybe False (const True))) mpaths of
    True -> bad <> disp
    False -> good

knows :: KCtxt -> Point -> S.Set Point -> IO ()
knows ctxt from tos = do
  let tons = S.union tos (ctxt_back_ptrs ctxt)
  mapM_ (know1 ctxt from) $ S.toList tons

all_points :: DLArg -> S.Set Point
all_points = \case
  DLA_Var v -> S.singleton $ P_Var v
  DLA_Con _ -> S.singleton $ P_Con
  DLA_Array _ as -> more as
  DLA_Tuple as -> more as
  DLA_Obj m -> more $ M.elems m
  DLA_Interact who what _ -> S.singleton $ P_Interact who what
  where
    more = mconcatMap all_points

kgq_a_all :: KCtxt -> DLArg -> IO ()
kgq_a_all ctxt a =
  mapM_ (flip (knows ctxt) (all_points a)) $ map P_Part (ctxt_ps ctxt)

kgq_a_only :: KCtxt -> DLVar -> DLArg -> IO ()
kgq_a_only ctxt v a =
  knows ctxt (P_Var v) (all_points a)

kgq_a_onlym :: KCtxt -> Maybe DLVar -> DLArg -> IO ()
kgq_a_onlym ctxt mv a =
  case mv of
    Nothing -> mempty
    Just v -> kgq_a_only ctxt v a

kgq_e :: KCtxt -> Maybe DLVar -> DLExpr -> IO ()
kgq_e ctxt mv = \case
  DLE_Arg _ a -> kgq_a_onlym ctxt mv a
  DLE_Impossible {} -> mempty
  DLE_PrimOp _ _ as -> kgq_a_onlym ctxt mv (DLA_Tuple as)
  DLE_ArrayRef _ _ a _ e -> kgq_a_onlym ctxt mv (DLA_Tuple [a, e])
  DLE_ArraySet _ _ a _ e n -> kgq_a_onlym ctxt mv (DLA_Tuple [a, e, n])
  DLE_TupleRef _ a _ -> kgq_a_onlym ctxt mv a
  DLE_ObjectRef _ a _ -> kgq_a_onlym ctxt mv a
  DLE_Interact _ _ who what t as ->
    kgq_a_onlym ctxt mv (DLA_Tuple $ (DLA_Interact who what t) : as)
  DLE_Digest _ _ ->
    --- This line right here is where all the magic happens
    mempty
  DLE_Claim at f ct what -> this
    where
      this =
        case (ct, what) of
          (CT_Assert, _) -> mempty
          (CT_Assume, _) -> mempty
          (CT_Require, _) -> mempty
          (CT_Possible, _) -> mempty
          (CT_Unknowable who, (DLA_Tuple whats)) ->
            mapM_ query_each whats
            where
              query_each = query ctxt at f who . all_points
          (CT_Unknowable {}, _) ->
            impossible "not tuple unknowable"
  DLE_Transfer _ _ _ amt ->
    kgq_a_all ctxt amt
  DLE_Wait _ amt ->
    kgq_a_all ctxt amt
  DLE_PartSet _ _ arg ->
    kgq_a_all ctxt arg

kgq_m :: (KCtxt -> a -> IO ()) -> KCtxt -> LLCommon a -> IO ()
kgq_m iter ctxt = \case
  LL_Return {} -> mempty
  LL_Let _ mdv de k ->
    kgq_e ctxt mdv de
      <> iter ctxt k
  LL_Var _ _dv k ->
    iter ctxt k
  LL_Set _ dv da k ->
    kgq_a_only ctxt dv da
      <> iter ctxt k
  LL_LocalIf _ ca t f k ->
    kgq_l ctxt' t
      <> kgq_l ctxt' f
      <> iter ctxt k
    where
      ctxt' = ctxt_add_back ctxt ca

kgq_l :: KCtxt -> LLLocal -> IO ()
kgq_l ctxt = \case
  LLL_Com m -> kgq_m kgq_l ctxt m

kgq_asn :: KCtxt -> DLAssignment -> IO ()
kgq_asn ctxt (DLAssignment m) = mapM_ (uncurry (kgq_a_only ctxt)) $ M.toList m

kgq_asn_def :: KCtxt -> DLAssignment -> IO ()
kgq_asn_def ctxt (DLAssignment m) = mapM_ (kgq_a_all ctxt . DLA_Var) $ M.keys m

kgq_n :: KCtxt -> LLConsensus -> IO ()
kgq_n ctxt = \case
  LLC_Com m -> kgq_m kgq_n ctxt m
  LLC_If _ ca t f ->
    ctxtNewScope ctxt' (kgq_n ctxt' t)
      <> ctxtNewScope ctxt' (kgq_n ctxt' f)
    where
      ctxt' = ctxt_add_back ctxt ca
  LLC_FromConsensus _ _ k -> kgq_s ctxt k
  LLC_While _ asn _ (LLBlock _ _ cond_l ca) body k ->
    kgq_asn_def ctxt asn
      <> kgq_asn ctxt asn
      <> kgq_l ctxt cond_l
      <> kgq_n ctxt' body
      <> kgq_n ctxt' k
    where
      ctxt' = ctxt_add_back ctxt ca
  LLC_Continue _ asn ->
    kgq_asn ctxt asn

kgq_fs :: KCtxt -> FromSpec -> IO ()
kgq_fs ctxt = \case
  FS_Join v -> kgq_a_all ctxt (DLA_Var v)
  FS_Again {} -> mempty

kgq_s :: KCtxt -> LLStep -> IO ()
kgq_s ctxt = \case
  LLS_Com m -> kgq_m kgq_s ctxt m
  LLS_Stop {} -> mempty
  LLS_Only _at who loc k -> kgq_l (ctxt_restrict ctxt who) loc <> kgq_s ctxt k
  LLS_ToConsensus _at _from fs from_as from_msg from_amt mtime next_n ->
    kgq_fs ctxt fs <> msg_to_as <> kgq_a_all ctxt from_amt
      <> kgq_a_all ctxt (DLA_Tuple $ map DLA_Var from_msg)
      <> ctxtNewScope ctxt (maybe mempty (kgq_s ctxt . snd) mtime)
      <> ctxtNewScope ctxt (kgq_n ctxt next_n)
    where
      msg_to_as = mapM_ (uncurry (kgq_a_only ctxt)) $ zip from_msg from_as

kgq_pie1 :: KCtxt -> SLPart -> SLVar -> IO ()
kgq_pie1 ctxt who what = knows ctxt (P_Part who) $ S.singleton $ P_Interact who what

kgq_pie :: KCtxt -> SLPart -> InteractEnv -> IO ()
kgq_pie ctxt who (InteractEnv m) =
  (knows ctxt (P_Part who) $ S.singleton $ P_Con)
    <> (mapM_ (kgq_pie1 ctxt who) $ M.keys m)

kgq_lp :: Maybe Handle -> VerifySt -> LLProg -> IO ()
kgq_lp mh vst (LLProg _ (LLOpts {..}) (SLParts psm) s) = do
  putStrLn $ "Verifying knowledge assertions"
  let ps = M.keys psm
  llr <- newIORefRef 0
  kgr <- newIORefRef mempty
  let ctxt =
        KCtxt
          { ctxt_mlog = mh
          , ctxt_loglvl = llr
          , ctxt_res_succ = vst_res_succ vst
          , ctxt_res_fail = vst_res_fail vst
          , ctxt_ps = ps
          , ctxt_back_ptrs = mempty
          , ctxt_kg = kgr
          }
  mapM_ (uncurry (kgq_pie ctxt)) $ M.toList psm
  kgq_s ctxt s

verify_knowledge :: Maybe FilePath -> VerifySt -> LLProg -> IO ()
verify_knowledge mout vst lp =
  case mout of
    Nothing -> go Nothing
    Just p -> withFile p WriteMode (go . Just)
  where
    go mh = kgq_lp mh vst lp
