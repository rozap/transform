module Main where

import String
import Task exposing (Task)
import Dict exposing (Dict)
import Json.Decode as JsDec

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy
import StartApp
import Effects exposing (Effects, Never)
import Html.Events.Extra

import Model exposing (..)
import Table exposing (Table)
import Util
import StepAdder


type alias Model =
  { transformScript : TransformScript
  , errors : List String
  , table : Maybe (TransformScript, Table)
  , rowsProcessed : Int
  , aggregates : List (ColumnName, JsDec.Value)
  , stepAdderState : StepAdder.Model
  }


type Action
  = AddStep Step
  | RemoveStep Int -- index
  | StepAdderAction StepAdder.Action
  | ServerEvent ServerEvent
  | NoOp


type ServerEvent
  = ProgressEvent Int
  | ErrorsEvent (List String)
  | TransformChunkEvent (List (List (ColumnName, String)))
  | AggregateUpdate (List (ColumnName, JsDec.Value))


type alias Histogram =
  Dict String Int


initModel =
  { transformScript = []
  , errors = []
  , table = Nothing
  , rowsProcessed = 0
  , aggregates = []
  , stepAdderState = StepAdder.initModel
  }


view : Signal.Address Action -> Model -> Html
view addr model =
  div []
    [ div [ class "pure-g" ]
      [ div [ class "pure-u-1-3" ]
          [ viewTransformEditor addr model
          , button
              [ disabled
                  (model.table
                    |> Maybe.map (\(tableScript, _) ->
                      tableScript == model.transformScript)
                    |> Maybe.withDefault False
                  )
              ]
              [ text "Save Transform & Get Preview" ]
          ]
      , div [ class "pure-u-1-3", id "errors" ]
          [ viewErrors model ]
      , div [ class "pure-u-1-3", id "upload" ]
          []
      , div [ class "pure-u-1-1" ]
          [ viewProgress model ]
      ]
    , table [ id "histograms" ] []
    , div [ id "results" ]
        [ Html.Lazy.lazy viewTable model ]
    ]


viewProgress : Model -> Html
viewProgress model =
  let
    goodRows =
      model.rowsProcessed

    badRows =
      List.length model.errors

    totalRows =
      goodRows + badRows
  in
    text <|
      toString goodRows ++ " good rows + " ++ toString badRows ++ " bad rows = " ++ toString totalRows ++ " total"


viewTable : Model -> Html
viewTable model =
  case model.table of
    Nothing ->
      p [] [text "No results yet"]

    Just (_, theTable) ->
      let
        header =
          theTable.columnNames
          |> List.map (\name -> th [] [text name])

        rows =
          theTable.rows
          |> List.map (\row ->
            tr []
              (row |> List.map (\col -> td [] [text col]))
          )
      in
        table
          []
          [ thead []
              [ tr []
                  header
              ]
          , tbody []
              rows
          , text <| toString model.aggregates
          ]


viewErrors : Model -> Html
viewErrors model =
  model.errors
  |> List.map (\error -> li [] [text error])
  |> ul [class "errors"]


viewTransformEditor : Signal.Address Action -> Model -> Html
viewTransformEditor addr model =
  let
    (stepErrors, mapping) =
      stepsToMapping
        model.transformScript
        (columnNames model |> makeEnv)
  in
    div
      []
      [ viewScript addr (List.map2 (,) model.transformScript stepErrors)
      , case model.table of
          Nothing ->
            span [] []

          Just _ ->
            StepAdder.view
              (Signal.forwardTo addr StepAdderAction)
              (columnNames model)
              model.stepAdderState
      ]


viewScript : Signal.Address Action -> List (Step, Maybe InvalidStepError) -> Html
viewScript addr scriptWithErrors =
  let
    closeButton idx =
      button
        [ onClick addr (RemoveStep idx) ]
        [ text "x" ]

    viewStep idx (step, maybeError) =
      case maybeError of
        Just err ->
          li
            []
            [ closeButton idx
            , text " "
            , span
                []
                [ text (toString step) ]
            , text " "
            , span
                [ style [("color", "red")] ]
                [ text (toString err) ]
            ]

        Nothing ->
          li
            []
            [ closeButton idx
            , text " "
            , text (toString step)
            ]
  in
    case scriptWithErrors of
      [] ->
        p [style [("font-style", "italic")]] [text "identity transform"]

      _ ->
        scriptWithErrors
        |> List.indexedMap viewStep
        |> ul []


--viewColumns : Signal.Address Action -> SchemaMapping -> Html
--viewColumns addr schema =
--  let
--    numCols =
--      List.length schema
--  in
--    schema
--    |> List.indexedMap (\idx (name, expr) ->
--          li [] [viewColumn addr idx numCols (name, expr, exprType env expr)]
--    )
--    |> ul []


--viewColumn : Signal.Address Action -> Int -> Int -> (ColumnName, Expr, Result TypeError SoqlType) -> Html
--viewColumn addr idx length (name, expr, typeResult) =
--  span
--    []
--    [ button
--        [ onClick addr (AddStep (DropColumn name)) ]
--        [ text "x" ]
--    , button
--        [ onClick addr (AddStep (MoveColumnToPosition name (idx - 1)))
--        , disabled (idx == 0)
--        ]
--        [ text "^" ]
--    , button
--        [ onClick addr (AddStep (MoveColumnToPosition name (idx + 1)))
--        , disabled (idx == length - 1)
--        ]
--        [ text "v" ]
--    , text " "
--    , input
--        [ value name
--        , style [("font-weight", "bold")]
--        , Html.Events.Extra.onInput addr (\newName -> (AddStep (RenameColumn name newName)))
--        , size 20
--        ]
--        []
--    , text " "
--    , text (toString expr)
--    , text ": "
--    , span
--        [ style [("font-style", "italic")] ]
--        [ text (toString typeResult) ]
--    ]


update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp ->
      (model, Effects.none)

    AddStep step ->
      ( { model | transformScript = model.transformScript ++ [step] |> smooshScript }
      , Effects.none
      )

    RemoveStep idx ->
      ( { model | transformScript = Util.removeAt idx model.transformScript |> smooshScript }
      , Effects.none
      )

    StepAdderAction action ->
      let
        (newStepAdderState, maybeNewStep) =
          StepAdder.update action (columnNames model) model.stepAdderState
      in
        ( { model
              | stepAdderState = newStepAdderState
              , transformScript =
                  model.transformScript ++
                    (maybeNewStep |> Maybe.map Util.singleton |> Maybe.withDefault [])
          }
        , Effects.none
        )

    ServerEvent evt ->
      case evt of
        ProgressEvent rows ->
          ( { model | rowsProcessed = Basics.max model.rowsProcessed rows }
          , Effects.none
          )

        ErrorsEvent errors ->
          ( { model | errors = model.errors ++ errors }
          , Effects.none
          )

        TransformChunkEvent chunk ->
          let
            (newTable, effects) =
              case model.table of
                Just (tableScript, table) ->
                  ( table
                      |> Table.addChunk chunk
                      |> (\newTable -> (tableScript, newTable))
                      |> Just
                  , Effects.none
                  )

                Nothing ->
                  let
                    maybeTable =
                      Table.fromFirstChunk chunk
                  in
                    ( maybeTable
                        |> Maybe.map (\table -> (model.transformScript, table))
                    , Signal.send
                        createHistogramsMailbox.address
                        (columnNames model)
                      |> Task.map (always NoOp)
                      |> Effects.task
                    )
          in
            ( {model | table = newTable}
            , effects
            )

        AggregateUpdate newAggs ->
          ( { model | aggregates = newAggs }
          , Signal.send
              updateHistogramsMailbox.address
              ( model.table
                  |> Maybe.map (snd >> .columnNames)
                  |> Maybe.withDefault []
              , newAggs
              )
            |> Task.map (always NoOp)
            |> Effects.task
          )


columnNames : Model -> List ColumnName
columnNames model =
  model.table
    |> Maybe.map (snd >> .columnNames)
    |> Maybe.withDefault []


app =
  StartApp.start
    { init = (initModel, Effects.none)
    , view = view
    , update = update
    , inputs =
        [ Signal.map (ServerEvent << ProgressEvent) phoenixDatasetProgress
        , Signal.map (ServerEvent << ErrorsEvent) phoenixDatasetErrors
        , Signal.map (ServerEvent << TransformChunkEvent) phoenixDatasetTransform
        , Signal.map (ServerEvent << AggregateUpdate) phoenixDatasetAggregate
        ]
    }


main = 
  app.html


port tasks : Signal (Task Never ())
port tasks =
  app.tasks


port phoenixDatasetProgress : Signal Int

port phoenixDatasetErrors : Signal (List String)

port phoenixDatasetTransform : Signal (List (List (ColumnName, String)))

port phoenixDatasetAggregate : Signal (List (ColumnName, JsDec.Value))


createHistogramsMailbox =
  Signal.mailbox []

port createHistograms : Signal (List ColumnName)
port createHistograms =
  createHistogramsMailbox.signal


updateHistogramsMailbox =
  Signal.mailbox ([], [])

port updateHistograms : Signal (List ColumnName, List (ColumnName, JsDec.Value))
port updateHistograms =
  updateHistogramsMailbox.signal
