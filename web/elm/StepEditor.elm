module StepEditor exposing (..)

import Dict

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Html.App as App

import Model exposing (..)
import Util exposing (..)
import PrimitiveEditors


type alias Model =
  Step


type Action
  = DropColumnAction DropColumnAction
  | RenameColumnAction RenameColumnAction
  | MoveColumnToPositionAction MoveColumnToPositionAction
  | ApplyFunctionAction ApplyFunctionAction


type DropColumnAction
  = UpdateDropColumnName ColumnName


type RenameColumnAction
  = UpdateFromColumnName ColumnName
  | UpdateToColumnName ColumnName


type MoveColumnToPositionAction
  = UpdateColumnToMove ColumnName
  | UpdateMoveToIndex Int


type ApplyFunctionAction
  = UpdateFuncName FuncName
  | UpdateResultColumnName ColumnName
  | UpdateArgAt Int Atom
  | RemoveArgAt Int
  | InsertArgAt Int Atom


update : Action -> Model -> Model
update action model =
  case action of
    DropColumnAction (UpdateDropColumnName name) ->
      case model of
        DropColumn _ ->
          DropColumn name

        _ ->
          Debug.crash "unexpected action"

    RenameColumnAction renameAction ->
      case model of
        RenameColumn from to ->
          case renameAction of
            UpdateFromColumnName newFrom ->
              RenameColumn newFrom to

            UpdateToColumnName newTo ->
              RenameColumn from newTo

        _ ->
          Debug.crash "unexpected action"

    MoveColumnToPositionAction moveAction ->
      case model of
        MoveColumnToPosition colName toIdx ->
          case moveAction of
            UpdateColumnToMove newColName ->
              MoveColumnToPosition newColName toIdx

            UpdateMoveToIndex newIdx ->
              MoveColumnToPosition colName newIdx

        _ ->
          Debug.crash "unexpected action"

    ApplyFunctionAction applyFuncAction ->
      case model of
        ApplyFunction resultColName funcName args ->
          case applyFuncAction of
            UpdateFuncName newName ->
              ApplyFunction resultColName newName (defaultArgsFor newName)

            UpdateResultColumnName newColName ->
              ApplyFunction newColName funcName args

            UpdateArgAt idx newAtom ->
              ApplyFunction
                resultColName
                funcName
                (args |> setAt newAtom idx |> getMaybe "idx out of range")

            RemoveArgAt idx ->
              ApplyFunction
                resultColName
                funcName
                (args |> removeAt idx)

            InsertArgAt idx newAtom ->
              ApplyFunction
                resultColName
                funcName
                (args |> insertAt newAtom idx |> getMaybe "idx out of range")

        _ ->
          Debug.crash "unexpected action"


view : TypedSchemaMapping -> Model -> Html Action
view typedMapping model =
  case model of
    DropColumn columnName ->
      span []
        [ text "Drop column "
        , App.map  
            (DropColumnAction << UpdateDropColumnName)
            (PrimitiveEditors.selector
              (columnNames typedMapping)
              columnName)
        ]

    RenameColumn fromName toName ->
      span []
        [ text "Rename column "
        , App.map 
            (RenameColumnAction << UpdateFromColumnName)
            (PrimitiveEditors.selector
              (columnNames typedMapping)
              fromName)
        , text " to "
        , App.map
            (RenameColumnAction << UpdateToColumnName)
            (PrimitiveEditors.string
              [size 20]
              toName)
        ]

    MoveColumnToPosition colName idx ->
      span []
        [ text "Move column "
        , App.map
            (MoveColumnToPositionAction << UpdateColumnToMove)
            (PrimitiveEditors.selector
              (columnNames typedMapping)
              colName)
        , text " to index "
        , App.map
            (MoveColumnToPositionAction << UpdateMoveToIndex)
            (PrimitiveEditors.int idx)
        ]

    ApplyFunction resultColName funcName args ->
      span []
        [ text "Add column "
        , App.map
            (ApplyFunctionAction << UpdateResultColumnName)
            (PrimitiveEditors.string
              [size 20]
              resultColName)
        , text " = "
        , App.map
            (ApplyFunctionAction << UpdateFuncName)
            (PrimitiveEditors.selector
              (Model.functions |> Dict.keys)
              funcName)
        , text "("
        , span
            []
            (args
              |> List.indexedMap (\idx atom ->
                span []
                  [ App.map
                      (ApplyFunctionAction << UpdateArgAt idx)
                      (atomEditor
                        typedMapping
                        atom)
                  , a [ href "#", onClick (ApplyFunctionAction (RemoveArgAt idx)) ]
                      [ text "X" ]
                  ]
              )
              |> List.intersperse (text ", ")
            )
        , text " "
        , a [ href "#"
            , onClick
                (ApplyFunctionAction <|
                  InsertArgAt (List.length args) (StringLit ""))
            ]
            [ text "+" ]
        , text ")"
        ]


atomEditor : TypedSchemaMapping -> Atom -> Html Atom
atomEditor typedMapping model =
  let
    firstCol =
      (columnNames typedMapping) |> List.head |> getMaybe "no columns"

    switchToCol =
      a [ href "#", onClick (ColRef firstCol) ]
        [ text "const" ]

    switchToLit =
      a [ href "#", onClick (StringLit "") ]
        [ text "col" ]
  in
    case model of
      ColRef columnName ->
        span []
          [ switchToLit
          , App.map
              ColRef
              (PrimitiveEditors.selector
                (Debug.log "cns" (columnNames typedMapping))
                columnName)
          ]

      StringLit val ->
        span []
          [ switchToCol
          , App.map
              StringLit
              (PrimitiveEditors.string [size 5] val)
          ]

      NumberLit val ->
        span []
          [ switchToCol
          , App.map
              NumberLit
              (PrimitiveEditors.int val)
          ]

      x ->
        text <| "TODO: edit " ++ toString x


-- model-y stuff

defaultArgsFor : FuncName -> List Atom
defaultArgsFor funcName =
  Model.functions
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
