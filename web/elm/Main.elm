module Main where

import String
import Task exposing (Task)
import Dict exposing (Dict)
import Json.Decode as JsDec exposing ((:=))
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
import Encode
import ProgressBar
import ProgressBar.Model


type alias Model =
  { transformScript : TransformScript
  , table : Maybe Table
  , progressBar : ProgressBar.Model.Model
  , aggregates : List (ColumnName, JsDec.Value)
  }


type Action
  = AddStep Step
  | UpdateStepAt Int StepEditor.Action
  | RemoveStep Int -- index
  | SaveTransform
  | ServerEvent ServerEvent
  | ProgressBarAction ProgressBar.Model.Action
  | NoOp


type ServerEvent
  = ProgressEvent ProgressEvent
  | TransformChunkEvent (List (List (ColumnName, String)))
  | AggregateUpdate (List (ColumnName, JsDec.Value))


type ProgressEvent
  = BasicTableChunkWritten
      { sequenceNumber : Int
      , errors : List (ProgressBar.Model.LineNo, ProgressBar.Model.ExtractError)
      }
  | ChunkTransformed
      { sequenceNumber : Int
      , errors : List (ProgressBar.Model.LineNo, ProgressBar.Model.TransformError)
      }


type alias Histogram =
  Dict String Int


-- match web/api/basic_table.ex (TODO: server should send this along)
chunkSize =
  512


initModel =
  { transformScript = []
  , progressBar = ProgressBar.Model.initModel chunkSize
  , table = Nothing
  , aggregates = []
  }


view : Signal.Address Action -> Model -> Html
view addr model =
  let
    (increments, finalMapping) =
      scriptToMapping
        model.transformScript
        (columnNames model.table)
  in
    div []
      [ div [ class "pure-g" ]
        [ div [ class "pure-u-2-3" ]
            [ div [ class "pure-u-1-3", id "upload" ] []
            , viewTransformEditor addr model.transformScript increments
            , button
                [ disabled
                    False
                    --(model.table
                    --  |> Maybe.map (\(tableScript, _) ->
                    --    tableScript == model.transformScript)
                    --  |> Maybe.withDefault False
                    --)
                , onClick addr SaveTransform
                ]
                [ text "Save Transform & Get Preview" ]
            ]
        , div [ class "pure-u-1-3", id "errors" ]
            [ ProgressBar.view
                (Signal.forwardTo addr ProgressBarAction)
                model.progressBar
            ]
        ]
      , table [ id "histograms" ] []
      , div [ id "results" ]
          [ model.table
            |> Maybe.map (\table ->
              case Table.forNewMapping finalMapping table of
                Err neededExprs ->
                  div []
                    [ p [] [text "Need moar exprs from the server..."]
                    , ul []
                        (neededExprs
                        |> List.map (\expr -> li [] [text (toString expr)]))
                    ]

                Ok table ->
                  viewTable addr table
            )
            |> Maybe.withDefault (p [] [text "No results yet"])
          ]
      ]


viewTable : Signal.Address Action -> Table -> Html
viewTable addr theTable =
  table
    []
    [ thead []
        [ tr []
          (List.map
            (viewColumnHeader (Signal.forwardTo addr AddStep))
            theTable.mapping)
        ]
      -- getting harder to lazify this
    , Html.Lazy.lazy viewRows (Table.getRows theTable)
    ]


viewRows : List (List String) -> Html
viewRows rows =
  tbody []
    (rows
    |> List.map (\row ->
      tr []
        (row |> List.map (\col -> td [] [text col]))
    ))


viewColumnHeader : Signal.Address Step -> (ColumnName, Expr, SoqlType) -> Html
viewColumnHeader addr (name, expr, ty) =
  th
    [ style [("font-weight", "normal")] ]
    [ span [ style [("font-weight", "bold")] ] [ text name ]
    , text ": "
    , span [ style [("font-style", "italic")] ] [text (toString ty)]
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
    , pre
        [ style
            [ ("white-space", "pre-wrap")
            , ("margin", "0")
            , ("text-align", "left")
            ]
        ]
        [ text (toString expr) ]
    ]


viewTransformEditor : Signal.Address Action
                   -> TransformScript
                   -> List (TypedSchemaMapping, Maybe InvalidStepError)
                   -> Html
viewTransformEditor addr transformScript increments =
  div
    []
    [ viewScript
        addr
        (List.map2 (,) transformScript increments)
    , let
        firstFunName =
          Model.functions
          |> Dict.keys
          |> List.head
          |> Util.getMaybe "no functions"

        defaultArgs =
          StepEditor.defaultArgsFor firstFunName
      in
        button
          [ onClick
              addr
              (AddStep (ApplyFunction "someCol" firstFunName defaultArgs))
          ]
          [ text "Add Function" ]
    ]


-- TODO: pass schema at each step
viewScript : Signal.Address Action -> List (Step, (TypedSchemaMapping, Maybe InvalidStepError)) -> Html
viewScript addr scriptWithIncrements =
  let
    closeButton idx =
      button
        [ onClick addr (RemoveStep idx) ]
        [ text "x" ]

    viewStep idx (step, (beforeMapping, maybeError)) =
      li []
        [ closeButton idx
        , text " "
        , StepEditor.view
            (Signal.forwardTo addr (UpdateStepAt idx))
            beforeMapping
            step
        , text " "
        , maybeError
          |> Maybe.map (\err ->
            span
              [ style [("color", "red")] ]
              [ text (toString err) ]
          )
          |> Maybe.withDefault (span [] [])
        ]
  in
    case scriptWithIncrements of
      [] ->
        p [style [("font-style", "italic")]] [text "identity transform"]

      _ ->
        scriptWithIncrements
        |> List.indexedMap viewStep
        |> ul []


update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp ->
      (model, Effects.none)

    AddStep step ->
      ( { model | transformScript = model.transformScript ++ [step] }
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
      ( { model | transformScript = Util.removeAt idx model.transformScript }
      , Effects.none
      )

    SaveTransform ->
      ( { model
            | table = Nothing
            , progressBar = ProgressBar.Model.initModel chunkSize
        }
      , Signal.send
          updateTransformMailbox.address
          (model.transformScript
            |> Encode.stepsToNestedFuncs
            |> Encode.encodeNestedFuncs)
        |> Task.map (always NoOp)
        |> Effects.task
      )

    ProgressBarAction action ->
      ( { model | progressBar = ProgressBar.update action model.progressBar }
      , Effects.none
      )

    ServerEvent evt ->
      case evt of
        ProgressEvent event ->
          let
            -- TODO: real line numbers
            (chunkState, sequenceNumber) =
              case event of
                BasicTableChunkWritten {errors, sequenceNumber} ->
                  ( ProgressBar.Model.Extracted
                      { numRows = chunkSize
                      , errors = errors
                      }
                  , sequenceNumber
                  )

                ChunkTransformed {errors, sequenceNumber} ->
                  ( ProgressBar.Model.Transformed
                      { numRows = chunkSize
                      , errors = errors
                      }
                  , sequenceNumber
                  )

            action =
              ProgressBar.Model.AddChunkState sequenceNumber chunkState
          in
            ( { model | progressBar =
                  ProgressBar.update action model.progressBar }
            , Effects.none
            )

        TransformChunkEvent chunk ->
          let
            (newTable, effects) =
              case model.table of
                Just table ->
                  ( table |> Table.addChunk chunk |> Just
                  , Effects.none
                  )

                Nothing ->
                  let
                    -- probably should be a user-visible error if your table is empty
                    maybeTable =
                      Table.fromFirstChunk chunk
                  in
                    ( maybeTable
                    , Signal.send
                        createHistogramsMailbox.address
                        (columnNames maybeTable)
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
              ( columnNames model.table
              , newAggs
              )
            |> Task.map (always NoOp)
            |> Effects.task
          )


columnNames : Maybe Table -> List ColumnName
columnNames maybeTable =
  maybeTable
  |> Maybe.map (\table -> table.mapping |> List.map (\(name, _, _) -> name))
  |> Maybe.withDefault []


app =
  StartApp.start
    { init = (initModel, Effects.none)
    , view = view
    , update = update
    , inputs =
        [ Signal.map
            (\rawEvent ->
              rawEvent
              |> decodeProgress
              |> Util.getMaybe "unrecognized stage"
              |> ProgressEvent
              |> ServerEvent)
            phoenixDatasetProgress
        , Signal.map (ServerEvent << TransformChunkEvent) phoenixDatasetTransform
        , Signal.map (ServerEvent << AggregateUpdate) phoenixDatasetAggregate
        ]
    }


main = 
  app.html


port tasks : Signal (Task Never ())
port tasks =
  app.tasks


port phoenixDatasetProgress : Signal RawProgressEvent


type alias RawProgressEvent =
  { stage : String
  , sequenceNumber : Int
  , errors : List String
  }


decodeProgress : RawProgressEvent -> Maybe ProgressEvent
decodeProgress rawEvent =
  case rawEvent.stage of
    -- TODO real line numbers
    "extract" ->
      Just (BasicTableChunkWritten
        { sequenceNumber = rawEvent.sequenceNumber
        , errors = rawEvent.errors |> List.map (\e -> (0, e))
        })

    "transform" ->
      Just (ChunkTransformed
        { sequenceNumber = rawEvent.sequenceNumber
        , errors = rawEvent.errors |> List.map (\e -> (0, e))
        })

    _ ->
      Nothing


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
