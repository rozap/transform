module Main where

import String
import Task exposing (Task)
import Dict exposing (Dict)
import Json.Decode as JsDec

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import StartApp
import Effects exposing (Effects, Never)

import Html.Events.Extra
import Model exposing (..)
import Table exposing (Table)
import Util


type alias Model =
  { transformScript : TransformScript
  , errors : List String
  , table : Maybe Table
  , rowsProcessed : Int
  , aggregates : List (ColumnName, JsDec.Value)
  }


type Action
  = AddStep Step
  | RemoveStep Int -- index
  | ServerEvent ServerEvent
  | NoOp


type ServerEvent
  = ProgressEvent Int
  | ErrorsEvent (List String)
  | TransformChunkEvent (List (List (ColumnName, String)))
  | AggregateUpdate (List (ColumnName, JsDec.Value))


type alias Histogram =
  Dict String Int


env =
  String.split "," "ID,ID,Case Number,Date,Block,IUCR,Primary Type,Description,Location Description,Arrest,Domestic,Beat,District,Ward,Community Area,FBI Code,X Coordinate,Y Coordinate,Year,Updated On,Latitude,Longitude,Location"
  |> makeEnv


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
      [ div [ class "pure-u-1-3" ]
          [ textarea [ id "transform" ]
              []
          , button []
              [ text "Update Transform" ]
          ]
      , div [ class "pure-u-1-3", id "errors" ]
          [ viewErrors model ]
      , div [ class "pure-u-1-3", id "upload" ]
          []
      , div [ class "pure-u-1-1" ]
          [ viewProgress model ]
      ]
    , table [ id "histograms" ] []
    , div [ id "results" ] [ viewTable addr model ]
    --, viewTransformEditor addr model
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

    Just theTable ->
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
      stepsToMapping model.transformScript env
  in
    table
      []
      [ tr []
          [ td [] [ h1 [] [text "Columns"] ]
          , td [] [ h1 [] [text "Transform Script"] ]
          ]
      , tr []
          [ td
              [ style [("vertical-align", "top")] ]
              [ viewColumns addr mapping ]
          , td
              [ style [("vertical-align", "top")] ]
              [ viewScript addr (List.map2 (,) model.transformScript stepErrors) ]
          ]
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
    scriptWithErrors
    |> List.indexedMap viewStep
    |> ul []


viewColumns : Signal.Address Action -> SchemaMapping -> Html
viewColumns addr schema =
  let
    numCols =
      List.length schema
  in
    schema
    |> List.indexedMap (\idx (name, expr) ->
          li [] [viewColumn addr idx numCols (name, expr, exprType env expr)]
    )
    |> ul []


viewColumn : Signal.Address Action -> Int -> Int -> (ColumnName, Expr, Result TypeError SoqlType) -> Html
viewColumn addr idx length (name, expr, typeResult) =
  span
    []
    [ button
        [ onClick addr (AddStep (DropColumn name)) ]
        [ text "x" ]
    , button
        [ onClick addr (AddStep (MoveColumnToPosition name (idx - 1)))
        , disabled (idx == 0)
        ]
        [ text "^" ]
    , button
        [ onClick addr (AddStep (MoveColumnToPosition name (idx + 1)))
        , disabled (idx == length - 1)
        ]
        [ text "v" ]
    , text " "
    , input
        [ value name
        , style [("font-weight", "bold")]
        , Html.Events.Extra.onInput addr (\newName -> (AddStep (RenameColumn name newName)))
        , size 20
        ]
        []
    , text " "
    , text (toString expr)
    , text ": "
    , span
        [ style [("font-style", "italic")] ]
        [ text (toString typeResult) ]
    ]


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
                Just table ->
                  ( table |> Table.addChunk chunk |> Just
                  , Effects.none
                  )

                Nothing ->
                  let
                    table =
                      Table.fromFirstChunk chunk
                  in
                    ( table
                    , Signal.send
                        createHistogramsMailbox.address
                        (table |> Maybe.map .columnNames |> Maybe.withDefault [])
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
              ( model.table |> Maybe.map .columnNames |> Maybe.withDefault []
              , newAggs
              )
            |> Task.map (always NoOp)
            |> Effects.task
          )


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
