-- | A "classic" (i.e. as seen in the specification) way to pretty-print PLC entities.

{-# OPTIONS_GHC -fno-warn-orphans #-}

{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE UndecidableInstances  #-}

module Language.PlutusCore.Core.Instance.Pretty.Classic () where

import           PlutusPrelude

import           Language.PlutusCore.Core.Instance.Pretty.Common ()
import           Language.PlutusCore.Core.Instance.Recursive
import           Language.PlutusCore.Core.Type
import           Language.PlutusCore.Pretty.Classic
import           Language.PlutusCore.Universe

import           Data.Functor.Foldable

instance PrettyBy (PrettyConfigClassic configName) (Kind a) where
    prettyBy _ = cata a where
        a TypeF{}             = "(type)"
        a (KindArrowF _ k k') = parens ("fun" <+> k <+> k')

instance (PrettyClassicBy configName (tyname a), GShow uni) =>
        PrettyBy (PrettyConfigClassic configName) (Type tyname uni a) where
    prettyBy config = cata a where
        a (TyAppF _ t t')     = brackets (t <+> t')
        a (TyVarF _ n)        = prettyName n
        a (TyFunF _ t t')     = parens ("fun" <+> t <+> t')
        a (TyIFixF _ pat arg) = parens ("ifix" <+> pat <+> arg)
        a (TyForallF _ n k t) = parens ("all" <+> prettyName n <+> prettyBy config k <+> t)
        a (TyBuiltinF _ n)    = parens ("con" <+> pretty n)
        a (TyLamF _ n k t)    = parens ("lam" <+> prettyName n <+> prettyBy config k <+> t)

        prettyName = prettyBy config

instance
        ( PrettyClassicBy configName (tyname a)
        , PrettyClassicBy configName (name a)
        , GShow uni, Closed uni, uni `Everywhere` Pretty
        ) => PrettyBy (PrettyConfigClassic configName) (Term tyname name uni a) where
    prettyBy config = cata a where
        a (ConstantF _ b)      = parens' ("con" </> pretty b)
        a (BuiltinF _ bi)      = parens' ("builtin" </> pretty bi)
        a (ApplyF _ t t')      = brackets' (vsep' [t, t'])
        a (VarF _ n)           = prettyName n
        a (TyAbsF _ n k t)     = parens' ("abs" </> vsep' [prettyName n, prettyBy config k, t])
        a (TyInstF _ t ty)     = braces' (vsep' [t, prettyBy config ty])
        -- FIXME: only do the </> thing when there's a line break in the `vsep'` part?
        a (LamAbsF _ n ty t)   = parens' ("lam" </> vsep' [prettyName n, prettyBy config ty, t])
        a (UnwrapF _ t)        = parens' ("unwrap" </> t)
        a (IWrapF _ pat arg t) = parens' ("iwrap" </> vsep' [prettyBy config pat, prettyBy config arg, t])
        a (ErrorF _ ty)        = parens' ("error" </> prettyBy config ty)

        prettyName :: PrettyClassicBy configName n => n -> Doc ann
        prettyName = prettyBy config

instance PrettyClassicBy configName (Term tyname name uni a) =>
        PrettyBy (PrettyConfigClassic configName) (Program tyname name uni a) where
    prettyBy config (Program _ version term) =
        parens' $ "program" <+> pretty version <//> prettyBy config term
