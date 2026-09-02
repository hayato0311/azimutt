module DataSources.ConversionTest exposing (..)

import DataSources.JsonMiner.JsonAdapter as JsonAdapter
import DataSources.JsonMiner.JsonSchema as JsonSchema
import DataSources.SqlMiner.MysqlGenerator as MysqlGenerator
import DataSources.SqlMiner.PostgreSqlGenerator as PostgreSqlGenerator
import DataSources.SqlMiner.SqlAdapter as SqlAdapter
import DataSources.SqlMiner.SqlParser as SqlParser
import Dict exposing (Dict)
import Expect
import Json.Decode as Decode
import Libs.Dict as Dict
import Libs.Nel as Nel exposing (Nel)
import Models.Project.Column as Column exposing (Column)
import Models.Project.ColumnName exposing (ColumnName)
import Models.Project.Comment exposing (Comment)
import Models.Project.Relation as Relation exposing (Relation)
import Models.Project.RelationCardinality exposing (RelationCardinality(..))
import Models.Project.Schema exposing (Schema)
import Models.Project.Table as Table exposing (Table)
import Models.Project.TableId exposing (TableId)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "DataSourceConversion"
        [ test "parse PostgreSQL" (\_ -> crmPostgres |> parseSql |> Expect.equal crmSchema)
        , test "generate PostgreSQL" (\_ -> crmSchema |> PostgreSqlGenerator.generate |> Expect.equal crmPostgres)
        , test "parse MySQL" (\_ -> crmMysql |> parseSql |> Expect.equal crmSchema)
        , test "generate MySQL" (\_ -> crmSchema |> MysqlGenerator.generate |> Expect.equal crmMysql)
        , test "parse JSON" (\_ -> crmJson |> parseJson |> Expect.equal crmSchema)
        , test "preserve explicit cardinality from JSON" <|
            \_ ->
                explicitCardinalityJson
                    |> parseJson
                    |> .relations
                    |> List.map (\relation -> ( relation.srcCardinality, relation.refCardinality ))
                    |> Expect.equal [ ( Just One, Just One ) ]
        , test "infer one-to-one from JSON uniques" <|
            \_ ->
                inferredCardinalityJson
                    |> parseJson
                    |> .relations
                    |> List.map .srcCardinality
                    |> Expect.equal [ Just One ]
        , test "infer one-to-one from a single-column unique" <|
            \_ ->
                uniqueForeignKeySql
                    |> parseSql
                    |> .relations
                    |> List.map .srcCardinality
                    |> Expect.equal [ Just One ]
        , test "do not infer one-to-one from part of a composite unique" <|
            \_ ->
                compositeUniqueForeignKeySql
                    |> parseSql
                    |> .relations
                    |> List.map .srcCardinality
                    |> Expect.equal [ Nothing ]
        ]



-- FIXME: table comments are not well parsed :(


crmSchema : Schema
crmSchema =
    { tables =
        [ { emptyTable
            | id = ( "", "contact_roles" )
            , name = "contact_roles"
            , columns =
                [ { emptyColumn | name = "contact_id", kind = "uuid" }
                , { emptyColumn | name = "role_id", kind = "uuid" }
                ]
                    |> buildColumns
            , primaryKey = Just { name = Nothing, columns = Nel "contact_id" [ "role_id" ] |> Nel.map Nel.from }
          }
        , { emptyTable
            | id = ( "", "contacts" )
            , name = "contacts"
            , columns =
                [ { emptyColumn | name = "id", kind = "uuid" }
                , { emptyColumn | name = "name", kind = "varchar" }
                , { emptyColumn | name = "email", kind = "varchar" }
                ]
                    |> buildColumns
            , primaryKey = Just { name = Nothing, columns = Nel.from "id" |> Nel.map Nel.from }
          }
        , { emptyTable
            | id = ( "", "events" )
            , name = "events"
            , columns =
                [ { emptyColumn | name = "id", kind = "uuid" }
                , { emptyColumn | name = "contact_id", kind = "uuid", nullable = True }
                , { emptyColumn | name = "instance_name", kind = "varchar", comment = Just { emptyComment | text = "hostname" } }
                , { emptyColumn | name = "instance_id", kind = "uuid" }
                ]
                    |> buildColumns
            , primaryKey = Just { name = Nothing, columns = Nel.from "id" |> Nel.map Nel.from }
          }
        , { emptyTable
            | id = ( "", "roles" )
            , name = "roles"
            , columns =
                [ { emptyColumn | name = "id", kind = "uuid" }
                , { emptyColumn | name = "name", kind = "varchar" }
                ]
                    |> buildColumns
            , primaryKey = Just { name = Nothing, columns = Nel.from "id" |> Nel.map Nel.from }
          }
        ]
            |> buildTables
    , relations =
        [ ( "contact_roles_contact_id_fk_az", ( "", "contact_roles", "contact_id" ), ( "", "contacts", "id" ) )
        , ( "contact_roles_role_id_fk_az", ( "", "contact_roles", "role_id" ), ( "", "roles", "id" ) )
        , ( "events_contact_id_fk_az", ( "", "events", "contact_id" ), ( "", "contacts", "id" ) )
        ]
            |> List.map buildRelation
    , types = Dict.empty
    }


crmPostgres : String
crmPostgres =
    """CREATE TABLE contact_roles (
  contact_id uuid,
  role_id uuid,
  PRIMARY KEY (contact_id, role_id)
);

CREATE TABLE contacts (
  id uuid PRIMARY KEY,
  name varchar NOT NULL,
  email varchar NOT NULL
);
ALTER TABLE contact_roles ADD CONSTRAINT contact_roles_contact_id_fk_az FOREIGN KEY (contact_id) REFERENCES contacts(id);

CREATE TABLE events (
  id uuid PRIMARY KEY,
  contact_id uuid REFERENCES contacts(id),
  instance_name varchar NOT NULL,
  instance_id uuid NOT NULL
);
COMMENT ON COLUMN events.instance_name IS 'hostname';

CREATE TABLE roles (
  id uuid PRIMARY KEY,
  name varchar NOT NULL
);
ALTER TABLE contact_roles ADD CONSTRAINT contact_roles_role_id_fk_az FOREIGN KEY (role_id) REFERENCES roles(id);"""


crmMysql : String
crmMysql =
    """CREATE TABLE contact_roles (
  contact_id uuid,
  role_id uuid,
  PRIMARY KEY (contact_id, role_id)
);

CREATE TABLE contacts (
  id uuid PRIMARY KEY,
  name varchar NOT NULL,
  email varchar NOT NULL
);
ALTER TABLE contact_roles ADD CONSTRAINT contact_roles_contact_id_fk_az FOREIGN KEY (contact_id) REFERENCES contacts(id);

CREATE TABLE events (
  id uuid PRIMARY KEY,
  contact_id uuid REFERENCES contacts(id),
  instance_name varchar NOT NULL COMMENT "hostname",
  instance_id uuid NOT NULL
);

CREATE TABLE roles (
  id uuid PRIMARY KEY,
  name varchar NOT NULL
);
ALTER TABLE contact_roles ADD CONSTRAINT contact_roles_role_id_fk_az FOREIGN KEY (role_id) REFERENCES roles(id);"""


uniqueForeignKeySql : String
uniqueForeignKeySql =
    """CREATE TABLE users (
  id bigint PRIMARY KEY
);
CREATE TABLE profiles (
  id bigint PRIMARY KEY,
  user_id bigint REFERENCES users(id),
  UNIQUE KEY profiles_user_id_key (user_id)
);"""


compositeUniqueForeignKeySql : String
compositeUniqueForeignKeySql =
    """CREATE TABLE users (
  id bigint PRIMARY KEY
);
CREATE TABLE profiles (
  id bigint PRIMARY KEY,
  tenant_id bigint NOT NULL,
  user_id bigint REFERENCES users(id),
  UNIQUE (tenant_id, user_id)
);"""


explicitCardinalityJson : String
explicitCardinalityJson =
    relationJson """
      "srcCardinality": "1",
      "refCardinality": "1",
"""


inferredCardinalityJson : String
inferredCardinalityJson =
    relationJson ""


relationJson : String -> String
relationJson cardinalities =
    """{
  "tables": [
    {"schema": "", "table": "users", "columns": [{"name": "id", "type": "bigint"}]},
    {"schema": "", "table": "profiles", "columns": [{"name": "user_id", "type": "bigint"}], "uniques": [{"columns": ["user_id"]}]}
  ],
  "relations": [{
    "name": "profiles_user",
"""
        ++ cardinalities
        ++ """
    "src": {"table": ".profiles", "column": "user_id"},
    "ref": {"table": ".users", "column": "id"}
  }]
}"""


crmJson : String
crmJson =
    """{
  "tables": [
    {
      "schema": "",
      "table": "contact_roles",
      "columns": [
        {
          "name": "contact_id",
          "type": "uuid"
        },
        {
          "name": "role_id",
          "type": "uuid"
        }
      ],
      "primaryKey": {
        "columns": [
          "contact_id",
          "role_id"
        ]
      }
    },
    {
      "schema": "",
      "table": "contacts",
      "columns": [
        {
          "name": "id",
          "type": "uuid"
        },
        {
          "name": "name",
          "type": "varchar"
        },
        {
          "name": "email",
          "type": "varchar"
        }
      ],
      "primaryKey": {
        "columns": [
          "id"
        ]
      }
    },
    {
      "schema": "",
      "table": "events",
      "columns": [
        {
          "name": "id",
          "type": "uuid"
        },
        {
          "name": "contact_id",
          "type": "uuid",
          "nullable": true
        },
        {
          "name": "instance_name",
          "type": "varchar",
          "comment": "hostname"
        },
        {
          "name": "instance_id",
          "type": "uuid"
        }
      ],
      "primaryKey": {
        "columns": [
          "id"
        ]
      }
    },
    {
      "schema": "",
      "table": "roles",
      "columns": [
        {
          "name": "id",
          "type": "uuid"
        },
        {
          "name": "name",
          "type": "varchar"
        }
      ],
      "primaryKey": {
        "columns": [
          "id"
        ]
      }
    }
  ],
  "relations": [
    {
      "name": "contact_roles_contact_id_fk_az",
      "src": {
        "table": ".contact_roles",
        "column": "contact_id"
      },
      "ref": {
        "table": ".contacts",
        "column": "id"
      }
    },
    {
      "name": "contact_roles_role_id_fk_az",
      "src": {
        "table": ".contact_roles",
        "column": "role_id"
      },
      "ref": {
        "table": ".roles",
        "column": "id"
      }
    },
    {
      "name": "events_contact_id_fk_az",
      "src": {
        "table": ".events",
        "column": "contact_id"
      },
      "ref": {
        "table": ".contacts",
        "column": "id"
      }
    }
  ]
}"""


parseSql : String -> Schema
parseSql sql =
    sql
        |> SqlParser.parse
        |> Tuple.second
        |> List.foldl (\c s -> s |> SqlAdapter.evolve ( Nel.from { index = 0, text = "" }, c )) SqlAdapter.initSchema
        |> (\schema -> { tables = schema.tables, relations = schema.relations |> List.map (Relation.inferCardinality schema.tables) |> List.sortBy .id, types = schema.types |> Dict.fromListBy .id })


parseJson : String -> Schema
parseJson json =
    json
        |> Decode.decodeString JsonSchema.decode
        |> Result.withDefault { tables = [], relations = [], types = [] }
        |> JsonAdapter.buildSchema
        |> (\schema -> { tables = schema.tables, relations = schema.relations |> List.sortBy .id, types = schema.types })


emptyTable : Table
emptyTable =
    Table.empty


emptyColumn : Column
emptyColumn =
    Column.empty


emptyComment : Comment
emptyComment =
    { text = "" }


buildTables : List Table -> Dict TableId Table
buildTables tables =
    tables |> Dict.fromListBy .id


buildColumns : List Column -> Dict ColumnName Column
buildColumns columns =
    columns |> List.indexedMap (\i c -> { c | index = i }) |> Dict.fromListBy .name


buildRelation : ( String, ( String, String, String ), ( String, String, String ) ) -> Relation
buildRelation ( name, ( srcSchema, srcTable, srcColumn ), ( refSchema, refTable, refColumn ) ) =
    { id = ( ( ( srcSchema, srcTable ), srcColumn ), ( ( refSchema, refTable ), refColumn ) )
    , name = name
    , src = { table = ( srcSchema, srcTable ), column = Nel.from srcColumn }
    , ref = { table = ( refSchema, refTable ), column = Nel.from refColumn }
    , srcCardinality = Nothing
    , refCardinality = Nothing
    }
