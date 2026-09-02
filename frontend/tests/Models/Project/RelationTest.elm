module Models.Project.RelationTest exposing (..)

import Dict exposing (Dict)
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Libs.Nel as Nel
import Models.Project.ColumnPath as ColumnPath
import Models.Project.ColumnRef exposing (ColumnRef)
import Models.Project.Relation as Relation
import Models.Project.RelationCardinality exposing (RelationCardinality(..))
import Models.Project.Table as Table exposing (Table)
import Models.Project.TableId exposing (TableId)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Models.Project.Relation"
        [ test "decodes legacy JSON without cardinality" <|
            \_ ->
                Decode.decodeString Relation.decode legacyJson
                    |> Result.map (\relation -> ( relation.srcCardinality, relation.refCardinality ))
                    |> Expect.equal (Ok ( Nothing, Nothing ))
        , test "round-trips explicit cardinality" <|
            \_ ->
                Relation.newWithCardinality "profiles_user" src ref (Just One) (Just One)
                    |> Relation.encode
                    |> Encode.encode 0
                    |> Decode.decodeString Relation.decode
                    |> Expect.equal (Ok (Relation.newWithCardinality "profiles_user" src ref (Just One) (Just One)))
        , test "infers one-to-one from a single-column unique" <|
            \_ ->
                Relation.new "profiles_user" src ref
                    |> Relation.inferCardinality tablesWithSingleUnique
                    |> .srcCardinality
                    |> Expect.equal (Just One)
        , test "does not infer from a composite unique" <|
            \_ ->
                Relation.new "profiles_user" src ref
                    |> Relation.inferCardinality tablesWithCompositeUnique
                    |> .srcCardinality
                    |> Expect.equal Nothing
        , test "infers one-to-one from a single-column primary key" <|
            \_ ->
                Relation.new "profiles_user" src ref
                    |> Relation.inferCardinality tablesWithSinglePrimaryKey
                    |> .srcCardinality
                    |> Expect.equal (Just One)
        , test "keeps explicit cardinality over inference" <|
            \_ ->
                Relation.newWithCardinality "profiles_user" src ref (Just Many) (Just One)
                    |> Relation.inferCardinality tablesWithSingleUnique
                    |> .srcCardinality
                    |> Expect.equal (Just Many)
        ]


src : ColumnRef
src =
    ColumnRef ( "", "profiles" ) (ColumnPath.fromString "user_id")


ref : ColumnRef
ref =
    ColumnRef ( "", "users" ) (ColumnPath.fromString "id")


tablesWithSingleUnique : Dict TableId Table
tablesWithSingleUnique =
    let
        table : Table
        table =
            Table.empty
    in
    Dict.singleton src.table
        { table
            | id = src.table
            , uniques = [ { name = "profiles_user_id_key", columns = Nel.from src.column, definition = Nothing } ]
        }


tablesWithCompositeUnique : Dict TableId Table
tablesWithCompositeUnique =
    let
        table : Table
        table =
            Table.empty
    in
    Dict.singleton src.table
        { table
            | id = src.table
            , uniques = [ { name = "profiles_tenant_user_key", columns = Nel.from2 src.column (ColumnPath.fromString "tenant_id"), definition = Nothing } ]
        }


tablesWithSinglePrimaryKey : Dict TableId Table
tablesWithSinglePrimaryKey =
    let
        table : Table
        table =
            Table.empty
    in
    Dict.singleton src.table
        { table
            | id = src.table
            , primaryKey = Just { name = Nothing, columns = Nel.from src.column }
        }


legacyJson : String
legacyJson =
    """{
  "name": "profiles_user",
  "src": {"table": ".profiles", "column": "user_id"},
  "ref": {"table": ".users", "column": "id"}
}"""
