module Model where

import Dict exposing (Dict)

import List.Extra

import Util

-- never want to denormalize shit... but sometimes you might as well...
-- you want the types when you're checking

-- you can have partial success... all of the columns might be right except
-- one. But it should probably be more like `Result StepError TypedSchemaMapping`

-- basic types

type Step
  = DropColumn ColumnName
  | RenameColumn ColumnName ColumnName
  | MoveColumnToPosition ColumnName Int
  | ApplyFunction ColumnName FuncName (List Atom)


type alias TransformScript =
  List Step


type alias ColumnName =
  String


type alias FuncName =
  String


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


-- schema types


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


type alias TypedSchemaMapping =
  List (ColumnName, Expr, SoqlType)


type alias Functions =
  Dict FuncName Function


-- default env

functions : Functions
functions =
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



-- type check


initialMapping : List ColumnName -> TypedSchemaMapping
initialMapping columns =
  columns |> List.map (\name -> (name, Atom (SourceColumn name), SoqlText))


scriptToMapping : TransformScript -> List ColumnName -> (List (TypedSchemaMapping, Maybe InvalidStepError), TypedSchemaMapping)
scriptToMapping script sourceColumns =
  let
    firstMapping =
      sourceColumns |> List.map (\name -> (name, Atom (SourceColumn name), SoqlText))
  in
    List.foldl
      (\step (increments, mapping) ->
        case applyStep step mapping of
          Ok newMapping ->
            (increments ++ [(mapping, Nothing)], newMapping)

          Err err ->
            (increments ++ [(mapping, Just err)], mapping) -- just let old mapping keep going...
      )
      ([], firstMapping)
      script


applyStep : Step -> TypedSchemaMapping -> Result InvalidStepError TypedSchemaMapping
applyStep step typedMapping =
  case step of
    DropColumn nameToDrop ->
      if colExists nameToDrop typedMapping then
        typedMapping
        |> List.filter (\(name, _, _) -> name /= nameToDrop)
        |> Ok
      else
        Err (NonexistentColumnStep nameToDrop)

    RenameColumn fromName toName ->
      if colExists fromName typedMapping then
        if colExists toName typedMapping then
          Err (ColumnAlreadyExists toName)
        else
          typedMapping
          |> List.map (\(name, expr, ty) ->
            if name == fromName then
              (toName, expr, ty)
            else
              (name, expr, ty))
          |> Ok
      else
        Err (NonexistentColumnStep fromName)

    MoveColumnToPosition colName toIndex ->
      case findCol colName typedMapping of
        Just col ->
          typedMapping
          |> List.filter (\(n, _, _) -> n /= colName)
          |> Util.insertAt col toIndex
          |> Result.fromMaybe (IndexOutOfRange toIndex)

        Nothing ->
          Err (NonexistentColumnStep colName)

    ApplyFunction newColName funcName args ->
      let
        newExpr =
          FunApp funcName (List.map Atom args)
      in
        case exprType typedMapping newExpr of
          Ok ty ->
            if colExists newColName typedMapping then
              Err (ColumnAlreadyExists newColName)
            else
              Ok <| (newColName, newExpr, ty) :: typedMapping

          Err err ->
            Err (ExprTypeError err)


exprType : TypedSchemaMapping -> Expr -> Result TypeError SoqlType
exprType typedMapping expr =
  case expr of
    FunApp name args ->
      case Dict.get name functions of
        Just fun ->
          let
            argTypeResults =
              args |> List.map (exprType typedMapping)
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
          if colExists colName typedMapping then
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


argsMatch : FunArgs -> List SoqlType -> Bool
argsMatch expectedArgs givenArgs =
  case expectedArgs of
    VarArgs ty ->
      givenArgs |> List.all (\argTy -> argTy == ty)

    NormalArgs typeList ->
      (typeList |> List.map snd) == givenArgs


-- errors

type InvalidStepError
  = NonexistentColumnStep ColumnName
  | ColumnAlreadyExists ColumnName
  | ExprTypeError TypeError
  | IndexOutOfRange Int
  | MultipleStepErrors (List InvalidStepError)


type TypeError
  = WrongArgs
      { expected : FunArgs
      , given : List SoqlType
      }
  | NonexistentFunction FuncName
  | NonexistentColumn ColumnName
  | MultipleTypeErrors (List TypeError)


-- utils

columnNames : TypedSchemaMapping -> List ColumnName
columnNames mapping =
  mapping |> List.map (\(name, _, _) -> name)


colExists : ColumnName -> TypedSchemaMapping -> Bool
colExists theName mapping =
  mapping |> findCol theName |> Util.isJust


findCol : ColumnName -> TypedSchemaMapping -> Maybe (ColumnName, Expr, SoqlType)
findCol name mapping =
  mapping |> List.Extra.find (\(colName, _, _) -> colName == name)
