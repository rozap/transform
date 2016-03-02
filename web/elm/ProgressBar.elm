module ProgressBar where

import Color exposing (Color)
import Dict exposing (Dict)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Effects exposing (Effects, Never)

import ProgressBar.Model exposing (..)
import Util


update : Action -> Model -> Model
update action model =
  case action of
    AddChunkState idx state ->
      let
        newErrs =
          case state of
            Transformed {numRows, errors} ->
              List.length errors

            Extracted {numRows, errors} ->
              List.length errors
      in
        { model
            | chunks = model.chunks |> Dict.insert idx state
            , errors = model.errors + newErrs
        }

    HoverChunk idx ->
      { model | hoveredChunk = Just idx }

    UnHoverChunk ->
      { model | hoveredChunk = Nothing }


view : Signal.Address Action -> Model -> Html
view addr model =
  div []
    [ div [ style [("display", "flex"), ("flex-wrap", "wrap")] ]
        ( model.chunks
          |> getStates
          |> List.indexedMap (\idx chunk -> viewChunk addr idx chunk)
        )
    , stats model
    , chunkDetail model
    ]


stats : Model -> Html
stats model =
  let
    numChunks =
      Dict.size model.chunks

    totalRows =
      numChunks * model.chunkSize
  in
    p []
      [ text <|
          toString numChunks ++ " chunks * " ++
          toString model.chunkSize ++ " rows/chunk = " ++
          toString totalRows ++ " total rows; " ++
          toString model.errors ++ " errors."
      ]


chunkDetail : Model -> Html
chunkDetail model =
  model.hoveredChunk
  |> Maybe.map (\hoveredChunk ->
    model.chunks
    |> Dict.get hoveredChunk
    |> Util.getMaybe "chunk not there"
    |> (\chunkState ->
      case chunkState of
        Extracted {numRows} ->
          p []
            [ text <| "Chunk " ++ toString hoveredChunk ++ ": " ++ toString numRows ++ " rows" ]

        Transformed {numRows, errors} ->
          div []
            [ p []
                [ text <|
                    "Chunk " ++ toString hoveredChunk ++ ": " ++
                      toString numRows ++ " rows, " ++
                      toString (List.length errors) ++ " errors:"
                ]
            , ul []
                (errors |> List.map (\err -> li [] [text (toString err)]))
            ]
    )
  )
  |> Maybe.withDefault (span [] [])


viewChunk : Signal.Address Action -> Int -> Maybe ChunkState -> Html
viewChunk addr idx maybeState =
  let
    color =
      case maybeState of
        Nothing ->
          Color.white

        Just (Extracted _) ->
          Color.grey

        (Just (Transformed {numRows, errors})) ->
          let
            errFrac =
              (List.length errors |> toFloat) / (numRows |> toFloat)

            displayFrac =
              Basics.min 1 (errFrac * 1000)
          in
            Color.rgb (displayFrac * 255 |> round) ((1 - displayFrac) * 255 |> round) 0
  in
    span
      [ style
          [ ("white-space", "pre")
          , ("background-color", colorToCss color)
          ]
      , onMouseEnter addr (HoverChunk idx)
      , onMouseLeave addr UnHoverChunk
      ]
      [ text "  " ]


colorToCss : Color -> String
colorToCss color =
  let
    rgb =
      Color.toRgb color
  in
    "rgb(" ++
      toString rgb.red ++ "," ++
      toString rgb.green ++ "," ++
      toString rgb.blue ++ ")"


getStates : Dict Int ChunkState -> List (Maybe ChunkState)
getStates states =
  states
  |> Dict.toList
  |> upToHighest
  |> List.map snd


upToHighest : List (Int, a) -> List (Int, Maybe a)
upToHighest chunks =
  let
    go curIdx rest =
      case rest of
        [] ->
          []

        ((chunkIdx, chunk)::restOfChunks) ->
          if chunkIdx == curIdx then
            (chunkIdx, Just chunk) :: go (curIdx + 1) restOfChunks
          else
            (curIdx, Nothing) :: go (curIdx + 1) rest
  in
    go 0 chunks

