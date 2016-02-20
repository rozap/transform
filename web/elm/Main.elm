module Main where

import String
import Task exposing (Task)
import Dict exposing (Dict)
import Json.Decode as JsDec
import Json.Encode as JsEnc

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
import StepEditor


type alias Model =
  { transformScript : TransformScript
  , errors : List String
  , table : Maybe (TransformScript, Table)
  , rowsProcessed : Int
  , aggregates : List (ColumnName, JsDec.Value)
  }


type Action
  = AddStep Step
  | UpdateStepAt Int StepEditor.Action
  | RemoveStep Int -- index
  | SaveTransform
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
  }


view : Signal.Address Action -> Model -> Html
view addr model =
  div []
    [ div [ class "pure-g" ]
      [ div [ class "pure-u-2-3" ]
          [ div [ class "pure-u-1-3", id "upload" ] []
          , viewTransformEditor addr model
          , button
              [ disabled
                  (model.table
                    |> Maybe.map (\(tableScript, _) ->
                      tableScript == model.transformScript)
                    |> Maybe.withDefault False
                  )
              , onClick addr SaveTransform
              ]
              [ text "Save Transform & Get Preview" ]
          ]
      , div [ class "pure-u-1-3", id "errors" ]
          [ viewErrors model ]
      , div [ class "pure-u-1-1" ]
          [ viewProgress model ]
      ]
    , table [ id "histograms" ] []
    , div [ id "results" ]
        [ viewTable addr model ]
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


viewTable : Signal.Address Action -> Model -> Html
viewTable addr model =
  case model.table of
    Nothing ->
      p [] [text "No results yet"]

    Just (_, theTable) ->
      let
        header =
          theTable.columnNames
          |> List.map (\name ->
            viewColumnName (Signal.forwardTo addr AddStep) name
          )

        viewRows rows =
          tbody []
            (rows
            |> List.map (\row ->
              tr []
                (row |> List.map (\col -> td [] [text col]))
            ))
      in
        table
          []
          [ thead []
              [ tr []
                  header
              ]
          , Html.Lazy.lazy viewRows theTable.rows
          ]


viewColumnName : Signal.Address Step -> ColumnName -> Html
viewColumnName addr name =
  th
    []
    [ text name
    , br [] []
    , span
        [ style [("font-weight", "normal")] ]
        [ button
            [ onClick addr (RenameColumn name "newName") ]
            [ text "Rename" ]
        , button
            [ onClick addr (MoveColumnToPosition name 0) ]
            [ text "Move" ]
        , button
            [ onClick addr (DropColumn name) ]
            [ text "Drop" ]
        ]
    ]


viewErrors : Model -> Html
viewErrors model =
  model.errors
  |> List.map (\error -> li [] [text error])
  |> ul [class "errors"]


viewTransformEditor : Signal.Address Action -> Model -> Html
viewTransformEditor addr model =
  let
    env =
      columnNames model |> makeEnv

    (stepErrors, mapping) =
      stepsToMapping
        model.transformScript
        env
  in
    div
      []
      [ viewScript
          addr
          (List.map2 (,) model.transformScript stepErrors)
      , case model.table of
          Nothing ->
            span [] []

          Just _ ->
            let
              firstFunName =
                env.functions
                |> Dict.keys
                |> List.head
                |> Util.getMaybe "no functions"

              defaultArgs =
                defaultArgsFor firstFunName env
            in
              button
                [ onClick
                    addr
                    (AddStep (ApplyFunction "someCol" firstFunName defaultArgs))
                ]
                [ text "Add Function" ]
      ]


-- TODO: pass schema at each step
viewScript : Signal.Address Action -> List (Step, (Env, Maybe InvalidStepError)) -> Html
viewScript addr scriptWithErrors =
  let
    closeButton idx =
      button
        [ onClick addr (RemoveStep idx) ]
        [ text "x" ]

    viewStep idx (step, (env, maybeError)) =
      case maybeError of
        Just err ->
          li
            []
            [ closeButton idx
            , text " "
            , StepEditor.view
                (Signal.forwardTo addr (UpdateStepAt idx))
                env
                step
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
            , StepEditor.view
                (Signal.forwardTo addr (UpdateStepAt idx))
                env
                step
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

    UpdateStepAt idx action ->
      ( { model | transformScript =
            model.transformScript
            |> Util.updateAt (StepEditor.update action) idx
            |> Util.getMaybe "idx out of range"
        }
      , Effects.none
      )

    RemoveStep idx ->
      ( { model | transformScript = Util.removeAt idx model.transformScript |> smooshScript }
      , Effects.none
      )

    SaveTransform ->
      ( { model | table = Nothing, errors = [], rowsProcessed = 0 }
      , Signal.send
          updateTransformMailbox.address
          (model.transformScript
            |> stepsToNestedFuncs
            |> encodeNestedFuncs)
        |> Task.map (always NoOp)
        |> Effects.task
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
                        (maybeTable
                          |> Maybe.map .columnNames
                          |> Maybe.withDefault [])
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


updateTransformMailbox =
  Signal.mailbox (JsEnc.string "__DATUM__") -- does this actually work for the backend?

port updateTransform : Signal JsEnc.Value
port updateTransform =
  updateTransformMailbox.signal
