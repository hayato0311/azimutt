module Models.Project.RelationCardinality exposing (RelationCardinality(..), decode, encode)

import Json.Decode as Decode
import Json.Encode as Encode exposing (Value)


type RelationCardinality
    = Zero
    | One
    | Many


encode : RelationCardinality -> Value
encode cardinality =
    Encode.string <|
        case cardinality of
            Zero ->
                "0"

            One ->
                "1"

            Many ->
                "n"


decode : Decode.Decoder RelationCardinality
decode =
    Decode.string
        |> Decode.andThen
            (\value ->
                case value of
                    "0" ->
                        Decode.succeed Zero

                    "1" ->
                        Decode.succeed One

                    "n" ->
                        Decode.succeed Many

                    _ ->
                        Decode.fail ("Invalid relation cardinality: " ++ value)
            )
