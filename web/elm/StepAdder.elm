module StepAdder where

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)

import Model exposing (..)
import Util exposing (..)
import PrimitiveEditors


type alias Model =
  Maybe StepEditor


initModel =
  Nothing


type StepEditor
  = ConcatEditor Concat


type alias Concat =
  { args : List ConcatArg
  , resultName : ColumnName
  }


type ConcatArg
  = ColumnArg ColumnName
  | ConstantArg String


type Action
  = Cancel
  | AddConcat
  | ConcatAction ConcatAction
  | AddIt


type ConcatAction
  = AddColumn
  | AddConst
  | RemoveArg Int
  | UpdateConstant Int String
  | UpdateColumn Int ColumnName
  | UpdateResultName String


update : Action -> List ColumnName -> Model -> (Model, Maybe Step)
update action columns model =
  let
    noGo x =
      (x, Nothing)
  in
  case action of
    Cancel ->
      noGo Nothing

    AddIt ->
      case model of
        Nothing ->
          Debug.crash "unexpected action"

        Just (ConcatEditor concat) ->
          let
            args =
              concat.args
              |> List.map (\arg ->
                case arg of
                  ColumnArg col ->
                    SourceColumn col

                  ConstantArg const ->
                    StringLit const
              )
          in
            (Nothing, Just (ApplyFunction concat.resultName "concat" args))
            --(Nothing, Just (DropColumn "foo"))

    AddConcat ->
      case model of
        Nothing ->
          Just
            (ConcatEditor
              { args =
                [ ConstantArg ""
                , ColumnArg (List.head columns |> getMaybe "no columns")
                , ConstantArg ""
                ]
              , resultName = "concat" ++ (List.head columns |> getMaybe "no columns")
              }
            )
          |> noGo

        Just _ ->
          Debug.crash "unexpected action"

    ConcatAction concatAction ->
      case model of
        Nothing ->
          Debug.crash "unexpected action"

        Just (ConcatEditor concat) ->
          case concatAction of
            AddColumn ->
              Just
                (ConcatEditor
                  { concat | args = concat.args ++
                    [ColumnArg (List.head columns |> getMaybe "no columns")]
                  })
              |> noGo

            AddConst ->
              Just
                (ConcatEditor
                  { concat | args = concat.args ++
                    [ConstantArg ""]
                  })
              |> noGo

            RemoveArg idx ->
              Just (ConcatEditor { concat | args = concat.args |> removeAt idx })
              |> noGo

            UpdateConstant idx newVal ->
              Just
                (ConcatEditor
                  { concat | args =
                      (concat.args
                      |> setAt (ConstantArg newVal) idx
                      |> getMaybe "invalid index")
                  })
              |> noGo

            UpdateColumn idx newVal ->
              Just
                (ConcatEditor
                  { concat | args =
                      (concat.args
                      |> setAt (ColumnArg newVal) idx
                      |> getMaybe "invalid index")
                  })
              |> noGo

            UpdateResultName newName ->
              Just (ConcatEditor {concat | resultName = newName })
              |> noGo


viewConcatEditor : Signal.Address ConcatAction -> List ColumnName -> Concat -> Html
viewConcatEditor addr columns concat =
  span
    []
    ([ text "concat " ] ++
      (List.indexedMap (\idx arg -> viewConcatArg addr columns idx arg) concat.args) ++
      [ text " as " ] ++
      [PrimitiveEditors.string (Signal.forwardTo addr UpdateResultName) 15 concat.resultName] ++
      [ button [ onClick addr AddConst ] [text "+ const"]
      , button [ onClick addr AddColumn ] [text "+ col"]
      ]
    )


viewConcatArg : Signal.Address ConcatAction -> List ColumnName -> Int -> ConcatArg -> Html
viewConcatArg addr columns idx arg =
  case arg of
    ConstantArg const ->
      PrimitiveEditors.string (Signal.forwardTo addr (UpdateConstant idx)) 3 const

    ColumnArg name ->
      PrimitiveEditors.selector (Signal.forwardTo addr (UpdateColumn idx)) columns name


view : Signal.Address Action -> List ColumnName -> Model -> Html
view addr columns model =
  case model of
    Nothing ->
      button
        [ onClick addr AddConcat ]
        [ text "+ Concat" ]

    Just editor ->
      case editor of
        ConcatEditor concat ->
          div []
            [ viewConcatEditor (Signal.forwardTo addr ConcatAction) columns concat
            , br [] []
            , button [onClick addr AddIt] [text "Add"]
            , a [ href "#", onClick addr Cancel ] [text "cancel"]
            ]
