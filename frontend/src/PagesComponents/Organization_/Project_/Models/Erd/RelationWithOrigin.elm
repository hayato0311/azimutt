module PagesComponents.Organization_.Project_.Models.Erd.RelationWithOrigin exposing (RelationWithOrigin, create, merge, unpack)

import Models.Project.ColumnRef exposing (ColumnRef)
import Models.Project.Relation exposing (Relation)
import Models.Project.RelationCardinality exposing (RelationCardinality)
import Models.Project.RelationId exposing (RelationId)
import Models.Project.RelationName exposing (RelationName)
import Models.Project.Source exposing (Source)
import PagesComponents.Organization_.Project_.Models.ErdOrigin as ErdOrigin exposing (ErdOrigin)


type alias RelationWithOrigin =
    { id : RelationId
    , name : RelationName
    , src : ColumnRef
    , ref : ColumnRef
    , srcCardinality : Maybe RelationCardinality
    , refCardinality : Maybe RelationCardinality
    , origins : List ErdOrigin
    }


create : Source -> Relation -> RelationWithOrigin
create source relation =
    { id = relation.id
    , name = relation.name
    , src = relation.src
    , ref = relation.ref
    , srcCardinality = relation.srcCardinality
    , refCardinality = relation.refCardinality
    , origins = [ ErdOrigin.create source ]
    }


unpack : RelationWithOrigin -> Relation
unpack relation =
    { id = relation.id
    , name = relation.name
    , src = relation.src
    , ref = relation.ref
    , srcCardinality = relation.srcCardinality
    , refCardinality = relation.refCardinality
    }


merge : RelationWithOrigin -> RelationWithOrigin -> RelationWithOrigin
merge r1 r2 =
    { id = r1.id
    , name = r1.name
    , src = r1.src
    , ref = r1.ref
    , srcCardinality = firstDefined r1.srcCardinality r2.srcCardinality
    , refCardinality = firstDefined r1.refCardinality r2.refCardinality
    , origins = r1.origins ++ r2.origins
    }


firstDefined : Maybe a -> Maybe a -> Maybe a
firstDefined first second =
    case first of
        Just _ ->
            first

        Nothing ->
            second
