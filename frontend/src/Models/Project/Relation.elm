module Models.Project.Relation exposing (Relation, RelationLike, decode, doc, empty, encode, inferCardinality, linkedToTable, new, newWithCardinality, outRelation, virtual)

import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Encode as Encode exposing (Value)
import Libs.Json.Decode as Decode
import Libs.Json.Encode as Encode
import Libs.Nel as Nel exposing (Nel)
import Models.Project.ColumnPath as ColumnPath exposing (ColumnPath)
import Models.Project.ColumnRef as ColumnRef exposing (ColumnRef, ColumnRefLike)
import Models.Project.RelationCardinality as RelationCardinality exposing (RelationCardinality(..))
import Models.Project.RelationId as RelationId exposing (RelationId)
import Models.Project.RelationName as RelationName exposing (RelationName)
import Models.Project.Table exposing (Table)
import Models.Project.TableId exposing (TableId)


type alias Relation =
    { id : RelationId
    , name : RelationName
    , src : ColumnRef
    , ref : ColumnRef
    , srcCardinality : Maybe RelationCardinality
    , refCardinality : Maybe RelationCardinality
    }


type alias RelationLike x y =
    { x
        | id : RelationId
        , name : RelationName
        , src : ColumnRefLike y
        , ref : ColumnRefLike y
    }


empty : Relation
empty =
    { id = ( ( ( "", "" ), "" ), ( ( "", "" ), "" ) ), name = "", src = { table = ( "", "" ), column = Nel "" [] }, ref = { table = ( "", "" ), column = Nel "" [] }, srcCardinality = Nothing, refCardinality = Nothing }


new : RelationName -> ColumnRef -> ColumnRef -> Relation
new name src ref =
    newWithCardinality name src ref Nothing Nothing


newWithCardinality : RelationName -> ColumnRef -> ColumnRef -> Maybe RelationCardinality -> Maybe RelationCardinality -> Relation
newWithCardinality name src ref srcCardinality refCardinality =
    Relation (RelationId.new src ref) name src ref srcCardinality refCardinality


virtual : ColumnRef -> ColumnRef -> Relation
virtual src ref =
    new "virtual relation" src ref


outRelation : List (RelationLike x y) -> ColumnPath -> List (RelationLike x y)
outRelation tableOutRelations column =
    tableOutRelations |> List.filter (\r -> r.src.column |> ColumnPath.startsWith column)


linkedToTable : TableId -> RelationLike x y -> Bool
linkedToTable table relation =
    relation.src.table == table || relation.ref.table == table


encode : Relation -> Value
encode value =
    Encode.notNullObject
        [ ( "name", value.name |> RelationName.encode )
        , ( "src", value.src |> ColumnRef.encode )
        , ( "ref", value.ref |> ColumnRef.encode )
        , ( "srcCardinality", value.srcCardinality |> Encode.maybe RelationCardinality.encode )
        , ( "refCardinality", value.refCardinality |> Encode.maybe RelationCardinality.encode )
        ]


decode : Decode.Decoder Relation
decode =
    Decode.map5 newWithCardinality
        (Decode.field "name" RelationName.decode)
        (Decode.field "src" ColumnRef.decode)
        (Decode.field "ref" ColumnRef.decode)
        (Decode.maybeField "srcCardinality" RelationCardinality.decode)
        (Decode.maybeField "refCardinality" RelationCardinality.decode)


inferCardinality : Dict TableId Table -> Relation -> Relation
inferCardinality tables relation =
    if relation.srcCardinality /= Nothing then
        relation

    else
        tables
            |> Dict.get relation.src.table
            |> Maybe.map
                (\table ->
                    if isSingleColumnUnique relation table then
                        { relation | srcCardinality = Just One }

                    else
                        relation
                )
            |> Maybe.withDefault relation


isSingleColumnUnique : Relation -> Table -> Bool
isSingleColumnUnique relation table =
    (table.uniques |> List.any (\unique -> List.isEmpty unique.columns.tail && unique.columns.head == relation.src.column))
        || (table.primaryKey
                |> Maybe.map (\primaryKey -> List.isEmpty primaryKey.columns.tail && primaryKey.columns.head == relation.src.column)
                |> Maybe.withDefault False
           )


doc : String -> String -> Relation
doc srcStr refStr =
    let
        ( src, ref ) =
            ( ColumnRef.fromString srcStr, ColumnRef.fromString refStr )
    in
    new (Tuple.second src.table ++ "_" ++ Nel.join "_" src.column ++ "_fk") src ref
