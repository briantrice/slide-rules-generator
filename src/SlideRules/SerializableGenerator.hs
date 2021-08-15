{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleInstances #-}
module SlideRules.SerializableGenerator where

-- aeson
import Data.Aeson
import qualified Data.Aeson.Parser as Parser

-- base
import GHC.Generics

-- decimal
import Data.Decimal

-- lens
import Control.Lens (use, (%~), (.~))

-- scientific
import Data.Scientific

-- local (sliderules)
import SlideRules.Generator
import SlideRules.Partitions
import SlideRules.Renderer
import SlideRules.Scales as Scales
import SlideRules.Transformations
import SlideRules.Types
import SlideRules.Tick
import SlideRules.Utils

data SerializableTickIdentifier
    = FloorIdentifier { leeway :: InternalFloat, lower :: Integer, upper :: Integer }
    | DefaultIdentifier
    deriving (Show, Generic)

instance ToJSON SerializableTickIdentifier
instance FromJSON SerializableTickIdentifier

deserializeTickIdentifier :: SerializableTickIdentifier -> TickIdentifier
deserializeTickIdentifier FloorIdentifier{ leeway, lower, upper } = floorIdentifier leeway (lower, upper)
deserializeTickIdentifier DefaultIdentifier = defaultIdentifier

data SerializableOffsetter
    = SLinear { height :: InternalFloat }
      -- ^ Hardcoded vertical offset h
    | SIncline { intercept :: InternalFloat, slope :: InternalFloat }
      -- ^ Incline with intercept (initial value) i, slope s
    | SRadial { radius :: InternalFloat }
      -- ^ Hardcoded radius r
    | SSpiral { radius :: InternalFloat, velocity :: InternalFloat }
      -- ^ Starting radius r, velocity v
    deriving (Show, Generic)

instance ToJSON SerializableOffsetter
instance FromJSON SerializableOffsetter

deserializeOffsetter :: SerializableOffsetter -> Offsetter
deserializeOffsetter SLinear{ height } = linear height
deserializeOffsetter SIncline{ intercept, slope } = incline intercept slope
deserializeOffsetter SRadial{ radius } = radial radius
deserializeOffsetter SSpiral{ radius, velocity } = spiral radius velocity

data SerializableGenerator
    = HardcodedPoints { transformations :: [Transformation], controlPoints :: [Scientific] }
    | SmartPartitionTens { transformations :: [Transformation], controlPoints :: [Scientific] }
    deriving (Show, Generic)

instance ToJSON SerializableGenerator
instance FromJSON SerializableGenerator

deserializeGenerator :: SerializableGenerator -> Generator ()
deserializeGenerator (HardcodedPoints { transformations, controlPoints }) =
    withs (postTransform <$> transformations) $ do
        traverse output $ scientificToInternalFloat <$> controlPoints
        pure ()
deserializeGenerator (SmartPartitionTens { transformations, controlPoints }) =
    withs (postTransform <$> transformations) $ do
        smartPartitionTens smartHandler $ scientificToDecimal <$> controlPoints
        pure ()

data SerializableScaleSpec = SerializableScaleSpec
    { baseTolerance :: InternalFloat
    , serializableTickIdentifier :: SerializableTickIdentifier
    , serializableGenerator :: SerializableGenerator
    , serializableOffsetter :: SerializableOffsetter
    , renderSettings :: RenderSettings
    }
    deriving (Show, Generic)

instance ToJSON SerializableScaleSpec
instance FromJSON SerializableScaleSpec

deserializeScaleSpec :: SerializableScaleSpec -> ScaleSpec
deserializeScaleSpec SerializableScaleSpec {..} =
    ScaleSpec
        { baseTolerance = baseTolerance
        , tickIdentifier = deserializeTickIdentifier serializableTickIdentifier
        , generator = deserializeGenerator serializableGenerator
        , offsetter = deserializeOffsetter serializableOffsetter
        , renderSettings = renderSettings
        }

-- Partitioning handler
smartHandler 1 = trees10
smartHandler 10 = trees10
smartHandler n = [treeN n]

partN n h = Partition n 0 $ fromInfo (end %~ (h*) <<< mlabel .~ Nothing)
treeN n = OptionTree [partN n 0.5] [(0, n - 1, trees10)]
trees10 =
    [ OptionTree [partN 2 0.75, partN 5 0.66] [(0, 9, trees10)]
    , OptionTree [partN 5 0.5] []
    , OptionTree [partN 2 0.5] []
    ]

-----------------------------------------------------------
-- Orphan instances for sliderules library datatypes
-----------------------------------------------------------

instance ToJSON Transformation
instance FromJSON Transformation

instance ToJSON RenderSettings
instance FromJSON RenderSettings

instance FromJSON Decimal where
    parseJSON = withScientific "Decimal" (pure . scientificToDecimal)

instance ToJSON Decimal where
    toJSON = toJSON . decimalToScientific

instance FromJSON InternalFloat where
    parseJSON = withScientific "Decimal" (pure . scientificToInternalFloat)

instance ToJSON InternalFloat where
    toJSON = toJSON . internalFloatToScientific

-----------------------------------------------------------
-- Conversion from Scientific
-----------------------------------------------------------

scientificToDecimal :: Scientific -> Decimal
scientificToDecimal s = Decimal (fromIntegral $ base10Exponent s) (coefficient s)

decimalToScientific :: Decimal -> Scientific
decimalToScientific d = scientific (decimalMantissa d) (fromIntegral $ decimalPlaces d)

scientificToInternalFloat :: Scientific -> InternalFloat
scientificToInternalFloat = realToFrac

internalFloatToScientific :: InternalFloat -> Scientific
internalFloatToScientific = realToFrac

instance FromJSON Decimal where
    parseJSON = withScientific "Decimal" (pure . scientificToDecimal)

instance ToJSON Decimal where
    toJSON = toJSON . decimalToScientific

instance FromJSON InternalFloat where
    parseJSON = withScientific "Decimal" (pure . scientificToInternalFloat)

instance ToJSON InternalFloat where
    toJSON = toJSON . internalFloatToScientific

