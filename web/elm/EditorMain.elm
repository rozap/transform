module EditorMain exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Html.App as App
import String

import Model exposing (..)
import TransformScriptEditor

-- just for showing the editor
-- no backend interaction

type alias Model =
  TransformScript


type Msg
  = ScriptEditorMsg TransformScriptEditor.Msg
  | NoOp


originalFileColumns =
  [ ("block", SoqlText)
  , ("date", SoqlText)
  , ("arrest", SoqlText)
  , ("latitude", SoqlText)
  , ("longitude", SoqlText)
  , ("description", SoqlText)
  , ("officersInvolved", SoqlNumber)
  ]


view : Model -> Html Msg
view model =
  let
    typedSchemaMapping =
      scriptToMapping originalFileColumns model
      |> snd
  in
    div [style [("margin", "10px"), ("overflow", "scroll")]]
      [ h1 [] [text "Source Table"]
      , originalFileColumns
        |> List.map (\(n, t) -> viewColNameAndType n t)
        |> List.intersperse (text ", ")
        |> span []
      , h1 [] [text "Transform"]
      , App.map
          ScriptEditorMsg
          (TransformScriptEditor.view
            originalFileColumns
            model)
      , p []
          [ text "As SQL: "
          , code [] [text (asSQL typedSchemaMapping "myTable")]
          ]
      , h1 [] [text "Output Table"]
      , table []
          [typedSchemaMapping
          |> List.map ((App.map (ScriptEditorMsg << TransformScriptEditor.AddStep)) << viewColumnHeader)
          |> thead []]
      ]


viewColumnHeader : (ColumnName, Expr, SoqlType) -> Html Step
viewColumnHeader (name, expr, ty) =
  th
    [ style [("font-weight", "normal")] ]
    [ viewColNameAndType name ty
    , br [] []
    , span
        [ style [("font-weight", "normal")] ]
        [ button
            [ onClick (RenameColumn name name) ]
            [ text "Rename" ]
        , button
            [ onClick (MoveColumnToPosition name 0) ]
            [ text "Move" ]
        , button
            [ onClick (DropColumn name) ]
            [ text "Drop" ]
        ]
    , pre
        [ style
            [ ("white-space", "pre-wrap")
            , ("margin", "0")
            , ("text-align", "left")
            ]
        ]
        [ text (toString expr) ]
    ]


viewColNameAndType : String -> SoqlType -> Html a
viewColNameAndType name ty =
  span []
    [ span [ style [("font-weight", "bold")] ] [ text name ]
    , text ": "
    , span [ style [("font-style", "italic")] ] [text (toString ty)]
    ]


asSQL : TypedSchemaMapping -> String -> String
asSQL typedMapping tableName =
  let
    colRefToSQL name =
      if name |> String.any (\c -> c == ' ') then
        "`" ++ name ++ "`"
      else
        name

    exprToSQL expr =
      case expr of
        FunApp name args ->
          name ++ "(" ++ (args |> List.map exprToSQL |> String.join ", ") ++ ")"
        
        Atom atom ->
          case atom of
            ColRef name ->
              colRefToSQL name
            
            StringLit str ->
              "'" ++ str ++ "'"
            
            NumberLit int ->
              toString int
            
            DoubleLit float ->
              toString float
            
            BoolLit bool ->
              toString bool
    
    colExprToSQL name expr =
      case (name, expr) of
        -- cases with conditions sure would be nice
        (givenName, Atom (ColRef referencedName)) ->
          if givenName == referencedName then
            givenName
          else
            (exprToSQL expr) ++ " AS " ++ (colRefToSQL name)
        
        _ ->
          (exprToSQL expr) ++ " AS " ++ (colRefToSQL name)

    colExprs =
      typedMapping
      |> List.map (\(name, expr, _) -> colExprToSQL name expr)
  in
    "SELECT " ++ (String.join ", " colExprs) ++ " FROM " ++ tableName


update : Msg -> Model -> Model
update msg model =
  case Debug.log "msg" msg of
    ScriptEditorMsg editorMsg ->
      TransformScriptEditor.update editorMsg model
    
    NoOp ->
      model


main =
  App.beginnerProgram
    { model = []
    , view = view
    , update = update
    }
