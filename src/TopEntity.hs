------------------------------------------------------------------------------
-- |
-- Module :  TopEntity
--
-- Simple demo application using the iceBlinkHX1K evaluation kit and
-- the Kitchen Timer extension board.
--
-----------------------------------------------------------------------------

{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RecordWildCards #-}

module TopEntity where

import OtherModule()
import Clash.Prelude

-----------------------------------------------------------------------------

type Pulse       = Bool
type Buzzr       = Bool
type ButtonPress = Bool
type Segment     = BitVector 7
type Display     = Vec 4 Segment
type Digit       = Index 10

-----------------------------------------------------------------------------

data Mode = Add | Mul
  deriving (Generic, NFDataX, Eq)

data State = State
  { mode :: Mode
  , v1 :: Digit
  , v2 :: Digit
  }
  deriving (Generic, NFDataX)

-----------------------------------------------------------------------------

topEntity ::
  HiddenClock System =>
  HiddenReset System =>
  Signal System ButtonPress ->
  Signal System ButtonPress ->
  Signal System ButtonPress ->
  Signal System (Display, Buzzr)
topEntity bL bM bR = withEnable enableGen $
  let
    (digits, buzz) =
      mealyB transF initialState
        (debounce bL, debounce bM, debounce bR)
  in
    bundle
      ( map fromDigit <$> digits
      , buzzer buzz
      )
 where
   initialState = State Add 0 0

   transF state (btnL, btnM, btnR) =
     let
       State{..} = upd state btnL btnM btnR

       result :: Index 100
       result = case mode of
         Add -> extend v1 + extend v2
         Mul -> extend v1 * extend v2

       dsp = v1
          :> v2
          :> truncateB (result `div` 10)
          :> truncateB (result `mod` 10)
          :> Nil
     in
       (State{..}, (dsp, btnL || btnM || btnR))

   upd State{..} btnL btnM btnR = State
     { mode = if btnR then flipMode mode      else mode
     , v1   = if btnM then satSucc SatWrap v1 else v1
     , v2   = if btnL then satSucc SatWrap v2 else v2
     }

   flipMode = \case
     Add -> Mul
     Mul -> Add

{-# NOINLINE topEntity #-}
{-# ANN topEntity (
  Synthesize
    { t_name    = "Demo"
    , t_inputs  =
        [ PortName "CLOCK"
        , PortName "RESET"
        , PortName "BTN_L"
        , PortName "BTN_M"
        , PortName "BTN_R"
        ]
    , t_output =
        PortProduct ""
          [ PortProduct ""
              [ PortName "D0"
              , PortName "D1"
              , PortName "D2"
              , PortName "D3"
              ]
          , PortName "BUZZR"
          ]
    }
  )
  #-}

-----------------------------------------------------------------------------

debounce ::
  HiddenClockResetEnable dom  =>
  Signal dom Bool -> Signal dom Pulse
debounce = isRising False . glitchFilter
 where
  glitchFilter =
    let
      transF (s, c) i
        | c < maxBound = (s, satSucc SatBound c)
        | i == s       = (s, maxBound)
        | otherwise    = (i, minBound)
    in
      moore transF fst (False, minBound :: Index 1666)

-----------------------------------------------------------------------------

buzzer ::
  HiddenClockResetEnable dom =>
  Signal dom Bool -> Signal dom Bool
buzzer trigger =
  mux (mealy transF (False, minBound :: Index 139000) trigger)
#ifdef PASSIVEBUZZER
      beepFreq
#else
      (pure True)
#endif
      (pure False)
 where
  transF (hold, c) trig =
    let
      squarewave x =
           x <   19000
        || x >=  40000 && x <  59000
        || x >=  80000 && x <  99000
        || x >= 120000 && x < 139000

      hold' = hold && c < 40000 || trig && c < 320000

      c' | hold'     = satSucc SatBound c
         | otherwise = minBound
    in
      ((hold', c'), hold' && squarewave c)

-----------------------------------------------------------------------------

#ifdef PASSIVEBUZZER
beepFreq ::
  HiddenClockResetEnable dom =>
  Signal dom Buzzr
beepFreq = moore transF fst (False, minBound :: Index 36) $ pure ()
 where
  transF (s, c) _
    | c < maxBound = (s, satSucc SatBound c)
    | otherwise    = (not s, minBound)
#endif

-----------------------------------------------------------------------------

fromDigit :: Digit -> Segment
fromDigit = \case
  0 -> 0b0001000    --
  1 -> 0b1011011    --    --0--
  2 -> 0b0100010    --   |     |
  3 -> 0b0010010    --   1     2
  4 -> 0b1010001    --   |     |
  5 -> 0b0010100    --    --3--
  6 -> 0b0000100    --   |     |
  7 -> 0b1011010    --   4     5
  8 -> 0b0000000    --   |     |
  9 -> 0b0010000    --    --6--
  _ -> 0b1111111    --

-----------------------------------------------------------------------------
