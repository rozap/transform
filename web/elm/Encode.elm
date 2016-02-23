module Encode where

import Json.Encode as JsEnc

import Model exposing (..)

-- for the elixir backend...
-- this should probably be done on the elixir side, since the transform script
-- is a nicer canonical repr

type NestedFuncs
  = Datum
  | StringLitNF String
  | SourceColumnNF String
  | FunAppNF FuncName (List NestedFuncs) ColumnName


-- TODO error checking like in stepsToMapping...
stepsToNestedFuncs : TransformScript -> NestedFuncs
stepsToNestedFuncs script =
  List.foldl
    (\step expr ->
      case step of
        ApplyFunction resultCol funName args ->
          FunAppNF
            funName
            ([expr] ++ List.map atomToNestedFuncs args)
            resultCol

        _ ->
          Debug.crash "TODO"
    )
    Datum
    script


atomToNestedFuncs : Atom -> NestedFuncs
atomToNestedFuncs atom =
  case atom of
    SourceColumn source ->
      SourceColumnNF source

    StringLit str ->
      StringLitNF str

    _ ->
      Debug.crash "TODO"


encodeNestedFuncs : NestedFuncs -> JsEnc.Value
encodeNestedFuncs expr =
  case expr of
    -- not great that all 3 of these are encoded the same way :P
    Datum ->
      JsEnc.string "__DATUM__"

    StringLitNF str ->
      JsEnc.string str

    SourceColumnNF sc ->
      JsEnc.string sc

    FunAppNF funcName args resultCol ->
      JsEnc.list
        [ JsEnc.string funcName
        , JsEnc.list []
        , List.map encodeNestedFuncs args ++ [JsEnc.string resultCol]
          |> JsEnc.list
        ]
