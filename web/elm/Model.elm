module Model exposing (..)

import Dict exposing (Dict)

import List.Extra

import Util

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
  = ColRef ColumnName
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


type alias Schema =
  List (ColumnName, SoqlType)


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
  , ( "add"
    , { arguments = NormalArgs [("a", SoqlNumber), ("b", SoqlNumber)]
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


initialMapping : Schema -> TypedSchemaMapping
initialMapping columns =
  columns
  |> List.map (\(name, ty) -> (name, Atom (ColRef name), ty))


scriptToMapping : Schema -> TransformScript -> (List (TypedSchemaMapping, Maybe InvalidStepError), TypedSchemaMapping)
scriptToMapping sourceColumns script =
  List.foldl
    (\step (increments, mapping) ->
      case applyStep step mapping of
        Ok newMapping ->
          (increments ++ [(mapping, Nothing)], newMapping)

        Err err ->
          (increments ++ [(mapping, Just err)], mapping) -- just let old mapping keep going...
    )
    ([], initialMapping sourceColumns)
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
        resolvedArgs =
          args
          |> List.map (resolve typedMapping << Atom)

        newExpr =
          FunApp funcName resolvedArgs
      in
        case exprType typedMapping newExpr of
          Ok ty ->
            if colExists newColName typedMapping then
              Err (ColumnAlreadyExists newColName)
            else
              Ok <| (newColName, newExpr, ty) :: typedMapping

          Err err ->
            Err (ExprTypeError err)


resolve : TypedSchemaMapping -> Expr -> Expr
resolve typedMapping expr =
  case expr of
    FunApp name args ->
      FunApp name (args |> List.map (resolve typedMapping))
    
    Atom (ColRef name) ->
      findCol name typedMapping
      |> Util.getMaybe ("couldn't find with name " ++ name)
      |> (\(_, expr, _) -> expr)
    
    _ ->
      expr


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
        ColRef colName ->
          case findCol colName typedMapping of
            Just (_, _, ty) ->
              Ok ty
            
            Nothing ->
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
