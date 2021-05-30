{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleContexts #-}
module SlideRules.Generator where

-- base
import qualified Data.Sequence as S

-- default
import Data.Default

-- lens
import Control.Lens.Combinators hiding (each)
import Control.Lens.Operators
import Control.Lens.TH (makeLenses)

-- mtl
import Control.Monad.State

-- pipes
import Pipes
import qualified Pipes.Prelude as PP

-- local (sliderules)
import SlideRules.Lenses
import SlideRules.Tick
import SlideRules.Transformations
import SlideRules.Types
import SlideRules.Utils

type Generator = ListT (State GenState)

data GenState = GenState
    { _preTransformations  :: [Transformation]
    , _postTransformations :: [Transformation]
    , _tickCreator         :: InternalFloat -> TickInfo
    , _out                 :: S.Seq Tick
    }
    -- deriving (Show)

makeLenses ''GenState

generate :: Generator a -> GenState
generate act = execState (runListT act) def

summarize :: Generator a -> [(String, InternalFloat, InternalFloat)]
summarize = foldMap summarize1 . _out . generate
    where
        summarize1 tick =
            case tick ^. info . mlabel of
                Nothing -> []
                Just label -> [(label ^. text, tick ^. prePos, tick ^. postPos)]

genTick :: InternalFloat -> GenState -> Maybe Tick
genTick x s = do
    _prePos <- runTransformations (_preTransformations s) x
    let _info = _tickCreator s _prePos
    _postPos <- runTransformations (_postTransformations s) _prePos
    pure $ Tick { _info, _prePos, _postPos }

instance Default GenState where
    def = GenState [] [] (const def) $ S.fromList []

together :: [Generator a] -> Generator a
together = join . Select . each

list :: [a] -> Generator a
list = Select . each

withPrevious :: Lens' GenState a -> (a -> a) -> Generator b -> Generator b
withPrevious lens f action = do
    previous <- use lens
    Right res <- together
        [ fmap Left $ lens %= f
        , fmap Right action
        , fmap Left $ lens .= previous
        ]
    return res

preTransform :: Transformation -> Generator a -> Generator a
preTransform transformation = withPrevious preTransformations (transformation :)

postTransform :: Transformation -> Generator a -> Generator a
postTransform transformation = withPrevious postTransformations (transformation :)

withTickCreator :: ((InternalFloat -> TickInfo) -> InternalFloat -> TickInfo) -> Generator a -> Generator a
withTickCreator handlerF = withPrevious tickCreator handlerF

withInfoX :: (TickInfo -> InternalFloat -> TickInfo) -> Generator a -> Generator a
withInfoX handlerF = withTickCreator (\f x -> handlerF (f x) x)

withInfo :: (TickInfo -> TickInfo) -> Generator a -> Generator a
withInfo handlerF = withInfoX (\info _ -> handlerF info)

output :: InternalFloat -> Generator ()
output x = do
    Just tick <- gets $ genTick x
    out <>= S.fromList [tick]
