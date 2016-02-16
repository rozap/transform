module PrimitiveEditors where

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Json.Decode as JsDec
import String

import StartApp.Simple as StartApp


bool : Signal.Address Bool -> Bool -> Html
bool addr currentValue =
  input
    [ type' "checkbox"
    , on
        "change"
        (JsDec.at ["target", "checked"] JsDec.bool)
        (Signal.message addr)
    , checked currentValue
    ]
    [ text (toString currentValue) ]


string : Signal.Address String -> Int -> String -> Html
string addr width currentValue =
  input
    [ on "input" (targetValue JsDec.string) (Signal.message addr)
    , value currentValue
    , size width
    ]
    []


int : Signal.Address Int -> Int -> Html
int addr currentValue =
  input
    [ on
        "input"
        (targetValue (JsDec.customDecoder JsDec.string String.toInt))
        (Signal.message addr)
    , type' "number"
    , step "1"
    , value (toString currentValue)
    ]
    []


targetValue : JsDec.Decoder a -> JsDec.Decoder a
targetValue decoder =
  JsDec.at ["target", "value"] decoder


selector : Signal.Address String -> List String -> String -> Html
selector addr options curVal =
  select
    [ on
        "change"
        (JsDec.at
          ["target", "value"]
          JsDec.string)
        (Signal.message addr)
    ]
    (options |> List.map (\opt ->
      option
        [ selected (opt == curVal) ]
        [ text opt ]
    ))

-- this provides an outline of editing a record type...


type alias Model =
  { str : String
  , b : Bool
  , i : Int
  }


type Action
  = EditString String
  | EditBool Bool
  | EditInt Int


view : Signal.Address Action -> Model -> Html
view addr model =
  div
    []
    [ p [] [bool (Signal.forwardTo addr EditBool) model.b]
    , p [] [string (Signal.forwardTo addr EditString) 3 model.str]
    , p [] [int (Signal.forwardTo addr EditInt) model.i]
    ]


update : Action -> Model -> Model
update action model =
  case action of
    EditString str ->
      { model | str = str }

    EditBool b ->
      { model | b = b }

    EditInt i ->
      { model | i = i }


main =
  StartApp.start
    { model =
        { i = 0
        , str = ""
        , b = True
        }
    , view = view
    , update = update
    }
