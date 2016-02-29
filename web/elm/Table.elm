module Table where

import Dict exposing (Dict)

import List.Extra

import Model exposing (..)
import Util


type alias Table =
  { sourceColumns : List ColumnName
  , mapping : TypedSchemaMapping
  , indexMapping : ColIndexMapping
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
        { sourceColumns = colNames
        , mapping = initialMapping colNames
        , indexMapping = [0..List.length colNames-1]
        , rows = []
        }
  )


fromFirstChunkWithTransform : Chunk -> TypedSchemaMapping -> Maybe Table
fromFirstChunkWithTransform _ _ =
  Debug.crash "TODO"


-- TODO: make sure columns line up...
addChunk : Chunk -> Table -> Table
addChunk rows table =
  { table | rows = table.rows ++ (List.map (List.map snd) rows) }


type alias ColIndexMapping =
  List Int


forNewMapping : TypedSchemaMapping -> Table -> Result (List Expr) Table
forNewMapping newMapping table =
  newMapping
  |> List.map (\(wantedName, wantedExpr, _) ->
    table.mapping
    |> List.indexedMap (,)
    |> List.Extra.find (\(_, (_, expr, _)) -> wantedExpr == expr)
    |> Result.fromMaybe wantedExpr
  )
  |> Util.getOks
  |> Result.map (List.map fst)
  |> Result.map (\newIndexMapping ->
    { table | mapping = newMapping, indexMapping = newIndexMapping |> List.reverse }
    -- I don't understand why that reverse needs to be there lol
  )


-- will crash if the mapping is invalid...
getRows : Table -> List (List String)
getRows table =
  let
    applyToRow mapping row =
      mapping
      |> List.map (\idx -> Util.getAt idx row |> Util.getMaybe "idx out of range")
  in
    List.map (applyToRow table.indexMapping) table.rows
