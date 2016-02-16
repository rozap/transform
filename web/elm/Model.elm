module Model where

import Dict exposing (Dict)
import Set exposing (Set)

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
  = SourceColumn ColumnName
  | FunApp FuncName (List Expr)
  | StringLit String
  | NumberLit Int
  | DoubleLit Float


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
  | MultipleErrors (List TypeError)


type alias Env =
  { functions : Dict FuncName Function
  , columns : List ColumnName
  }


exprType : Env -> Expr -> Result TypeError SoqlType
exprType env expr =
  case expr of
    SourceColumn colName ->
      if List.member colName env.columns then
        Ok SoqlText
      else
        Err (NonexistentColumn colName)

    FunApp name args ->
      case Dict.get name env.functions of
        Just fun ->
          let
            argTypeResults =
              args |> List.map (exprType env)
          in
            case getOks argTypeResults of
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
                Err (MultipleErrors errs)

        Nothing ->
          Err (NonexistentFunction name)

    StringLit _ ->
      Ok SoqlText

    DoubleLit _ ->
      Ok SoqlDouble

    NumberLit _ ->
      Ok SoqlNumber


schemaType : SchemaMapping -> Env -> Result TypeError Schema
schemaType mapping env =
  mapping
    |> List.map (snd >> exprType env)
    |> getOks
    |> Result.map (\types -> List.map2 (,) (List.map fst mapping) types)
    |> Result.formatError MultipleErrors


argsMatch : FunArgs -> List SoqlType -> Bool
argsMatch expectedArgs givenArgs =
  case expectedArgs of
    VarArgs ty ->
      givenArgs |> List.all (\argTy -> argTy == ty)

    NormalArgs typeList ->
      (typeList |> List.map snd) == givenArgs


getOks : List (Result a b) -> Result (List a) (List b)
getOks results =
  let
    go soFarErr soFarOk remaining =
      case remaining of
        [] ->
          case (soFarErr, soFarOk) of
            ([], xs) ->
              Ok xs

            (errs, _) ->
              Err errs

        (Ok x::xs) ->
          go soFarErr (x::soFarOk) xs

        (Err x::xs) ->
          go (x::soFarErr) soFarOk xs
  in
    go [] [] results


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
  | ApplyFunction ColumnName FuncName (List Expr)


type alias TransformScript =
  List Step


type InvalidStepError
  = NonexistentColumnStep ColumnName
  | ColumnAlreadyExists ColumnName
  | ExprTypeError TypeError
  | IndexOutOfRange Int


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
      let
        newExpr =
          FunApp funcName args
      in
        case exprType env newExpr of
          Ok _ ->
            (newColName, newExpr) :: mapping
            |> Ok

          Err typeErr ->
            Err (ExprTypeError typeErr)


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


stepsToMapping : TransformScript -> Env -> (List (Maybe InvalidStepError), SchemaMapping)
stepsToMapping script env =
  let
    d =
      Debug.log "stepsToMapping" (script, env)
    initialMapping =
      env.columns
      |> List.map (\name -> (name, SourceColumn name))
  in
    List.foldl
      (\step (errors, mapping) ->
        case applyStep step env mapping of
          Ok newMapping ->
            (errors ++ [Nothing], newMapping)

          Err err ->
            (errors ++ [Just err], mapping)
      )
      ([], initialMapping)
      script
