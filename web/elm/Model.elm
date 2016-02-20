module Model where

import Dict exposing (Dict)
import Set exposing (Set)
import Json.Encode as JsEnc

import Util
import List.Extra


type alias ColumnName =
  String


type alias FuncName =
  String


type alias Schema = -- aka record
  List (ColumnName, SoqlType)


type alias SchemaMapping =
  List (ColumnName, Expr)


type Expr
  = FunApp FuncName (List Expr)
  | Atom Atom


type Atom
  = SourceColumn ColumnName
  | StringLit String
  | NumberLit Int
  | DoubleLit Float
  | BoolLit Bool


type alias Function =
  { arguments : FunArgs
  , returnType : SoqlType
  }


type FunArgs
  = VarArgs SoqlType
  | NormalArgs (List (String, SoqlType))


makeEnv : List ColumnName -> Env
makeEnv columns =
  { functions = envFunctions
  , columns = columns |> dedupify
  }


envFunctions =
  [ ( "concat"
    , { arguments = VarArgs SoqlText
      , returnType = SoqlText
      }
    )
  , ( "parseInt"
    , { arguments = NormalArgs [("input", SoqlText)]
      , returnType = SoqlNumber
      }
    )
  , ( "parseFloatingTimestamp"
    , { arguments =
          NormalArgs [("input", SoqlText), ("format", SoqlText)]
      , returnType = SoqlFloatingTimestamp
      }
    )
  ]
  |> Dict.fromList


type TypeError
  = WrongArgs
      { expected : FunArgs
      , given : List SoqlType
      }
  | NonexistentFunction FuncName
  | NonexistentColumn ColumnName
  | MultipleTypeErrors (List TypeError)


type alias Env =
  { functions : Dict FuncName Function
  , columns : List ColumnName
  }


exprType : Env -> Expr -> Result TypeError SoqlType
exprType env expr =
  case expr of
    FunApp name args ->
      case Dict.get name env.functions of
        Just fun ->
          let
            argTypeResults =
              args |> List.map (exprType env)
          in
            case Util.getOks argTypeResults of
              Ok argTypes ->
                if argsMatch fun.arguments argTypes then
                  Ok fun.returnType
                else
                  Err
                    (WrongArgs
                      { given = argTypes
                      , expected = fun.arguments
                      })

              Err errs ->
                Err (MultipleTypeErrors errs)

        Nothing ->
          Err (NonexistentFunction name)

    Atom atom ->
      case atom of
        SourceColumn colName ->
          if List.member colName env.columns then
            Ok SoqlText
          else
            Err (NonexistentColumn colName)

        StringLit _ ->
          Ok SoqlText

        DoubleLit _ ->
          Ok SoqlDouble

        NumberLit _ ->
          Ok SoqlNumber

        BoolLit _ ->
          Ok SoqlCheckbox


schemaType : SchemaMapping -> Env -> Result TypeError Schema
schemaType mapping env =
  mapping
    |> List.map (snd >> exprType env)
    |> Util.getOks
    |> Result.map (\types -> List.map2 (,) (List.map fst mapping) types)
    |> Result.formatError MultipleTypeErrors


argsMatch : FunArgs -> List SoqlType -> Bool
argsMatch expectedArgs givenArgs =
  case expectedArgs of
    VarArgs ty ->
      givenArgs |> List.all (\argTy -> argTy == ty)

    NormalArgs typeList ->
      (typeList |> List.map snd) == givenArgs


defaultArgsFor : FuncName -> Env -> List Atom
defaultArgsFor funcName env =
  env.functions
  |> Dict.get funcName
  |> Util.getMaybe "nonexistent function"
  |> (\func ->
    case func.arguments of
      VarArgs ty ->
        defaultAtomForType ty
        |> List.repeat 3

      NormalArgs nameAndTypePairs ->
        nameAndTypePairs
        |> List.map (snd >> defaultAtomForType)
  )


defaultAtomForType : SoqlType -> Atom
defaultAtomForType ty =
  case ty of
    SoqlCheckbox ->
      BoolLit True

    SoqlDouble ->
      DoubleLit 0

    SoqlNumber ->
      NumberLit 0

    SoqlText ->
      StringLit ""

    _ ->
      Debug.crash "TODO"

    --SoqlMoney ->
    --  XXX

    --SoqlFloatingTimestamp ->
    --  XXX

    --SoqlLocation ->
    --  XXX

    --SoqlPoint ->
    --  XXX

    --SoqlPolygon ->
    --  XXX

    --SoqlLine ->
    --  XXX


type SoqlType
  = SoqlCheckbox
  | SoqlDouble
  | SoqlFloatingTimestamp
  | SoqlMoney
  | SoqlNumber
  | SoqlText
  -- geo
  | SoqlLocation
  | SoqlPoint
  | SoqlPolygon
  | SoqlLine


type alias TableName =
  String


type Step
  = DropColumn ColumnName
  | RenameColumn ColumnName ColumnName
  | MoveColumnToPosition ColumnName Int
  | ApplyFunction ColumnName FuncName (List Atom)


type alias TransformScript =
  List Step


type InvalidStepError
  = NonexistentColumnStep ColumnName
  | ColumnAlreadyExists ColumnName
  | ExprTypeError TypeError
  | IndexOutOfRange Int
  | MultipleStepErrors (List InvalidStepError)


colExists : ColumnName -> SchemaMapping -> Bool
colExists theName mapping =
  mapping |> List.any (\(name, _) -> name == theName)


findCol : ColumnName -> SchemaMapping -> Maybe (ColumnName, Expr)
findCol colName mapping =
  List.Extra.find (\(n, _) -> n == colName) mapping


applyStep : Step -> Env -> SchemaMapping -> Result InvalidStepError SchemaMapping
applyStep step env mapping =
  case step of
    DropColumn nameToDrop ->
      if colExists nameToDrop mapping then
        mapping
        |> List.filter (\(name, _) -> name /= nameToDrop)
        |> Ok
      else
        Err (NonexistentColumnStep nameToDrop)

    RenameColumn fromName toName ->
      if colExists fromName mapping then
        if colExists toName mapping then
          Err (ColumnAlreadyExists toName)
        else
          mapping
          |> List.map (\(name, expr) ->
            if name == fromName then
              (toName, expr)
            else
              (name, expr))
          |> Ok
      else
        Err (NonexistentColumnStep fromName)

    MoveColumnToPosition colName toIndex ->
      case findCol colName mapping of
        Just col ->
          mapping
          |> List.filter (\(n, _) -> n /= colName)
          |> Util.insertAt col toIndex
          |> Result.fromMaybe (IndexOutOfRange toIndex)

        Nothing ->
          Err (NonexistentColumnStep colName)

    ApplyFunction newColName funcName args ->
      -- this is ugly
      let
        newExpr =
          FunApp funcName (List.map Atom args)

        maybeColExistsErr =
          case findCol newColName mapping of
            Just col ->
              Err (ColumnAlreadyExists (fst col))

            _ ->
              Ok ()

        maybeTypeErrs =
          case exprType env newExpr of
            Ok _ ->
              Ok ()

            Err typeErr ->
              Err (ExprTypeError typeErr)
      in
        case Util.getOks [maybeColExistsErr, maybeTypeErrs] of
          Ok _ ->
            Ok <| (newColName, newExpr) :: mapping

          Err errs ->
            Err <| MultipleStepErrors errs
        


-- this would have to be done before the transformer...
dedupify : List String -> List String
dedupify list =
  List.foldl
    (\colName (counters, soFar) ->
      let
        newCounter =
          Dict.get colName counters
          |> Maybe.withDefault 0
          |> (\c -> c + 1)

        newCounters =
          counters
          |> Dict.insert colName newCounter

        newColName =
          if newCounter == 1 then
            colName
          else
            colName ++ (toString (newCounter - 1))
      in
        (newCounters, soFar ++ [newColName])
    )
    (Dict.empty, [])
    list
  |> snd


smooshScript : TransformScript -> TransformScript
smooshScript script =
  let
    smooshPairs list =
      case list of
        a::b::rest ->
          case shmooshSteps a b of
            Just smooshed ->
              smooshScript (smooshed::rest)

            Nothing ->
              a :: (smooshScript (b::rest))

        _ ->
          script

    hasEffect step =
      case step of
        RenameColumn a b ->
          a /= b

        _ ->
          True
  in
    script
    |> smooshPairs
    |> List.filter hasEffect


shmooshSteps : Step -> Step -> Maybe Step
shmooshSteps step1 step2 =
  case (step1, step2) of
    (MoveColumnToPosition name1 pos1, MoveColumnToPosition name2 pos2) ->
      if name1 == name2 then
        Just (MoveColumnToPosition name1 pos2)
      else
        Nothing

    (RenameColumn fromName1 toName1, RenameColumn fromName2 toName2) ->
      if toName1 == fromName2 then
        Just (RenameColumn fromName1 toName2)
      else
        Nothing

    _ ->
      Nothing


-- TODO: schema, not list columnname
stepsToMapping : TransformScript -> Env -> (List (Env, Maybe InvalidStepError), SchemaMapping)
stepsToMapping script env =
  let
    initialMapping =
      env.columns
      |> List.map (\name -> (name, name |> SourceColumn |> Atom))
  in
    List.foldl
      (\step (errors, mapping) ->
        let
          curEnv =
            { env | columns = List.map fst mapping }
        in
          case applyStep step env mapping of
            Ok newMapping ->
              (errors ++ [(curEnv, Nothing)], newMapping)

            Err err ->
              (errors ++ [(curEnv, Just err)], mapping)
      )
      ([], initialMapping)
      script

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
