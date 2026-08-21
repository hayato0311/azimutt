module Libs.Html.EventsTest exposing (..)

import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Libs.Html.Events exposing (wheelDecoder)
import Libs.Models.Platform exposing (Platform(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Libs.Html.Events"
        [ describe "wheelDecoder"
            [ zoomModifierTest "Mac keeps Command + scroll zoom" Mac True False True
            , zoomModifierTest "Mac enables trackpad pinch zoom" Mac False True True
            , zoomModifierTest "Mac keeps unmodified scroll as pan" Mac False False False
            , zoomModifierTest "Mac accepts both zoom modifiers" Mac True True True
            , zoomModifierTest "PC ignores metaKey" PC True False False
            , zoomModifierTest "PC keeps Ctrl + scroll zoom" PC False True True
            , zoomModifierTest "PC keeps unmodified scroll as pan" PC False False False
            ]
        ]


zoomModifierTest : String -> Platform -> Bool -> Bool -> Bool -> Test
zoomModifierTest name platform metaKey ctrlKey expected =
    test name <|
        \_ ->
            wheelEvent metaKey ctrlKey
                |> Decode.decodeValue (wheelDecoder platform)
                |> Result.map .ctrl
                |> Expect.equal (Ok expected)


wheelEvent : Bool -> Bool -> Encode.Value
wheelEvent metaKey ctrlKey =
    Encode.object
        [ ( "clientX", Encode.float 100 )
        , ( "clientY", Encode.float 200 )
        , ( "pageX", Encode.float 100 )
        , ( "pageY", Encode.float 200 )
        , ( "deltaX", Encode.float 0 )
        , ( "deltaY", Encode.float -10 )
        , ( "metaKey", Encode.bool metaKey )
        , ( "ctrlKey", Encode.bool ctrlKey )
        , ( "altKey", Encode.bool False )
        , ( "shiftKey", Encode.bool False )
        ]
