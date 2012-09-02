

module GhcRefacCase(ifToCase) where

import qualified Data.Generics.Schemes as SYB
import qualified Data.Generics.Aliases as SYB
import qualified GHC.SYB.Utils         as SYB

import qualified GHC
import qualified DynFlags              as GHC
import qualified Outputable            as GHC
import qualified MonadUtils            as GHC
import qualified RdrName               as GHC
import qualified OccName               as GHC
 
import GHC.Paths ( libdir )
import Control.Monad
import Control.Monad.State
import GhcUtils 
import GhcRefacTypeSyn
import Data.Data
-----------------

-- import GhcRefacLocUtils
import GhcRefacUtils 

ifToCase :: [String] -> IO () -- For now
ifToCase args  
  = do let fileName = args!!0              
           beginPos = (read (args!!1), read (args!!2))::(Int,Int)
           endPos   = (read (args!!3), read (args!!4))::(Int,Int)
       modInfo@(_, _, mod, toks) <- parseSourceFile fileName 
       let exp = locToExp beginPos endPos toks mod
       case exp of
         (GHC.L _ (GHC.HsIf _ _ _ _))
                -> do refactoredMod <- applyRefac (ifToCase' exp) (Just modInfo) fileName
                      writeRefactoredFiles False [refactoredMod]
         _      -> error "You haven't selected an if-then-else  expression!"
    -- where 


ifToCase' ::
  forall t (m :: * -> *).
  (MonadPlus m
  , MonadState (([PosToken], Bool), (Int, Int)) m
  )
  =>
  GHC.GenLocated GHC.SrcSpan (GHC.HsExpr GHC.RdrName)
  -> (t, [GHC.LIE GHC.RdrName], GHC.ParsedSource) -> m GHC.ParsedSource
-- ifToCase' exp (_, _, mod)= applyTP (once_buTP (failTP `adhocTP` inExp)) mod
ifToCase' exp (_, _, mod)= somewhereStaged SYB.Parser (SYB.mkM inExp) mod
       where 
         inExp exp1@(GHC.L _ (GHC.HsIf _ _ _ _))
           | sameOccurrence exp exp1       
           -- = let newExp =Exp (HsCase e [HsAlt loc0 (nameToPat "True") (HsBody e1) [],
           --                              HsAlt loc0 (nameToPat "False")(HsBody e2) []])
           = let newExp = ifToCaseTransform exp1
             in update exp1 newExp exp1
         inExp _ = mzero


ifToCaseTransform :: GHC.Located (GHC.HsExpr GHC.RdrName) -> GHC.Located (GHC.HsExpr GHC.RdrName)
ifToCaseTransform (GHC.L l (GHC.HsIf _se e1 e2 e3))
  = GHC.L l (GHC.HsCase e1 (GHC.MatchGroup
                   [
                     (GHC.noLoc $ GHC.Match
                      [
                        GHC.noLoc $ GHC.ConPatIn (GHC.noLoc $ GHC.mkRdrUnqual $ GHC.mkVarOcc "True") (GHC.PrefixCon [])
                      ]
                      Nothing
                       ((GHC.GRHSs
                         [
                           GHC.noLoc $ GHC.GRHS [] e2
                         ] GHC.EmptyLocalBinds))
                      )
                   , (GHC.noLoc $ GHC.Match
                      [
                        GHC.noLoc $ GHC.ConPatIn (GHC.noLoc $ GHC.mkRdrUnqual $ GHC.mkVarOcc "False") (GHC.PrefixCon [])
                      ]
                      Nothing
                       ((GHC.GRHSs
                         [
                           GHC.noLoc $ GHC.GRHS [] e3
                         ] GHC.EmptyLocalBinds))
                      )
                   ] undefined))
ifToCaseTransform x                          = x

                           



