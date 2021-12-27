defmodule CmsbearWeb.PageController do
  use CmsbearWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  # TODO do as an output plugin for Earmark?
  def replace_image_links(html) do
    Regex.replace(~r/\[image:([^]]+)]/, html, fn _, path -> "<img src='/bimg/#{path}' width=100%/>" end)
  end

  def replace_file_links(html) do
    Regex.replace(~r/\[file:([^\/]+\/([^]]+))]/, html, fn _, path, filename -> "<a href='/bfile/#{path}'>#{filename}</a>" end)
  end

  def by_slug(conn, %{"slug" => slug}) do
    title_components = String.split(slug, "_")
    # TODO
    # Redirect to canonical URL that includes ID?
    # Or preferentially match exactly to slug that is embedded in a specific way in document?
    [article|_rest] = Cmsbear.ReadBear.notes_by_title(title_components)
    {:ok, html, _} = Earmark.as_html(article.text)
    html = html |> replace_image_links() |> replace_file_links()
    conn |> html(html)
  end

  # TODO add access control

  # TODO add way to browse a particular tag

  # TODO extract tags and show separately (e.g. in sidebar)

  # TODO make it look pretty

  # TODO how to access control files and images? Should be determined by access level of least-restrictive document(s) that references that file...

  # TODO RSS feed

  # TODO add the concept of an account (i.e. one for each Bear database uploader)
end
