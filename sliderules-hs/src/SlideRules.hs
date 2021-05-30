module SlideRules where

-- default
import Data.Default

-- diagrams-*
import qualified Diagrams.Backend.SVG         as D
import qualified Diagrams.Backend.SVG.CmdLine as D
import qualified Diagrams.Prelude             as D
import qualified Diagrams.TwoD.Text           as D
import qualified Diagrams.TwoD.Vector         as D

-- local (sliderules)
import SlideRules.Generator
import SlideRules.Lenses
import SlideRules.Tick
import SlideRules.Transformations
import SlideRules.Types
import SlideRules.Utils

ex100 :: Generator ()
ex100 =
    postTransform (Log 10) $
    withInfo (\f x -> (f x) { _mlabel = Just (def { _fontSize = 0.3, _text = show x }) }) $
    together
        [ do
            x <- list [1..9]
            output x
            withInfo (\f x -> (f x) { _end = 0.5, _mlabel = Nothing }) $
                preTransform (Offset x) $ preTransform (Scale 0.1) $ do
                    x <- list [1..9]
                    output x
        , output 10
        , withInfo (\f x -> (f x) { _start = 0.5, _end = 0.6, _mlabel = Just (def { _fontSize = 0.3, _text = "π" }) })
            (output pi)
        , withInfo (\f x -> (f x) { _start = 0.5, _end = 0.6, _mlabel = Just (def { _fontSize = 0.3, _text = "e" }) })
            (output e)
        ]

renderSlide :: Generator a -> D.Diagram D.B
renderSlide generator =
    let ticks = foldMap (renderTick False) $ _out $ generate generator
    in
    ticks <> laserline [D.r2 (0, 0), D.r2 (1, 0)]

total :: D.Diagram D.B
total = D.bgFrame 0.025 D.white $ D.vsep 0.02 [ renderSlide ex100 ]
