module Page.Docs.Section__ exposing (Data, Model, Msg, page)

import Css
import Css.Global
import DataSource exposing (DataSource)
import DataSource.File
import DataSource.Glob as Glob exposing (Glob)
import DocsSection exposing (Section)
import Head
import Head.Seo as Seo
import Heroicon
import Html.Styled as Html exposing (Html)
import Html.Styled.Attributes as Attr exposing (css)
import List.Extra
import Markdown.Block as Block exposing (Block)
import Markdown.Parser
import MarkdownCodec
import NextPrevious
import OptimizedDecoder as Decode exposing (Decoder)
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Shared
import TableOfContents
import Tailwind.Breakpoints as Bp
import Tailwind.Utilities as Tw
import TailwindMarkdownRenderer
import Url
import View exposing (View)


type alias Model =
    ()


type alias Msg =
    Never


type alias RouteParams =
    { section : Maybe String }


page : Page RouteParams Data
page =
    Page.prerender
        { head = head
        , routes = routes
        , data = data
        }
        |> Page.buildNoState
            { view = view
            }


routes : DataSource (List RouteParams)
routes =
    DocsSection.all
        |> DataSource.map
            (List.map
                (\section ->
                    { section = Just section.slug }
                )
            )
        |> DataSource.map
            (\sections ->
                { section = Nothing } :: sections
            )


data : RouteParams -> DataSource Data
data routeParams =
    DataSource.map3 Data
        (pageBody routeParams)
        (previousAndNextData routeParams)
        (routeParams.section
            |> Maybe.withDefault "what-is-elm-pages"
            |> findBySlug
            |> Glob.expectUniqueMatch
            |> DataSource.map filePathToEditUrl
        )


filePathToEditUrl : String -> String
filePathToEditUrl filePath =
    "https://github.com/dillonkearns/elm-pages/edit/static-files/examples/docs/" ++ filePath


previousAndNextData : RouteParams -> DataSource { title : String, previousAndNext : ( Maybe NextPrevious.Item, Maybe NextPrevious.Item ) }
previousAndNextData current =
    DocsSection.all
        |> DataSource.andThen
            (\sections ->
                let
                    index : Int
                    index =
                        sections
                            |> List.Extra.findIndex (\section -> Just section.slug == current.section)
                            |> Maybe.withDefault 0
                in
                DataSource.map2 (\title previousAndNext -> { title = title, previousAndNext = previousAndNext })
                    (List.Extra.getAt index sections
                        |> maybeDataSource titleForSection
                        |> DataSource.map (Result.fromMaybe "Couldn't find section")
                        |> DataSource.andThen DataSource.fromResult
                        |> DataSource.map .title
                    )
                    (DataSource.map2 Tuple.pair
                        (List.Extra.getAt (index - 1) sections
                            |> maybeDataSource titleForSection
                        )
                        (List.Extra.getAt (index + 1) sections
                            |> maybeDataSource titleForSection
                        )
                    )
            )


maybeDataSource : (a -> DataSource b) -> Maybe a -> DataSource (Maybe b)
maybeDataSource fn maybe =
    case maybe of
        Just just ->
            fn just |> DataSource.map Just

        Nothing ->
            DataSource.succeed Nothing


titleForSection : Section -> DataSource NextPrevious.Item
titleForSection section =
    Glob.expectUniqueMatch (findBySlug section.slug)
        |> DataSource.andThen
            (\filePath ->
                DataSource.File.bodyWithoutFrontmatter filePath
                    |> DataSource.andThen markdownBodyDecoder2
                    |> DataSource.map
                        (\blocks ->
                            List.Extra.findMap
                                (\block ->
                                    case block of
                                        Block.Heading Block.H1 inlines ->
                                            Just
                                                { title = Block.extractInlineText inlines
                                                , slug = section.slug
                                                }

                                        _ ->
                                            Nothing
                                )
                                blocks
                        )
            )
        |> DataSource.andThen
            (\maybeTitle ->
                maybeTitle
                    |> Result.fromMaybe "Expected to find an H1 heading in this markdown."
                    |> DataSource.fromResult
            )
        |> DataSource.distillSerializeCodec ("next-previous-" ++ section.slug) NextPrevious.serialize


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "elm-pages"
        , image =
            { url =
                Pages.Url.external <|
                    "https://cards.microlink.io/editor?preset=contentz&title=elm-pages+docs&description="
                        ++ Url.percentEncode static.data.titles.title
            , alt = "elm-pages docs section title"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = static.data.body.description
        , locale = Nothing
        , title = static.data.titles.title ++ " | elm-pages docs"
        }
        |> Seo.website


type alias Data =
    { body : { description : String, body : List (Html Msg) }
    , titles : { title : String, previousAndNext : ( Maybe NextPrevious.Item, Maybe NextPrevious.Item ) }
    , editUrl : String
    }


view :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel static =
    { title = static.data.titles.title ++ " - elm-pages docs"
    , body =
        [ Css.Global.global
            [ Css.Global.selector ".anchor-icon"
                [ Css.opacity Css.zero
                ]
            , Css.Global.selector "h2:hover .anchor-icon"
                [ Css.opacity (Css.num 100)
                ]
            ]
        , Html.div
            [ css
                [ Tw.flex
                , Tw.flex_1
                , Tw.h_full
                ]
            ]
            [ TableOfContents.view sharedModel.showMobileMenu True static.routeParams.section static.sharedData
            , Html.article
                [ css
                    [ Tw.prose
                    , Tw.max_w_xl

                    --, Tw.whitespace_normal
                    --, Tw.mx_auto
                    , Tw.relative
                    , Tw.pt_20
                    , Tw.pb_16
                    , Tw.px_6
                    , Tw.w_full
                    , Tw.max_w_full
                    , Tw.overflow_x_hidden
                    , Bp.md
                        [ Tw.px_8
                        ]
                    ]
                ]
                [ Html.div
                    [ css
                        [ Tw.max_w_screen_md
                        , Tw.mx_auto
                        , Bp.xl [ Tw.pr_36 ]
                        ]
                    ]
                    (static.data.body.body
                        ++ [ NextPrevious.view static.data.titles.previousAndNext
                           , Html.hr [] []
                           , Html.footer
                                [ css [ Tw.text_right ]
                                ]
                                [ Html.a
                                    [ Attr.href static.data.editUrl
                                    , Attr.target "_blank"
                                    , css
                                        [ Tw.text_sm
                                        , Css.hover
                                            [ Tw.text_gray_800 |> Css.important
                                            ]
                                        , Tw.text_gray_500 |> Css.important
                                        , Tw.flex
                                        , Tw.items_center
                                        , Tw.float_right
                                        ]
                                    ]
                                    [ Html.span [ css [ Tw.pr_1 ] ] [ Html.text "Suggest an edit on GitHub" ]
                                    , Heroicon.edit
                                    ]
                                ]
                           ]
                    )
                ]
            ]
        ]
    }


pageBody : RouteParams -> DataSource { description : String, body : List (Html msg) }
pageBody routeParams =
    let
        slug : String
        slug =
            routeParams.section
                |> Maybe.withDefault "what-is-elm-pages"
    in
    Glob.expectUniqueMatch (findBySlug slug)
        |> DataSource.andThen
            (MarkdownCodec.withFrontmatter (\description body -> { description = description, body = body })
                (Decode.field "description" Decode.string)
                TailwindMarkdownRenderer.renderer
            )


findBySlug : String -> Glob String
findBySlug slug =
    Glob.succeed identity
        |> Glob.captureFilePath
        |> Glob.match (Glob.literal "content/docs/")
        |> Glob.match Glob.int
        |> Glob.match (Glob.literal "-")
        |> Glob.match (Glob.literal slug)
        |> Glob.match (Glob.literal ".md")


markdownBodyDecoder : String -> Decoder (List Block)
markdownBodyDecoder rawBody =
    rawBody
        |> Markdown.Parser.parse
        |> Result.mapError (\_ -> "Markdown parsing error")
        |> Decode.fromResult


markdownBodyDecoder2 : String -> DataSource (List Block)
markdownBodyDecoder2 rawBody =
    rawBody
        |> Markdown.Parser.parse
        |> Result.mapError (\_ -> "Markdown parsing error")
        |> DataSource.fromResult
