module PrimitiveEditors exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Html.App
import Json.Decode as JsDec
import String


bool : Bool -> Html Bool
bool currentValue =
  input
    [ type' "checkbox"
    , on
        "change"
        (JsDec.at ["target", "checked"] JsDec.bool)
    , checked currentValue
    ]
    [ text (toString currentValue) ]


string : (List (Attribute String)) -> String -> Html String
string attributes currentValue =
  input
    ( [ on "input" (targetValue JsDec.string)
      , value currentValue
      ]
    ++ attributes
    )
    []


int : Int -> Html Int
int currentValue =
  input
    [ on
        "input"
        (targetValue (JsDec.customDecoder JsDec.string String.toInt))
    , type' "number"
    , step "1"
    -- size has no effect http://stackoverflow.com/questions/22709792/html-input-type-number-wont-resize
    , value (toString currentValue)
    ]
    []


targetValue : JsDec.Decoder a -> JsDec.Decoder a
targetValue decoder =
  JsDec.at ["target", "value"] decoder


-- TODO: if curVal is not in options, show it anyway?
selector : List String -> String -> Html String
selector options curVal =
  select
    [ on
        "change"
        (JsDec.at
          ["target", "value"]
          JsDec.string)
    ]
    (""::options |> List.map (\opt ->
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


-- view : Model -> Html Action
-- view addr model =
--   div
--     []
--     [ p [] [bool (Html.App.map addr EditBool) model.b]
--     , p [] [string (Html.App.map addr EditString) [size 3] model.str]
--     , p [] [int (Html.App.map addr EditInt) model.i]
--     ]


-- update : Action -> Model -> Model
-- update action model =
--   case action of
--     EditString str ->
--       { model | str = str }

--     EditBool b ->
--       { model | b = b }

--     EditInt i ->
--       { model | i = i }


-- main =
--   Html.App.beginnerProgram
--     { model =
--         { i = 0
--         , str = ""
--         , b = True
--         }
--     , view = view
--     , update = update
--     }
