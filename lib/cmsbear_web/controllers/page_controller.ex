defmodule CmsbearWeb.PageController do
  use CmsbearWeb, :controller

  alias Cmsbear.ReadBear
  alias Cmsbear.Markup
  alias CmsbearWeb.Auth

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def by_slug(conn, %{"slug" => slug}) do
    title_components = String.split(slug, "_")
    # TODO
    # Redirect to canonical URL that includes ID?
    # Or preferentially match exactly to slug that is embedded in a specific way in document?
    [article|_rest] = ReadBear.notes_by_title(title_components)

    case Auth.can_access_content?(conn, [article.text]) do
      true ->
        conn |> html(Markup.note_to_html(article.text))
      _ ->
        conn |> resp(404, "")
    end
  end

  # TODO controller for retrieving images and files
  # TODO how to access control files and images? Should be determined by access level of least-restrictive document(s) that references that file...

  # TODO add upload mechanism

  # TODO add way to browse a particular tag

  # TODO extract tags and show separately (e.g. in sidebar)

  # TODO make it look pretty

  # TODO RSS feed

  # TODO add the concept of an account (i.e. one for each Bear database uploader)

end
