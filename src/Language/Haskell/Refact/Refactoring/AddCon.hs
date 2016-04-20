{-# LANGUAGE ScopedTypeVariables #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  RefacAddCon
-- Copyright   :  (c) Christopher Brown 2006
--
-- Maintainer  :  cmb21@kent.ac.uk
-- Stability   :  provisional
-- Portability :  portable
--
-- This module contains a transformation for HaRe.
-- Add a new constructor to a data type

-----------------------------------------------------------------------------

module Language.Haskell.Refact.Refactoring.AddCon
  (
    addConstructor
  , compAddConstructor
  ) where

import qualified Data.Generics as SYB
import qualified GHC.SYB.Utils as SYB

import qualified GHC
import qualified Name                  as GHC
import qualified RdrName               as GHC

import Control.Exception
import Data.List
import Data.Maybe

import qualified Language.Haskell.GhcMod as GM
import Language.Haskell.GhcMod.Internal  as GM
import Language.Haskell.Refact.API

import Language.Haskell.GHC.ExactPrint.Parsers
import Language.Haskell.GHC.ExactPrint.Transform
import Language.Haskell.GHC.ExactPrint.Types

import Data.Generics.Strafunski.StrategyLib.StrategyLib hiding (liftIO,MonadPlus,mzero)
import System.Directory
-- import PrettyPrint
-- import PrettyPrint
-- import PosSyntax
-- import AbstractIO
-- import Data.Maybe
-- import TypedIds
-- import UniqueNames hiding (srcLoc)
-- import PNT
-- import TiPNT
-- import Data.List
-- import RefacUtils hiding (getParams)
-- import PFE0 (findFile)
-- import MUtils (( # ))
-- import RefacLocUtils
-- --import System
import System.IO
-- import System.IO.Unsafe
import Data.Char

-- | An argument list for a function which of course is a list of patterns.
type FunctionPats = [GHC.Pat GHC.RdrName]

-- | A list of declarations used to represent a where or let clause.
type WhereDecls = [GHC.HsDecl GHC.RdrName]


alphabet :: String
alphabet = "abcdefghijklmnopqrstuvwxyz"

-- ---------------------------------------------------------------------
-- | This refactoring adds a new constructor to an existing data declaration
addConstructor :: RefactSettings -> GM.Options -> FilePath -> [String] -> SimpPos -> IO [FilePath]
addConstructor settings opts fileName ans (row,col) = do
  absFileName <- canonicalizePath fileName
  runRefacSession settings opts (compAddConstructor absFileName ans (row,col))

compAddConstructor :: FilePath -> [String] -> SimpPos -> RefactGhc [ApplyRefacResult]
compAddConstructor fileName ans (row, col) = do
  logm "compAddConstructor"

  parseSourceFileGhc fileName
  parsed  <- getRefactParsed
  nm <- getRefactNameMap

  -- let modName = convertModName modName1            -- Parse the input file.
  -- modInfo@(inscps, exps, mod, tokList) <- parseSourceFile (fileName)
  -- let res1 = locToPNT fileName (row, col) mod
  --     res2 = locToPN fileName (row, col) mod
  --     decs = hsDecls mod
  --     datDec = definingDecls [res2] decs False True
  --     datName = (declToName (ghead "datName" datDec))
  --     datPNT = (declToPNT (ghead "datPNT" datDec))

       -- add any new type params...

  let maybePn = locToRdrName (row,col) parsed
  case maybePn of
    Just lr@(GHC.L l _) ->
      do
        let aName = rdrName2NamePure nm lr
        let pn = GHC.L l aName
        logm $ "AddCon.compAddConstructor:about to applyRefac for:pn=" ++ SYB.showData SYB.Parser 0 pn
        decs <- liftT $ hsDecls parsed
        let datDec  = ghead "compAddConstructor.2" $ definingDeclsRdrNames nm [aName] decs False True
        let datName = ghead "compAddConstructor.1" $ definedNamesRdr nm datDec
        -- (refactoredMod,_) <- applyRefac (addField datDec datName (tail ans) parsed) RSAlreadyLoaded
        (refactoredMod,_) <- applyRefac (doRefactoring datDec datName (head ans) (tail ans) parsed) RSAlreadyLoaded
        return [refactoredMod]

  -- ((_,m), (newToks, newMod)) <- applyRefac (addField (ghead "applyRefac" datDec) datPNT datName res1 (drop 1 (tail first)) tokList)
  --                                          (Just (inscps, exps, mod, tokList)) fileName

  -- writeRefactoredFiles False [((fileName, m), (newToks, newMod))]
{-
  (s, col', row', inf) <- doFileStuff fileName row col ans
  modName1 <- fileNameToModName fileName

  let modName = convertModName modName1            -- Parse the input file.
  modInfo@(inscps, exps, mod, tokList) <- parseSourceFile (fileName)
  -- Find the datatype that's been highlighted as the refactree

  {- case checkCursor fileName row col mod of
    Left errMsg -> do AbstractIO.removeFile (fileName ++ ".temp.hs")
                      error errMsg
    Right dat ->
      do

      -}

  let res' = locToPNT fileName (row, col) mod
      res = pNTtoPN res'
       -- Parse the input file.
  AbstractIO.putStrLn ("parsing ..." ++ fileName ++ ".temp.hs")
  modInfo2@(inscps', exps', mod', tokList') <- parseSourceFileOld (fileName ++ ".temp.hs")
  AbstractIO.putStrLn "parsed."
  let decs = hsDecls mod'
      -- datDec = definingDecls [res] decs False True
       -- get the list of constructors from the data type
      decs' = hsDecls mod
      datDec'' = definingDecls [res2] decs False True
      datDec' = ghead "datDec'" datDec''
      -- datName = getDataName [datDec']
      pnames = definedPNs datDec'
      newPN = locToPN (fileName ++ ".temp.hs") (row', col') mod'
      newPNT = locToPNT (fileName ++ ".temp.hs") (row', col') mod'
  numParam <- getParams datDec' newPNT
  let oldPnames = filter (/= newPN) pnames
      position = findPos 0 newPN pnames

  ((_,m), (newToks, newMod)) <- applyRefac (addCon (fileName) datName pnames newPN newPNT numParam oldPnames position inf (tail first) modName)
                                                       (Just (inscps', exps', mod', tokList')) (fileName++"temp.hs")
  writeRefactoredFiles True [((fileName, m), (newToks, newMod))]
  AbstractIO.removeFile (fileName ++ ".temp.hs")
  AbstractIO.putStrLn "Completed.\n"
-}

-- ---------------------------------------------------------------------

{-
refacAddCon args
  = do
       let len = length args
       if len > 2
         then do
            let (first,sec) = splitAt ((length args)-2) args
            let fileName    = first!!0
                ans         = concat ( map ( ++ " ") (tail first))
                row         = read (sec!!0)::Int
                col         = read (sec!!1)::Int
            AbstractIO.putStrLn "refacAddCon"

            -- let modName = convertModName modName1            -- Parse the input file.
            modInfo@(inscps, exps, mod, tokList) <- parseSourceFile (fileName)
            let res1 = locToPNT fileName (row, col) mod
                res2 = locToPN fileName (row, col) mod
                decs = hsDecls mod
                datDec = definingDecls [res2] decs False True
                datName = (declToName (ghead "datName" datDec))
                datPNT = (declToPNT (ghead "datPNT" datDec))

                 -- add any new type params...

            ((_,m), (newToks, newMod)) <- applyRefac (addField (ghead "applyRefac" datDec) datPNT datName res1 (drop 1 (tail first)) tokList)
                                                     (Just (inscps, exps, mod, tokList)) fileName

            writeRefactoredFiles False [((fileName, m), (newToks, newMod))]

            (s, col', row', inf) <- doFileStuff fileName row col ans
            modName1 <- fileNameToModName fileName

            let modName = convertModName modName1            -- Parse the input file.
            modInfo@(inscps, exps, mod, tokList) <- parseSourceFile (fileName)
            -- Find the datatype that's been highlighted as the refactree

            {- case checkCursor fileName row col mod of
              Left errMsg -> do AbstractIO.removeFile (fileName ++ ".temp.hs")
                                error errMsg
              Right dat ->
                do

                -}

            let res' = locToPNT fileName (row, col) mod
                res = pNTtoPN res'
                 -- Parse the input file.
            AbstractIO.putStrLn ("parsing ..." ++ fileName ++ ".temp.hs")
            modInfo2@(inscps', exps', mod', tokList') <- parseSourceFileOld (fileName ++ ".temp.hs")
            AbstractIO.putStrLn "parsed."
            let decs = hsDecls mod'
                -- datDec = definingDecls [res] decs False True
                 -- get the list of constructors from the data type
                decs' = hsDecls mod
                datDec'' = definingDecls [res2] decs False True
                datDec' = ghead "datDec'" datDec''
                -- datName = getDataName [datDec']
                pnames = definedPNs datDec'
                newPN = locToPN (fileName ++ ".temp.hs") (row', col') mod'
                newPNT = locToPNT (fileName ++ ".temp.hs") (row', col') mod'
            numParam <- getParams datDec' newPNT
            let oldPnames = filter (/= newPN) pnames
                position = findPos 0 newPN pnames

            ((_,m), (newToks, newMod)) <- applyRefac (addCon (fileName) datName pnames newPN newPNT numParam oldPnames position inf (tail first) modName)
                                                                 (Just (inscps', exps', mod', tokList')) (fileName++"temp.hs")
            writeRefactoredFiles True [((fileName, m), (newToks, newMod))]
            AbstractIO.removeFile (fileName ++ ".temp.hs")
            AbstractIO.putStrLn "Completed.\n"
         else do
            error "refacAddCon must take a new constructor and a list of arguments."
-}

-- ---------------------------------------------------------------------

doRefactoring :: GHC.LHsDecl GHC.RdrName
              -> GHC.Name
              -> String
              -> [String]
              -> GHC.ParsedSource
              -> RefactGhc ()
doRefactoring datDec datName fName fType t = do
  nm <- getRefactNameMap
  t2 <- addField datDec datName fName fType t
  let
    fileName = assert False undefined
    pnames   = assert False undefined
    newPN    = assert False undefined
    newPNT   = assert False undefined
    numParam = assert False undefined
    oldPnames = getConNames nm datDec
  t3 <- addCon fileName datName pnames newPN newPNT numParam oldPnames (assert False undefined) (assert False undefined) fType t2
  putRefactParsed t3 mempty

-- ---------------------------------------------------------------------

getConNames :: (SYB.Data t) => NameMap -> t -> [GHC.Name]
getConNames nm t = SYB.everything (++) ([] `SYB.mkQ` inCon) t
  where
    inCon (GHC.ConDecl ns _ _ _ _ _ _ _) = map (rdrName2NamePure nm) ns

-- ---------------------------------------------------------------------

addField :: GHC.LHsDecl GHC.RdrName -> GHC.Name -> String -> [String] -> GHC.ParsedSource
         -> RefactGhc GHC.ParsedSource
addField datDec datPNT fName fType t = do
  logm $ "addField:(datDec,datPNT,fType)=" ++ showGhc (datDec,datPNT,fType)
  addTypeVar datDec datPNT fName fType t

-- ---------------------------------------------------------------------

{-
addingField pnt fName fType t
 = applyTP (stop_tdTP (failTP `adhocTP` inDat)) t
    where
     inDat (dat@(HsConDecl s i c p types)::HsConDeclP)
       | p == pnt = do
                       r <- update dat (HsConDecl s i c p (newTypes types fType)) dat
                       return r
     inDat (dat@(HsRecDecl s i c p types)::HsConDeclP)
       | p == pnt = do
                      r <- update dat (HsRecDecl s i c p (newRecTypes types fName fType)) dat
                      return r
     inDat _ = fail ""


     -- newRecTypes must check that the name is not already declared as a field name
     -- within that constructor.
     newRecTypes xs n []  = xs
     newRecTypes xs n (a:as)
       | n `elem` (map pNTtoName (unFlattern xs)) = error "There is already a field declared with that name!"
       | otherwise =  ([nameToPNT n], (HsUnBangedType (Typ (HsTyCon (nameToPNT a))))) : (newRecTypes xs n as)

     unFlattern :: [([a],b)] -> [a]
     unFlattern [] = []
     unFlattern ((xs, y):xss) = xs ++ (unFlattern xss)


     newTypes xs [] = xs
     newTypes xs (a:as) = HsUnBangedType (Typ (HsTyCon (nameToPNT a))) : (newTypes xs as)
-}

-- ---------------------------------------------------------------------

mkConDecl :: String -> [String] -> RefactGhc (GHC.LConDecl GHC.RdrName)
mkConDecl _ [] = error "mkConDecl called for []"
mkConDecl n ss = do
  l <- liftT uniqueSrcSpanT
  ln <- liftT uniqueSrcSpanT
  let
    mkArg s = do
      la <- liftT uniqueSrcSpanT
      let nv = (GHC.L la (GHC.HsTyVar (mkRdrName s)))
      liftT $ addSimpleAnnT nv (DP (0,1)) [((G GHC.AnnVal),DP (0,0))]
      return nv
  args <- mapM mkArg ss

  let
    nn = GHC.L ln (mkRdrName n)
    conNames = [nn]
    details  = GHC.PrefixCon args
    con = GHC.L l (GHC.ConDecl conNames GHC.Explicit (GHC.HsQTvs [] []) (GHC.noLoc []) details GHC.ResTyH98 Nothing False)
  liftT $ addSimpleAnnT nn  (DP (0,0)) [(G GHC.AnnVal,DP (0,0))]
  liftT $ addSimpleAnnT con (DP (0,1)) []
  return con

-- ---------------------------------------------------------------------

addTypeVar :: (SYB.Data t)
           => GHC.LHsDecl GHC.RdrName -> GHC.Name -> String -> [String] -> t -> RefactGhc t
addTypeVar datDec datName fName fType t = do
  logm $ "addTypeVar:(datDec,datName,fType)=" ++ showGhc (datDec,datName,fType)
  logDataWithAnns "addTypeVar:datDec" datDec
  nm <- getRefactNameMap
  applyTP (full_buTP (idTP `adhocTP` (inDatDeclaration nm datDec))) t
    where
      inDatDeclaration :: NameMap -> GHC.LHsDecl GHC.RdrName -> GHC.LHsDecl GHC.RdrName -> RefactGhc (GHC.LHsDecl GHC.RdrName)
      inDatDeclaration nm _ d@(GHC.L l (GHC.TyClD (GHC.DataDecl ln bndrs (GHC.HsDataDefn nd cxt mc mks cons derivs) fvs)))
        | GHC.nameUnique datName == (GHC.nameUnique $ rdrName2NamePure nm ln) && checkIn fType (flattenBndrs bndrs)
        = do
            let
              newTyVarBndr v = do
                ss <- liftT uniqueSrcSpanT
                let nv = GHC.L ss (GHC.UserTyVar $ mkRdrName v)
                liftT $ addSimpleAnnT nv (DP (0,1)) [((G GHC.AnnVal),DP (0,0))]
                liftT $ appendToSortKey d ss
                return nv
              updateTVs (GHC.HsQTvs kvs tvs) ntvs = GHC.HsQTvs kvs (tvs ++ ntvs)
            ntvs <- mapM newTyVarBndr fType
            let bndrs' = updateTVs bndrs ntvs
            newCon <- mkConDecl fName fType
            liftT $ addTrailingAnnT (G GHC.AnnVbar ) (last cons)
            let cons' = cons ++ [newCon]
            return (GHC.L l (GHC.TyClD (GHC.DataDecl ln bndrs' (GHC.HsDataDefn nd cxt mc mks cons' derivs) fvs)))

      -- inDatDeclaration (Dec (HsDataDecl _ _ tp _ _)) (dat@(Dec (HsTypeSig s is c t))::HsDeclP)
      --   | (pNTtoName datName) `elem` (map (pNTtoName.typToPNT) (flatternTApp t) )
      --     = do
      --          let res = changeType t tp
      --          if res == t
      --            then return dat
      --            else update dat (Dec (HsTypeSig s is c res)) dat

      inDatDeclaration _ _ t = return t

      -- AZ: extract just the names used in the tyvars
      flattenBndrs (GHC.HsQTvs kvs tvs) = map go tvs
        where go (GHC.L l (GHC.UserTyVar n))               = showGhc n
              go (GHC.L l (GHC.KindedTyVar (GHC.L _ n) _)) = showGhc n

      -- AZ: for each new type/type variable to be added, if it is a type
      -- variable check that it is not already present. Return True if there is
      -- no problem.
      checkIn [] _ = True
      checkIn (fType:fTypes) tp =
       (fType `elem` tp) == False &&
            isLower (ghead "checkIn" fType) || (checkIn fTypes tp)
      -- checkIn (fType:fTypes) tp =
      --  (fType `elem` (map (pNTtoName.typToPNT) (flatternTApp tp))) == False &&
      --       isLower (ghead "checkIn" fType) || (checkIn fTypes tp)

      checkInOne t tp n [] = []
      -- checkInOne t tp n (f:fs)
      --   | (f `elem` (map (pNTtoName.typToPNT) (flatternTApp tp))) &&
      --         isLower (ghead "checkInOne" f) = checkInOne t tp n fs
      --   | (f `elem` (map (pNTtoName.typToPNT) (flatternTApp t))) &&
      --         isLower (ghead "checkInOne" f)  = newName : checkInOne t tp (n ++ [newName]) fs
      --   | (f `elem` (map (pNTtoName.typToPNT) (flatternTApp t))) == False &&
      --        isLower (ghead "checkInOne" f) = f : (checkInOne t tp n fs)
      --   | otherwise = checkInOne t tp n fs

      --       where
      --         newName = (mkNewName f (n ++ (map (pNTtoName.typToPNT) (flatternTApp tp))) 1)

      checkInOne2 tp n [] = []
      -- checkInOne2 tp n (f:fs)
      --   | (f `elem` (map (pNTtoName.typToPNT) (flatternTApp tp))) == False &&
      --        isLower (ghead "checkInOne" f) = f : (checkInOne2 tp n fs)
      --   | otherwise = checkInOne2 tp n fs


      -- changeType :: HsTypeP -> HsTypeP -> HsTypeP
      changeType :: GHC.LHsType GHC.RdrName -> GHC.LHsType GHC.RdrName -> GHC.LHsType GHC.RdrName
      changeType t@(GHC.L l (GHC.HsFunTy t1 t2)) tp
            = (GHC.L l (GHC.HsFunTy (changeType t1 tp) (changeType t2 tp)))
      -- changeType t@(GHC.L l (HsAppTy (GHC.L l1 (HsTyCon p)) t2)) tp
      --   | (defineLoc datName) == (defineLoc p) &&
      --     checkIn fType t
      --       = createTypFunc ((typToPNT.(ghead "inDatDeclaration").flatternTApp) t)
      --                                         ( ((map nameToTyp fType') ++ (tail (flatternTApp t))))
      --        where
      --         fType' = checkInOne t tp [" "] fType
      changeType t@(GHC.L l (GHC.HsAppTy t1 t2)) tp
            = (GHC.L l (GHC.HsAppTy (changeType t1 tp) (changeType t2 tp)))

              -- fType'' = checkNames ftype' t
      -- changeType t@(Typ (HsTyCon p)) tp
      --   | (defineLoc datName) == (defineLoc p) &&
      --        checkIn fType t
      --          = createTypFunc ((typToPNT.(ghead "inDatDeclaration").flatternTApp) t)
      --                                         ( ((map nameToTyp fType') ++ (tail (flatternTApp t))))
      --       where
      --         fType' = checkInOne t tp [" "] fType
      changeType t tp = t

      flatternTApp :: GHC.LHsType GHC.RdrName -> [GHC.LHsType GHC.RdrName]
      flatternTApp (GHC.L _ (GHC.HsFunTy t1 t2)) = flatternTApp t1 ++ flatternTApp t2
      flatternTApp (GHC.L _ (GHC.HsAppTy t1 t2)) = flatternTApp t1 ++ flatternTApp t2
      flatternTApp x = [x]

{-
addTypeVar datDec datName pnt fType toks t
 = applyTP (full_buTP (idTP `adhocTP` (inDatDeclaration datDec))) t
    where
      inDatDeclaration _ (dat@(Dec (HsDataDecl a b tp c d))::HsDeclP)
        | (defineLoc datName == (defineLoc.typToPNT.(ghead "inDatDeclaration").flatternTApp) tp) &&
          checkIn fType tp
          = update dat (Dec (HsDataDecl a b (createTypFunc ((typToPNT.(ghead "inDatDeclaration").flatternTApp) tp)
                                              ( ((map nameToTyp fType') ++ (tail (flatternTApp tp))) )) c d)) dat

             where
              fType' = checkInOne2 tp [" "] fType

      inDatDeclaration (Dec (HsDataDecl _ _ tp _ _)) (dat@(Dec (HsTypeSig s is c t))::HsDeclP)
        | (pNTtoName datName) `elem` (map (pNTtoName.typToPNT) (flatternTApp t) )
          = do

               let res = changeType t tp
               if res == t
                 then return dat
                 else update dat (Dec (HsTypeSig s is c res)) dat

      inDatDeclaration _ t = return t

      checkIn [] tp = True
      checkIn (fType:fTypes) tp =
       (fType `elem` (map (pNTtoName.typToPNT) (flatternTApp tp))) == False &&
            isLower (ghead "checkIn" fType) || (checkIn fTypes tp)

      checkInOne t tp n [] = []
      checkInOne t tp n (f:fs)
        | (f `elem` (map (pNTtoName.typToPNT) (flatternTApp tp))) &&
              isLower (ghead "checkInOne" f) = checkInOne t tp n fs
        | (f `elem` (map (pNTtoName.typToPNT) (flatternTApp t))) &&
              isLower (ghead "checkInOne" f)  = newName : checkInOne t tp (n ++ [newName]) fs
        | (f `elem` (map (pNTtoName.typToPNT) (flatternTApp t))) == False &&
             isLower (ghead "checkInOne" f) = f : (checkInOne t tp n fs)
        | otherwise = checkInOne t tp n fs

            where
              newName = (mkNewName f (n ++ (map (pNTtoName.typToPNT) (flatternTApp tp))) 1)

      checkInOne2 tp n [] = []
      checkInOne2 tp n (f:fs)
        | (f `elem` (map (pNTtoName.typToPNT) (flatternTApp tp))) == False &&
             isLower (ghead "checkInOne" f) = f : (checkInOne2 tp n fs)
        | otherwise = checkInOne2 tp n fs


      changeType :: HsTypeP -> HsTypeP -> HsTypeP
      changeType t@(Typ (HsTyFun t1 t2)) tp
            = (Typ (HsTyFun (changeType t1 tp) (changeType t2 tp)))
      changeType t@(Typ (HsTyApp (Typ (HsTyCon p)) t2)) tp
        | (defineLoc datName) == (defineLoc p) &&
          checkIn fType t
            = createTypFunc ((typToPNT.(ghead "inDatDeclaration").flatternTApp) t)
                                              ( ((map nameToTyp fType') ++ (tail (flatternTApp t))))
             where
              fType' = checkInOne t tp [" "] fType
      changeType t@(Typ (HsTyApp t1 t2)) tp
            = (Typ (HsTyApp (changeType t1 tp) (changeType t2 tp)))

              -- fType'' = checkNames ftype' t
      changeType t@(Typ (HsTyCon p)) tp
        | (defineLoc datName) == (defineLoc p) &&
             checkIn fType t
               = createTypFunc ((typToPNT.(ghead "inDatDeclaration").flatternTApp) t)
                                              ( ((map nameToTyp fType') ++ (tail (flatternTApp t))))
            where
              fType' = checkInOne t tp [" "] fType
      changeType t tp = t

      flatternTApp :: HsTypeP -> [HsTypeP]
      flatternTApp (Typ (HsTyFun t1 t2)) = flatternTApp t1 ++ flatternTApp t2
      flatternTApp (Typ (HsTyApp t1 t2)) = flatternTApp t1 ++ flatternTApp t2
      flatternTApp x = [x]
-}

-- ---------------------------------------------------------------------

{-

checkCursor :: String -> Int -> Int -> HsModuleP -> Either String HsDeclP
checkCursor fileName row col mod
 = case locToTypeDecl of
     Nothing -> Left ("Invalid cursor position. Please place cursor at the beginning of the constructor name!")
     Just decl@(Dec (HsDataDecl loc c tp xs _)) -> Right decl
   where
    locToTypeDecl = find (definesTypeCon (locToPNT fileName (row, col) mod)) (hsModDecls mod)

    -- definesTypeCon pnt (Dec (HsDataDecl loc c tp xs _))
    --  = isDataCon pnt && (findPNT pnt tp)

    definesTypeCon pnt (Dec (HsDataDecl _ _ _ i _))
      = isDataCon pnt && (findPNT pnt i)
    definesTypeCon pnt _ = False



isDefinedData [] _    = error "Please select the beginning of a constructor!"
isDefinedData ((Dec (HsDataDecl _ _ _ cs i)):ds) c2
 | c2 `myIn` cs = True
 | otherwise  = isDefinedData ds c2
     where
       myIn _ [] = False
       myIn pnt ((HsConDecl _ _ _ i _):cs)
         | pnt == i   = True
         | otherwise  = myIn pnt cs
       myIn pnt ((HsRecDecl _ _ _ i _):cs)
         | pnt == i   = True
         | otherwise  = myIn pnt cs

convertModName (PlainModule s) = s
convertModName m@(MainModule f) = modNameToStr m


findPos _ _ [] = 0
findPos count newPn (x:xs)
 | newPn == x = count
 | otherwise  = findPos (count + 1) newPn xs

getBeforePN _ _ [] = 0
getBeforePN c newPN (x:xs)
  | newPN /= x = (c + 1) + (getBeforePN (c + 1)newPN xs)
  | otherwise = c
-}

-- ---------------------------------------------------------------------


createFun (x:xs) newPN datName = do
  let str = "added" ++ x ++ " = error \"added " ++ (concat (map ( ++ " ") (x:xs))) ++ "to " ++ datName ++ "\""
  -- addedC2 = error "added C2 c to T"

  parseDeclWithAnns str

{-

createFun (x:xs) newPN datName
 = Dec ( HsPatBind loc0 (pNtoPat funPName) (HsBody (nameToExp ("error \"added " ++ (concat (map ( ++ " ") (x:xs))) ++ "to " ++ datName ++ "\"") )) [] )
    where funPName= PN (UnQual ("added" ++ x)) (S loc0)

-}

-- ---------------------------------------------------------------------
{-

getParams (Dec (HsDataDecl _ _ _ cons _)) newPNT
 = numParam cons
     where
       numParam [] = return 0
       numParam (x@(HsConDecl _ _ _ pnt list):cs)
        | newPNT == pnt = do
                             list' <- countCon x
                             return $ length list'
        | otherwise = do x <- numParam cs
                         return x
       numParam (x@(HsRecDecl _ _ _ pnt list):cs)
        | newPNT == pnt = do list' <- countCon' x
                             return $ length list'
        | otherwise = do x <- numParam cs
                         return x

       -- numParam _ = return 0

countCon :: (MonadPlus m, Term t) => t -> m [Int]
countCon co
 = applyTU (full_tdTU (constTU [] `adhocTU` inCon)) co
    where
      inCon a@(HsTyCon _::TI PNT HsTypeP) = return [0]
      inCon a@(HsTyVar _::TI PNT HsTypeP) = return [0]
      inCon _ = return []

countCon' :: (MonadPlus m, Term t) => t -> m [Int]
countCon' co
 = applyTU (full_tdTU (constTU [] `adhocTU` inCon)) co
    where
      inCon a@((x, _)::([PNT], HsBangType HsTypeP)) = return $ replicate (length x) 0
      -- inCon _ = return []
-}

-- ---------------------------------------------------------------------

addCon :: FilePath -> GHC.Name -> GHC.Name -> d -> e -> Int -> [GHC.Name] -> h -> i -> [String] -> GHC.ParsedSource -> RefactGhc GHC.ParsedSource
addCon fileName datName pnames newPn newPNT numParam oldPnames  position inf xs parsed
 = do
      newFun <- createFun xs newPn (showGhc datName)
      logm $ "addCom:newFun=" ++ showGhc newFun
      newMod <- addDecl parsed Nothing ([newFun], Nothing)
      nm <- getRefactNameMap
      res <- findFuncs nm fileName datName newMod pnames newPn newPNT numParam oldPnames position inf xs

   --   res2 <- findPatterns ses datName res pnames newPn newPNT numParam oldPnames position inf xs
      -- putRefactParsed res mempty
      -- putRefactParsed newMod mempty
      return res
{-
addCon fileName datName pnames newPn newPNT numParam oldPnames  position inf xs modName (inscps, exps, mod)
 = do
      newMod <- addDecl mod Nothing ([createFun xs newPn datName], Nothing) True
      -- unsafePerformIO.putStrLn $ show newMod
      res <- findFuncs fileName datName newMod pnames newPn newPNT numParam oldPnames position inf xs modName

   --   res2 <- findPatterns ses datName res pnames newPn newPNT numParam oldPnames position inf xs

      return res
-}

-- ---------------------------------------------------------------------

{-
getPNs (Dec (HsFunBind _ (m:ms) ))
 = checkMatch (m:ms)
    where checkMatch [] = []
          checkMatch ((HsMatch _ _ (p:ps) _ _):ms)
            | (getPN p) /= defaultPN = (getPN p) : checkMatch ms
            | otherwise = checkMatch ms

getPNPats (Exp (HsCase e pats))
 = checkAlt pats
    where checkAlt [] = []
          checkAlt ((HsAlt loc p e2 ds):ps)
            | p /= (Pat HsPWildCard) = (getPN p) : checkAlt ps
            | otherwise = checkAlt ps

getPN p
 = fromMaybe (defaultPN)
             (applyTU (once_tdTU (failTU `adhocTU` inPat)) p)

    where
      inPat (pat::PName)
       = Just pat
      -- inPat _ = Nothing

findPosBefore newPN [] = []
findPosBefore newPN (x:[]) = [x]
findPosBefore newPN (x:y:ys)
 | newPN == y = [x]
 | otherwise  = findPosBefore newPN (y:ys)
-}

-- ---------------------------------------------------------------------

-- |AZ: Seems to find all functions having multiple matches on the type having
-- the new constructor, and adds one for the new constructor.
-- TODO: maybe use the GHC exhaustiveness checker instead.
findFuncs :: (SYB.Data t) => NameMap -> FilePath -> GHC.Name -> t -> b -> c -> d -> Int -> [GHC.Name] -> g -> h -> [i] -> RefactGhc t
findFuncs nm fileName datName t pnames newPn newPNT numParam oldPnames position inf (x:xs) = do
  logm "findFuncs is a nop"
  applyTP (stop_tdTP (failTP `adhocTP` inFun
                             `adhocTP` inFunDecl
                     )) t
    where
    inFunDecl :: GHC.LHsDecl GHC.RdrName -> RefactGhc (GHC.LHsDecl GHC.RdrName)
    inFunDecl (GHC.L l (GHC.ValD f@(GHC.FunBind{}))) = do
      (GHC.L l' f') <- inFun (GHC.L l f)
      return (GHC.L l' (GHC.ValD f'))
    inFunDecl x = return x

    inFun :: GHC.LHsBind GHC.RdrName -> RefactGhc (GHC.LHsBind GHC.RdrName)
    inFun dec1@(GHC.L l (GHC.FunBind ln f (GHC.MG matches tys ty o) co fvs ti))
        = do
            -- logm "findFuncs.inFun"
            logDataWithAnns "findFuncs.inFun:dec1" dec1
            mexp <- findCase dec1
            logm $ "findFuncs.inFun:mexp=" ++ showGhc mexp
            case mexp of
              Just exp1 -> do
                error "findFuncs: still need if leg"
                    -- let altPNs = getPNPats exp1
                    -- if oldPnames /= altPNs
                    --  then do
                    --   let posBefore = findPosBefore newPn pnames
                    --   update exp1 (newPat3 exp1 (head posBefore)) dec1
                    --  else do
                    --   update exp1 (newPat2 exp1) dec1

              Nothing -> do
                 ((match,arity), patar) <- findFun dec1
                 if match == False
                   then do  --error "not found"
                       fail ""
                   else do
                         let funPNs = getPNs nm dec1
                         logm $ "dec1=" ++ showGhc dec1
                         logm $ "(oldPnames,funPNs)=" ++ showGhc (oldPnames,funPNs)
                         if oldPnames /= funPNs
                           then do
                            error "findFuncs: still need else leg 1"
                            -- let posBefore = findPosBefore newPn pnames
                            -- if length posBefore > 1
                            --  then do
                            --   update dec1 (newMatch3 dec1 (head posBefore) arity patar) dec1
                            --  else do
                            --   update dec1 (newMatch dec1 arity patar) dec1
                           else do
                            error "findFuncs: still need else leg 2"
                           -- update dec1 (newMatch2 dec1 arity patar) dec1
                       where
                        -- newMatch (Dec (HsFunBind loc1 matches@((HsMatch _ pnt p e ds):ms)))  arity patar
                        --   =  Dec (HsFunBind loc1 (newMatches matches pnt arity patar (length p)))

                        newMatch2 (GHC.L l (GHC.FunBind ln i (GHC.MG matches tys rty o) co fvs t) ) arity
                          = (GHC.L l (GHC.FunBind ln i (GHC.MG matches' tys rty o) co fvs t) )
                          where
                            matches' = matches ++ newMatch
                            newMatch = newMatch' arity
                        -- newMatch2 (Dec (HsFunBind loc1 matches@((HsMatch _ pnt p e ds):ms) )) arity patar
                        --   = Dec (HsFunBind loc1 (fst ++ (newMatch' pnt arity patar(length p)) ++ snd) )
                        --     where
                        --       (fst, snd) = splitAt position matches

                        -- newMatch3 (Dec (HsFunBind loc1 matches@((HsMatch _ pnt p e ds):ms))) posBefore arity patar
                        --   = Dec (HsFunBind loc1 (newMatches' matches pnt posBefore arity patar (length p)))


              {-
                        newMatches [] pnt position arity patar = newMatch' pnt position arity patar
                        newMatches (m@(HsMatch _ _ pats _ _):ms) pnt position arity patar
                         | or (map wildOrID pats) = (newMatch' pnt position arity patar) ++ (m : ms)
                         | otherwise                     = m : (newMatches ms pnt position arity patar)

                        newMatches' [] pnt posBefore position arity patar = newMatch' pnt position arity patar
                        newMatches' (m@(HsMatch _ _ pats _ _):ms) pnt posBefore position arity patar
                         | (getPN pats) == posBefore = m : ((newMatch' pnt position arity patar) ++ ms)
                         | or (map wildOrID pats) = (newMatch' pnt position arity patar) ++ (m : ms)
      --                   | (TiDecorate.Pat HsPWildCard) `elem` pats = (newMatch' pnt) ++ (m : ms)
                         | otherwise      = m : (newMatches' ms pnt posBefore position arity patar)
-}

                        newMatch' arity = error "newMatch'"
{-
                        newMatch' pnt arity  patar position
                  --       | numParam == 0  =  [HsMatch loc0 pnt [pNtoPat newPn] (HsBody (nameToExp ("added" ++ x))) []  ]
                          = createMatch arity ['a'..'z'] patar
                            where
                              createMatch arity alpha patar
                               | elem 1 arity
                                   = (HsMatch loc0 pnt (createPat arity patar alpha) (HsBody (nameToExp ("added" ++ x))) []) : (createMatch (mutatearity arity) alpha patar)
                               | otherwise = []

                              mutatearity [] = []
                              mutatearity (x:xs)
                               | x == 1 = 0 : xs
                               | otherwise = x : (mutatearity xs)

                              createPat [] _ alpha= []
                              createPat (x:xs) ((y,n):ys) alpha
                               | x == 1    =  newPatt' : (createPat (replicate (length xs) 0) ys ((res4')))
                               | elem 1 y  = (conApps n) : (createPat xs ys (res3))
                               | otherwise = (createNames 1 alpha) ++ (createPat xs ys (tail alpha))
                                  where
                                    (_, res2) = splitAt numParam alpha
                                    conApps n = conApp y alpha n
                                    (_, res3) = splitAt ((myLength (conApps n)) * numParam -1) alpha

                                    (_, res4') = splitAt ((myLength newPatt') ) alpha
                                    newPatt' = patt alpha

                                    patt alpha
                                     | inf == False = (Pat (HsPParen (Pat (HsPApp newPNT (createNames numParam alpha))))::HsPatP)
                                     | otherwise    = (Pat (HsPInfixApp (nameToPat [alpha!!0]) newPNT (nameToPat [alpha!!1]))::HsPatP)

                                    conApp xs alpha name
                                      = (Pat (HsPParen (Pat (HsPApp (nameToPNT name) (createPats xs alpha)))))

                                    myLength (Pat (HsPParen (Pat (HsPApp _ xs)))) = length xs
                                    myLength _ = 0


                                    createPats [] alpha = []
                                    createPats (x:xs) alpha
                                     | x == 1 = newPatt : (createPats xs (res4))
                                     | otherwise = (createNames 1 alpha) ++ (createPats xs (tail alpha))
                                        where
                                         (_, res4) = splitAt ((myLength newPatt)) alpha
                                         newPatt = patt alpha

                                    createNames 0 _ = []
                                    createNames count (x:xs)
                                     = (nameToPat [x]) : (createNames (count-1) xs)

                        newPat (Exp (HsCase e pats@((HsAlt loc p e2 ds):ps)))
                          = Exp (HsCase e (newPats pats))

                        newPat2 (Exp (HsCase e pats))
                          = Exp (HsCase e (fst ++ newPat' ++ snd))
                             where
                              (fst, snd) = splitAt position pats


                        newPat3 (Exp (HsCase e pats)) posBefore
                          = Exp (HsCase e (newPats' pats posBefore))

                        newPats [] = newPat'
                        newPats(pa@(HsAlt _ p _ _):ps)
                         | wildOrID p = newPat' ++ (pa:ps)
                         | otherwise              = pa : (newPats ps)

                        newPats' [] posBefore = newPat'
                        newPats' (pa@(HsAlt _ p _ _):ps) posBefore
                         | (getPN p) == posBefore = pa : (newPat' ++ ps)
                         | wildOrID p = newPat' ++ (pa:ps)
                         | otherwise = pa : (newPats' ps posBefore)


                        newPat'
                         | numParam == 0 = [HsAlt loc0 (pNtoPat newPn) (HsBody (nameToExp ("added" ++ x))) [] ]
                         | otherwise = [HsAlt loc0 patt (HsBody (nameToExp ("added" ++ x))) []]
                            where
                             patt
                              | inf == False = (Pat (HsPParen (Pat (HsPApp newPNT  (createNames numParam ['a'..'z']))))::HsPatP)
                              | otherwise    = (Pat (HsPInfixApp (nameToPat "a") newPNT (nameToPat "b"))::HsPatP)

                             createNames 0 _ = []
                             createNames count (x:xs)
                               = (nameToPat [x]) : (createNames (count-1) xs)
-}

      --The selected sub-expression is in the argument list of a match
      --and the function only takes 1 parameter
    -- findFun dec@(Dec (HsFunBind loc matches)::HsDeclP) modName
    findFun :: GHC.LHsBind GHC.RdrName -> RefactGhc ((Bool, [t4]), [([t5], [Char])])
    findFun dec@(GHC.L _ (GHC.FunBind ln _ (GHC.MG matches _ _ _) _ _ _ )::GHC.LHsBind GHC.RdrName) = do
        return $ findMatch matches
           where findMatch match
                   = fromMaybe ((False, []), [([], "")])
                      (applyTU (once_tdTU (failTU `adhocTU` inMatch)) match)
                 inMatch ((GHC.Match _ [pat] ty grhss ) :: GHC.Match GHC.RdrName (GHC.LHsExpr GHC.RdrName))
                   = Just ((True, []), [([], "")])
                 -- inMatch (mat@(HsMatch loc1  pnt pats (HsBody e) ds)::HsMatchP)
                 --  = do
                 --       let (_, y) = checkTypesInPat datName pats modName fileName
                 --      -- error $ show y

                 --       Just ((checkTypes2 datName (pNTtoName pnt) modName fileName), y)

                 inMatch x@(_) = Nothing

    findFun a@(_) = return ((False, []), [([], "")])

    findCase :: GHC.LHsBind GHC.RdrName -> RefactGhc (Maybe (GHC.HsExpr GHC.RdrName))
    findCase dec@(GHC.L _ (GHC.FunBind ln _ (GHC.MG matches _ _ _) _ _ _ )::GHC.LHsBind GHC.RdrName) = do
      logDataWithAnns "findCase" matches
      -- logDataWithAnns "findCase" (findExp matches)
      return (findExp matches)
           where findExp alt
                  = fromMaybe Nothing
                     (applyTU (once_tdTU (failTU `adhocTU` inExp)) alt)
                 inExp (exp@e::GHC.HsExpr GHC.RdrName)
                  -- = Just ((findPat e), exp)
                  = Just (if (findPat e) then Just exp else Nothing)

                  where
                   -- findPat :: (SYB.Data t) => t -> Bool
                   findPat alt
                    = fromMaybe False
                      (applyTU (once_tdTU (failTU `adhocTU` inPat)) alt)
                   -- inPat (pat@(HsAlt loc (Pat (HsPId (HsCon p))) e ds)::HsAltP)
                   --   = (Just (checkTypes datName (pNTtoName p) modName fileName))
                   inPat :: GHC.LPat GHC.RdrName -> Maybe Bool
                   inPat (GHC.L lp (GHC.ConPatIn lx dets)) = do
                     if rdrName2NamePure nm lx `elem` oldPnames
                      then Just True
                      else Nothing
                   -- inPat e -- (pat@(HsAlt loc (Pat (HsPId (HsVar _))) e ds)::HsAltP)
                   --   = do
                   --       case exp of
                   --        Exp (HsCase (Exp (HsId (HsVar x))) alts)
                   --                                          -> do
                   --                                               -- find where p is defined, and get the type
                   --                                               let decs = hsDecls t
                   --                                               -- error ( show (pNTtoPN x))
                   --                                               let y = definingDecls [(pNTtoPN x)] decs False True
                   --                                               -- error $ show y
                   --                                               if length y /= 0
                   --                                                then do
                   --                                                 let b = definedPNs (head y)
                   --                                                 Just (checkTypes datName (pNtoName (head b)) modName fileName)
                   --                                                else  Nothing
                   --        _ -> Nothing
                   inPat e = error $ "findCase:inPat:" ++ (showGhc e) -- Nothing
                 -- inExp _ = Nothing
    findCase pat@(_) =  return Nothing



  
{-
findFuncs fileName datName t pnames newPn newPNT numParam oldPnames position inf (x:xs) modName
  =  applyTP (stop_tdTP (failTP `adhocTP` inFun)) t
    where
    inFun dec1
        = do
            (pat, exp1) <- findCase dec1 modName
            if pat /= False
             then do
                    let altPNs = getPNPats exp1
                    if oldPnames /= altPNs
                     then do
                      let posBefore = findPosBefore newPn pnames
                      update exp1 (newPat3 exp1 (head posBefore)) dec1
                     else do
                      update exp1 (newPat2 exp1) dec1

             else
              do ((match,arity), patar) <- findFun dec1 modName
                 if match == False
                   then do  --error "not found"
                       fail ""
                   else
                     do  let funPNs = getPNs dec1
                         if oldPnames /= funPNs
                           then do
                            let posBefore = findPosBefore newPn pnames
                            if length posBefore > 1
                             then do
                              update dec1 (newMatch3 dec1 (head posBefore) arity patar) dec1
                             else do
                              update dec1 (newMatch dec1 arity patar) dec1
                           else do
                           update dec1 (newMatch2 dec1 arity patar) dec1
                       where
                        newMatch (Dec (HsFunBind loc1 matches@((HsMatch _ pnt p e ds):ms)))  arity patar
                          =  Dec (HsFunBind loc1 (newMatches matches pnt arity patar (length p)))

                        newMatch2 (Dec (HsFunBind loc1 matches@((HsMatch _ pnt p e ds):ms) )) arity patar
                          = Dec (HsFunBind loc1 (fst ++ (newMatch' pnt arity patar(length p)) ++ snd) )
                            where
                              (fst, snd) = splitAt position matches

                        newMatch3 (Dec (HsFunBind loc1 matches@((HsMatch _ pnt p e ds):ms))) posBefore arity patar
                          = Dec (HsFunBind loc1 (newMatches' matches pnt posBefore arity patar (length p)))


                        newMatches [] pnt position arity patar = newMatch' pnt position arity patar
                        newMatches (m@(HsMatch _ _ pats _ _):ms) pnt position arity patar
                         | or (map wildOrID pats) = (newMatch' pnt position arity patar) ++ (m : ms)
                         | otherwise                     = m : (newMatches ms pnt position arity patar)

                        newMatches' [] pnt posBefore position arity patar = newMatch' pnt position arity patar
                        newMatches' (m@(HsMatch _ _ pats _ _):ms) pnt posBefore position arity patar
                         | (getPN pats) == posBefore = m : ((newMatch' pnt position arity patar) ++ ms)
                         | or (map wildOrID pats) = (newMatch' pnt position arity patar) ++ (m : ms)
      --                   | (TiDecorate.Pat HsPWildCard) `elem` pats = (newMatch' pnt) ++ (m : ms)
                         | otherwise      = m : (newMatches' ms pnt posBefore position arity patar)

                        newMatch' pnt arity  patar position
                  --       | numParam == 0  =  [HsMatch loc0 pnt [pNtoPat newPn] (HsBody (nameToExp ("added" ++ x))) []  ]
                          = createMatch arity ['a'..'z'] patar
                            where
                              createMatch arity alpha patar
                               | elem 1 arity
                                   = (HsMatch loc0 pnt (createPat arity patar alpha) (HsBody (nameToExp ("added" ++ x))) []) : (createMatch (mutatearity arity) alpha patar)
                               | otherwise = []

                              mutatearity [] = []
                              mutatearity (x:xs)
                               | x == 1 = 0 : xs
                               | otherwise = x : (mutatearity xs)

                              createPat [] _ alpha= []
                              createPat (x:xs) ((y,n):ys) alpha
                               | x == 1    =  newPatt' : (createPat (replicate (length xs) 0) ys ((res4')))
                               | elem 1 y  = (conApps n) : (createPat xs ys (res3))
                               | otherwise = (createNames 1 alpha) ++ (createPat xs ys (tail alpha))
                                  where
                                    (_, res2) = splitAt numParam alpha
                                    conApps n = conApp y alpha n
                                    (_, res3) = splitAt ((myLength (conApps n)) * numParam -1) alpha

                                    (_, res4') = splitAt ((myLength newPatt') ) alpha
                                    newPatt' = patt alpha

                                    patt alpha
                                     | inf == False = (Pat (HsPParen (Pat (HsPApp newPNT (createNames numParam alpha))))::HsPatP)
                                     | otherwise    = (Pat (HsPInfixApp (nameToPat [alpha!!0]) newPNT (nameToPat [alpha!!1]))::HsPatP)

                                    conApp xs alpha name
                                      = (Pat (HsPParen (Pat (HsPApp (nameToPNT name) (createPats xs alpha)))))

                                    myLength (Pat (HsPParen (Pat (HsPApp _ xs)))) = length xs
                                    myLength _ = 0


                                    createPats [] alpha = []
                                    createPats (x:xs) alpha
                                     | x == 1 = newPatt : (createPats xs (res4))
                                     | otherwise = (createNames 1 alpha) ++ (createPats xs (tail alpha))
                                        where
                                         (_, res4) = splitAt ((myLength newPatt)) alpha
                                         newPatt = patt alpha

                                    createNames 0 _ = []
                                    createNames count (x:xs)
                                     = (nameToPat [x]) : (createNames (count-1) xs)

                        newPat (Exp (HsCase e pats@((HsAlt loc p e2 ds):ps)))
                          = Exp (HsCase e (newPats pats))

                        newPat2 (Exp (HsCase e pats))
                          = Exp (HsCase e (fst ++ newPat' ++ snd))
                             where
                              (fst, snd) = splitAt position pats


                        newPat3 (Exp (HsCase e pats)) posBefore
                          = Exp (HsCase e (newPats' pats posBefore))

                        newPats [] = newPat'
                        newPats(pa@(HsAlt _ p _ _):ps)
                         | wildOrID p = newPat' ++ (pa:ps)
                         | otherwise              = pa : (newPats ps)

                        newPats' [] posBefore = newPat'
                        newPats' (pa@(HsAlt _ p _ _):ps) posBefore
                         | (getPN p) == posBefore = pa : (newPat' ++ ps)
                         | wildOrID p = newPat' ++ (pa:ps)
                         | otherwise = pa : (newPats' ps posBefore)


                        newPat'
                         | numParam == 0 = [HsAlt loc0 (pNtoPat newPn) (HsBody (nameToExp ("added" ++ x))) [] ]
                         | otherwise = [HsAlt loc0 patt (HsBody (nameToExp ("added" ++ x))) []]
                            where
                             patt
                              | inf == False = (Pat (HsPParen (Pat (HsPApp newPNT  (createNames numParam ['a'..'z']))))::HsPatP)
                              | otherwise    = (Pat (HsPInfixApp (nameToPat "a") newPNT (nameToPat "b"))::HsPatP)

                             createNames 0 _ = []
                             createNames count (x:xs)
                               = (nameToPat [x]) : (createNames (count-1) xs)

      --The selected sub-expression is in the argument list of a match
      --and the function only takes 1 parameter
    findFun dec@(Dec (HsFunBind loc matches)::HsDeclP) modName
        =  return $ findMatch matches
           where findMatch match
                   = fromMaybe ((False, []), [([], "")])
                      (applyTU (once_tdTU (failTU `adhocTU` inMatch)) match)
                 inMatch (mat@(HsMatch loc1  pnt pats (HsBody e) ds)::HsMatchP)
                  = do
                       let (_, y) = checkTypesInPat datName pats modName fileName
                      -- error $ show y

                       Just ((checkTypes2 datName (pNTtoName pnt) modName fileName), y)
                 inMatch x@(_) = Nothing
    findFun a@(_) _ = return ((False, []), [([], "")])

    findCase dec@(Dec (HsFunBind loc matches)::HsDeclP) modName
        = return (findExp matches)
           where findExp alt
                  = fromMaybe ((False, defaultExp))
                     (applyTU (once_tdTU (failTU `adhocTU` inExp)) alt)
                 inExp (exp@(Exp e)::HsExpP)
                  = Just ((findPat e), exp)

                  where
                   findPat alt
                    = fromMaybe (False)
                      (applyTU (once_tdTU (failTU `adhocTU` inPat)) alt)
                   inPat (pat@(HsAlt loc (Pat (HsPId (HsCon p))) e ds)::HsAltP)
                     = (Just (checkTypes datName (pNTtoName p) modName fileName))
                   inPat e -- (pat@(HsAlt loc (Pat (HsPId (HsVar _))) e ds)::HsAltP)
                     = do
                         case exp of
                          Exp (HsCase (Exp (HsId (HsVar x))) alts)
                                                            -> do
                                                                 -- find where p is defined, and get the type
                                                                 let decs = hsDecls t
                                                                 -- error ( show (pNTtoPN x))
                                                                 let y = definingDecls [(pNTtoPN x)] decs False True
                                                                 -- error $ show y
                                                                 if length y /= 0
                                                                  then do
                                                                   let b = definedPNs (head y)
                                                                   Just (checkTypes datName (pNtoName (head b)) modName fileName)
                                                                  else  Nothing
                          _ -> Nothing
                   -- inPat e = error (show e) -- Nothing
                 -- inExp _ = Nothing
    findCase pat@(_) _ =  return (False, defaultExp)

    findCase dec@(Dec (HsFunBind loc matches)::HsDeclP) modName
        = return (findExp matches)
           where findExp alt
                  = fromMaybe ((False, defaultExp))
                     (applyTU (once_tdTU (failTU `adhocTU` inExp)) alt)
                 inExp (exp@(Exp e)::HsExpP)
                  = Just ((findPat e), exp)

                  where
                   findPat alt
                    = fromMaybe (False)
                      (applyTU (once_tdTU (failTU `adhocTU` inPat)) alt)
                   inPat (pat@(HsAlt loc (Pat (HsPId (HsCon p))) e ds)::HsAltP)
                     = (Just (checkTypes datName (pNTtoName p) modName fileName))
                   inPat e -- (pat@(HsAlt loc (Pat (HsPId (HsVar _))) e ds)::HsAltP)
                     = do
                         case exp of
                          Exp (HsCase (Exp (HsId (HsVar x))) alts)
                                                            -> do
                                                                 -- find where p is defined, and get the type
                                                                 let decs = hsDecls t
                                                                 -- error ( show (pNTtoPN x))
                                                                 let y = definingDecls [(pNTtoPN x)] decs False True
                                                                 -- error $ show y
                                                                 if length y /= 0
                                                                  then do
                                                                   let b = definedPNs (head y)
                                                                   Just (checkTypes datName (pNtoName (head b)) modName fileName)
                                                                  else  Nothing
                          _ -> Nothing
                   -- inPat e = error (show e) -- Nothing
                 -- inExp _ = Nothing
    findCase pat@(_) _ =  return (False, defaultExp)
-}
-- ---------------------------------------------------------------------

-- | getPNs take a declaration and returns all the PNames within that declaration
-- getPNs :: HsDeclP -> [PName]
getPNs nm (GHC.L _ (GHC.FunBind ln _ (GHC.MG ms _ _ _) _ _ _ )::GHC.LHsBind GHC.RdrName)
 = checkMatch ms
    where
          checkMatch :: [GHC.LMatch GHC.RdrName (GHC.LHsExpr GHC.RdrName)] -> [GHC.Name]
          checkMatch [] = []
          checkMatch ((GHC.L _ (GHC.Match _ (p:ps) ty grhss )):ms)
            = (getPN p) ++ checkMatch ms
          getPN p = SYB.everything (++) ([] `SYB.mkQ` getCon) p
            where
              getCon :: GHC.LPat GHC.RdrName -> [GHC.Name]
              getCon (GHC.L _ (GHC.ConPatIn ln _)) = [rdrName2NamePure nm ln]
              getCon _                             = []
getPNs _ _ = []

-- ---------------------------------------------------------------------
{-
flatternPat :: HsPatP -> [HsPatP]
flatternPat (Pat (HsPAsPat i p)) = flatternPat p
flatternPat (Pat (HsPApp i p)) = (Pat (HsPId (HsCon i))) : (concatMap flatternPat p)
flatternPat (Pat (HsPTuple _ p)) = p
flatternPat (Pat (HsPList _ p)) = p
flatternPat (Pat (HsPInfixApp p1 i p2)) = (flatternPat p1) ++ (flatternPat p2)
flatternPat (Pat (HsPParen p)) = flatternPat p
flatternPat p@(Pat (HsPId i)) = [p]
flatternPat p = [p]

wildOrID (Pat HsPWildCard) = True
wildOrID (Pat (HsPId (HsVar x))) = True
wildOrID _ = False

doFileStuff fileName r c a = do
    s <- AbstractIO.readFile fileName

    -- get the first half of the file (up to point user has selected)
    let rev = reverse (returnHalf r c (1,1) s)
    let rest = returnSndHalf r c (1,1) s
    let str = parseIt rest a
    let str' = parseIt' rest a
    let len = length (myDiff s str')
    let (st, fin) = splitAt len s
    let new = st ++ str ++ fin
    let extraCol = parseTick 0 str
    let (col, row) = getRowCol r c (1,1) st

    -- Check that the file does not already exist first
    -- or else it will lead into strange errors...
    AbstractIO.catch (AbstractIO.writeFile (fileName ++ ".temp.hs") new)
                      (\_ -> do AbstractIO.removeFile (fileName ++ ".temp.hs")
                                AbstractIO.writeFile (fileName ++ ".temp.hs") new)

    if '`' `elem` a
      then do return (new, col + extraCol, row, True)
      else do return (new, col + extraCol, row, False)

-- function to parse to see if user is placing contructor at the beginning or end of statement...
-- if the user has selected a ' ' or a character
-- parse forwards (which is really backwards) until a '|' or a '=' character is found
parseTick _ [] = 3
parseTick count (x:xs)
 | x == '`' = count + 1
 | otherwise = parseTick (count+1) xs


myDiff :: String -> String -> String
myDiff [] _ = []
myDiff (y:ys) (x:xs)
 | (y:ys) == (x:xs) = ""
 | otherwise = y : (myDiff ys (x:xs))

parseIt :: String -> String -> String
parseIt "" str = error "Please select a position on the right hand side of the data type."
parseIt (x:xs) str
 | x == '\n' || x == '|' = " | " ++ str ++ " "
 | x /= '\n' || x /= '|' = parseIt xs str
 | otherwise            = " | " ++ str ++ " "

parseIt' :: String -> String -> String
parseIt' "" str = ""
parseIt' (x:xs) str
 | x == '\n' || x == '|' = (x:xs)
 | x /= '\n' || x /= '|' = parseIt' xs str
 | otherwise             = (x:xs)


-- perform some primitve parsing. We need to check where abouts the user wants
-- to add the data structure:
-- a) if the it is at the beginning - we need to check that the
--    use has selected at the end of a "=" sign -- if this is the case append "|" to the end
--    of the user string;
-- b) if a "=" does not proceed the position - append a "|" to the end
--
-- we do not need to check for any other cases as Programatica will pick up the errors
-- (if the position of adding the constructor is invalid, for example.)

-- function to return the half of the file that comes before the user position
returnHalf r c (col, row) "" = ""
returnHalf r c (col, row) (x:xs)
  | x == '\n' = if (r == row) && (c == col)   then [x]
                                              else x : (returnHalf r c (1, row+1) xs)
  | otherwise = if c == col && (r == row)     then [x]
                                              else x : (returnHalf r c (col+1, row) xs)

returnSndHalf r c (col, row) "" = ""
returnSndHalf r c (col, row) (x:xs)
  | x == '\n' = if (r == row) && (c == col)   then xs
                                              else (returnSndHalf r c (1, row+1) xs)
  | otherwise = if c == col && (r == row)     then xs
                                              else (returnSndHalf r c (col+1, row) xs)

getRowCol r c (col, row) "" = (col, row)
getRowCol r c (col, row) (x:xs)
 | x == '\n' = getRowCol r c (1, row+1) xs
 | otherwise = getRowCol r c (col+1, row) xs


{-|
Takes the position of the highlighted code and returns
the function name, the list of arguments, the expression that has been
highlighted by the user, and any where\/let clauses associated with the
function.
-}

findDefNameAndExp :: Term t => [PosToken] -- ^ The token stream for the
                                          -- file to be
                                          -- refactored.
                  -> (Int, Int) -- ^ The beginning position of the highlighting.
                  -> (Int, Int) -- ^ The end position of the highlighting.
                  -> t          -- ^ The abstract syntax tree.
                  -> [HsConDeclP]  -- ^ A tuple of,
                     -- (the function name, the list of arguments,
                     -- the expression highlighted, any where\/let clauses
                     -- associated with the function).

findDefNameAndExp toks beginPos endPos t
  = fromMaybe ([])
              (applyTU (once_tdTU (failTU `adhocTU` inData)) t)
    where
      --The selected sub-expression is the rhs of a data type
      inData (dat@(HsConDecl loc1 is con i xs)::HsConDeclP)
       = error (show res)
            where
               res = pNtoExp (pNTtoPN i)
      inData _ = Nothing
-}
