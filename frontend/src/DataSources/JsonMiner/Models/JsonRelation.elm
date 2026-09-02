module DataSources.JsonMiner.Models.JsonRelation exposing (JsonColumnRef, JsonRelation, decode, encode)

import Json.Decode as Decode
import Json.Encode as Encode exposing (Value)
import Libs.Json.Decode as Decode
import Libs.Json.Encode as Encode
import Models.Project.RelationCardinality as RelationCardinality exposing (RelationCardinality)


type alias JsonRelation =
    { name : String
    , src : JsonColumnRef
    , ref : JsonColumnRef
    , srcCardinality : Maybe RelationCardinality
    , refCardinality : Maybe RelationCardinality
    }


type alias JsonColumnRef =
    { table : String
    , column : String
    }


decode : Decode.Decoder JsonRelation
decode =
    Decode.map5 JsonRelation
        (Decode.field "name" Decode.string)
        (Decode.field "src" decodeJsonColumnRef)
        (Decode.field "ref" decodeJsonColumnRef)
        (Decode.maybeField "srcCardinality" RelationCardinality.decode)
        (Decode.maybeField "refCardinality" RelationCardinality.decode)


encode : JsonRelation -> Value
encode value =
    Encode.notNullObject
        [ ( "name", value.name |> Encode.string )
        , ( "src", value.src |> encodeJsonColumnRef )
        , ( "ref", value.ref |> encodeJsonColumnRef )
        , ( "srcCardinality", value.srcCardinality |> Encode.maybe RelationCardinality.encode )
        , ( "refCardinality", value.refCardinality |> Encode.maybe RelationCardinality.encode )
        ]


decodeJsonColumnRef : Decode.Decoder JsonColumnRef
decodeJsonColumnRef =
    Decode.map2 JsonColumnRef
        (Decode.field "table" Decode.string)
        (Decode.field "column" Decode.string)


encodeJsonColumnRef : JsonColumnRef -> Value
encodeJsonColumnRef value =
    Encode.notNullObject
        [ ( "table", value.table |> Encode.string )
        , ( "column", value.column |> Encode.string )
        ]
