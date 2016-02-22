module Table where

import Model exposing (..)

type alias Table =
  { columnNames : List ColumnName
  , rows : List (List String)
  }


type alias Chunk =
  List (List (ColumnName, String))


fromFirstChunk : Chunk -> Maybe Table
fromFirstChunk chunk =
  List.head chunk
  |> Maybe.map (\firstRow ->
    let
      colNames =
        firstRow
        |> List.map fst
    in
      addChunk
        chunk
        { columnNames = colNames
        , rows = []
        }
  )


-- TODO: make sure columns line up...
addChunk : Chunk -> Table -> Table
addChunk rows table =
  { table | rows = table.rows ++ (List.map (List.map snd) rows) }
