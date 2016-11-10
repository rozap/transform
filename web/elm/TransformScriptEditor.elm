module TransformScriptEditor exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.App
import Dict

import Model exposing (..)
import StepEditor
import Util

type alias Model =
  TransformScript


type Msg
  = AddStep Step
  | UpdateStepAt Int StepEditor.Action
  | RemoveStep Int -- index


update : Msg -> TransformScript -> Model
update msg transformScript =
  case msg of
    AddStep step ->
      transformScript ++ [step]

    UpdateStepAt idx action ->
      transformScript
      |> Util.updateAt (StepEditor.update action) idx
      |> Util.getMaybe "idx out of range"

    RemoveStep idx ->
      Util.removeAt idx transformScript


view : Schema -> TransformScript -> Html Msg
view columnNames transformScript =
  let
    (increments, finalMapping) =
      scriptToMapping columnNames transformScript
    
    scriptWithIncrements =
      List.map2 (,) transformScript increments

    closeButton idx =
      button
        [ onClick (RemoveStep idx) ]
        [ text "x" ]

    viewStep idx (step, (beforeMapping, maybeError)) =
      li []
        [ closeButton idx
        , text " "
        , Html.App.map
            (UpdateStepAt idx)
            (StepEditor.view
              beforeMapping
              step)
        , text " "
        , maybeError
          |> Maybe.map (\err ->
            span
              [ style [("color", "red")] ]
              [ text (toString err) ]
          )
          |> Maybe.withDefault (span [] [])
        ]

    steps =
      case scriptWithIncrements of
        [] ->
          p [style [("font-style", "italic")]] [text "identity transform"]

        _ ->
          scriptWithIncrements
          |> List.indexedMap viewStep
          |> ul []
    
    firstFunName =
          Model.functions
          |> Dict.keys
          |> List.head
          |> Util.getMaybe "no functions"

    defaultArgs =
      StepEditor.defaultArgsFor firstFunName
  in
    div []
      [ steps
      , button
          [ onClick
              (AddStep (ApplyFunction "someCol" firstFunName defaultArgs))
          ]
          [ text "Add Function" ] 
      ]
