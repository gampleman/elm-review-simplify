module NoListLiteralsConcat exposing (rule)

{-|

@docs rule

-}

import Elm.Syntax.Expression as Expression exposing (Expression)
import Elm.Syntax.Node as Node exposing (Node)
import Elm.Syntax.Range exposing (Range)
import Review.Fix
import Review.Rule as Rule exposing (Error, Rule)


{-| Reports when an operation on lists could be simplified to a single literal list.

    config =
        [ NoListLiteralsConcat.rule
        ]


## Fail

    _ =
        [ 1, 2, 3 ] ++ [ 4, mysteryNumber, 6 ]

    _ =
        List.concat
            [ [ 1, 2, 3 ]
            , [ 4, mysteryNumber, 6 ]
            ]

    _ =
        List.concat
            [ [ 1, 2, 3 ]
            ]

    _ =
        1 :: [ 2, 3 ]

    _ =
        [] ++ list

    _ =
        list ++ []


## Success

    _ =
        [ 1, 2, 3, 4, mysteryNumber, 6 ]

    _ =
        [ 1, 2, 3 ] ++ list ++ [ 4, mysteryNumber, 6 ]

    _ =
        List.concat
            [ [ 1, 2, 3 ]
            , list
            , [ 4, mysteryNumber, 6 ]
            ]


## Try it out

You can try this rule out by running the following command:

```bash
elm-review --template jfmengels/elm-review-simplification/example --rules NoListLiteralsConcat
```

-}
rule : Rule
rule =
    Rule.newModuleRuleSchema "NoListLiteralsConcat" ()
        |> Rule.withSimpleExpressionVisitor expressionVisitor
        |> Rule.fromModuleRuleSchema


errorForAddingEmptyLists : Range -> Range -> Error {}
errorForAddingEmptyLists range rangeToRemove =
    Rule.errorWithFix
        { message = "Concatenating with a single list doesn't have any effect"
        , details = [ "You should remove the concatenation with the empty list." ]
        }
        range
        [ Review.Fix.removeRange rangeToRemove ]


error2 : Range -> Error {}
error2 range =
    Rule.error
        { message = "Expression could be simplified to be a single List"
        , details = [ "Try moving all the elements into a single list." ]
        }
        range


expressionVisitor : Node Expression -> List (Error {})
expressionVisitor node =
    case Node.value node of
        Expression.OperatorApplication "++" _ (Node.Node range (Expression.ListExpr [])) other ->
            [ errorForAddingEmptyLists range
                { start = range.start
                , end = (Node.range other).start
                }
            ]

        Expression.OperatorApplication "++" _ other (Node.Node range (Expression.ListExpr [])) ->
            [ errorForAddingEmptyLists range
                { start = (Node.range other).end
                , end = range.end
                }
            ]

        Expression.OperatorApplication "++" _ (Node.Node rangeLeft (Expression.ListExpr _)) (Node.Node rangeRight (Expression.ListExpr _)) ->
            [ Rule.errorWithFix
                { message = "Expression could be simplified to be a single List"
                , details = [ "Try moving all the elements into a single list." ]
                }
                (Node.range node)
                [ Review.Fix.replaceRangeBy
                    { start = { row = rangeLeft.end.row, column = rangeLeft.end.column - 1 }
                    , end = { row = rangeRight.start.row, column = rangeRight.start.column + 1 }
                    }
                    ","
                ]
            ]

        Expression.OperatorApplication "::" _ _ (Node.Node _ (Expression.ListExpr _)) ->
            [ error2 (Node.range node) ]

        Expression.Application [ Node.Node _ (Expression.FunctionOrValue [ "List" ] "concat"), Node.Node _ (Expression.ListExpr list) ] ->
            if List.length list < 2 then
                [ error2 (Node.range node) ]

            else if List.all isListLiteral list then
                [ error2 (Node.range node) ]

            else
                []

        _ ->
            []


isListLiteral : Node Expression -> Bool
isListLiteral node =
    case Node.value node of
        Expression.ListExpr _ ->
            True

        _ ->
            False
