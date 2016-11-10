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
  [ "block", "date", "arrest", "latitude"
  , "longitude", "description"
  ]


view : Model -> Html Msg
view model =
  let
    typedSchemaMapping =
      scriptToMapping originalFileColumns model
      |> snd
  in
    div [style [("margin", "10px"), ("overflow", "scroll")]]
      [ span []
          [ strong [] [text "Source Columns: "]
          , originalFileColumns |> String.join ", " |> text
          ]
      , App.map
          ScriptEditorMsg
          (TransformScriptEditor.view
            originalFileColumns
            model)
      , table []
          [typedSchemaMapping
          |> List.map ((App.map (ScriptEditorMsg << TransformScriptEditor.AddStep)) << viewColumnHeader)
          |> thead []]
      ]


viewColumnHeader : (ColumnName, Expr, SoqlType) -> Html Step
viewColumnHeader (name, expr, ty) =
  th
    [ style [("font-weight", "normal")] ]
    [ span [ style [("font-weight", "bold")] ] [ text name ]
    , text ": "
    , span [ style [("font-style", "italic")] ] [text (toString ty)]
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
