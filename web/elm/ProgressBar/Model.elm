module ProgressBar.Model where

import Dict exposing (Dict)


type alias Model =
  { chunkSize : Int
  , errors : Int
  , chunks : Dict Int ChunkState
  , hoveredChunk : Maybe Int
  }


initModel : Int -> Model
initModel chunkSize =
  { chunkSize = chunkSize
  , chunks = Dict.empty
  , errors = 0
  , hoveredChunk = Nothing
  }


type ChunkState
  = Extracted { numRows : Int, errors : List (LineNo, ExtractError) }
  | Transformed { numRows : Int, errors : List (LineNo, TransformError) }


type alias LineNo =
  Int


type Error
  = TransformError TransformError
  | ExtractError ExtractError


type alias ExtractError
  = String


type alias TransformError
  = String


type Action
  = AddChunkState Int ChunkState
  | HoverChunk Int
  | UnHoverChunk
