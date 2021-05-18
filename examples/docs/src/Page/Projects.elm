module Page.Projects exposing (Data, Model, Msg, page)

import DataSource exposing (DataSource)
import DataSource.File
import DataSource.Glob as Glob
import DataSource.Http
import Document exposing (Document)
import Head
import Head.Seo as Seo
import Html.Styled exposing (div, text)
import Html.Styled.Attributes exposing (css)
import OptimizedDecoder
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.ImagePath as ImagePath
import Secrets
import Tailwind.Utilities as Tw


type alias Model =
    ()


type alias Msg =
    Never


type alias RouteParams =
    {}


page : Page RouteParams Data
page =
    Page.singleRoute
        { head = head
        , data = data
        }
        |> Page.buildNoState { view = view }


type alias Repo =
    { stars : Int
    }



--
--
--projects : DataSource (List Project)
--projects =
--    DataSource.combine
--        [ githubProjects
--        , paidProjects
--        ]
--        |> DataSource.map List.concat
--
--
--paidProjects : DataSource (List Project)
--paidProjects =
--    DataSource.succeed
--        [ { openSource = False
--          , name = "elm-ts-interop-pro"
--          , url = "https://elm-ts-interop.com"
--          }
--        ]
--
--
--githubProjects : DataSource (List Project)
--githubProjects =
--    DataSource.Http.get (Secrets.succeed "https://api.github.com/users/dillonkearns/repos")
--        (OptimizedDecoder.list
--            (OptimizedDecoder.map3 Project
--                (OptimizedDecoder.succeed True)
--                (OptimizedDecoder.field "name" OptimizedDecoder.string)
--                (OptimizedDecoder.field "url" OptimizedDecoder.string)
--            )
--        )


type alias Project =
    { name : String
    , description : String
    , repo : Repo
    }


data : DataSource (List Project)
data =
    Glob.succeed
        (\projectName filePath ->
            DataSource.map2 (Project projectName)
                (DataSource.File.request filePath DataSource.File.body)
                (repo projectName)
        )
        |> Glob.ignore (Glob.literal "projects/")
        |> Glob.capture Glob.wildcard
        |> Glob.ignore (Glob.literal ".txt")
        |> Glob.capture Glob.fullFilePath
        |> Glob.toDataSource
        |> DataSource.resolve


repo : String -> DataSource Repo
repo repoName =
    DataSource.Http.get
        (Secrets.succeed ("https://api.github.com/repos/dillonkearns/" ++ repoName))
        (OptimizedDecoder.map Repo
            (OptimizedDecoder.field "stargazers_count" OptimizedDecoder.int)
        )


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "elm-pages"
        , image =
            { url = ImagePath.build [ "TODO" ]
            , alt = "elm-pages logo"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = "TODO"
        , locale = Nothing
        , title = "TODO title" -- metadata.title -- TODO
        }
        |> Seo.website


type alias Data =
    List Project


view :
    StaticPayload Data RouteParams
    -> Document Msg
view static =
    { title = "Projects"
    , body =
        Document.ElmCssView
            [ div
                [ css
                    [ Tw.pt_32
                    , Tw.px_16
                    ]
                ]
                (static.data
                    |> List.map
                        (\project ->
                            text (project.name ++ ": " ++ project.description)
                        )
                )
            ]
    }