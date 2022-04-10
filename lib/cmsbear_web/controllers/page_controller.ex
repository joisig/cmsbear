defmodule CmsbearWeb.PageController do
  use CmsbearWeb, :controller

  alias Cmsbear.ReadBear
  alias Cmsbear.Markup
  alias CmsbearWeb.Auth

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def get_canonical_or_static(path) do
    case ReadBear.canonical_slug_notes()[path] do
      nil ->
        case ReadBear.static_files("staticfile")[path] do
          nil ->
            nil
          %{mime: mime, body: body} ->
            {:static, mime, body}
        end
      note ->
        {:note, note}
    end
  end

  def serve_result_of_get_canonical_or_static(conn, result_of_get_canonical_or_static) do
    case result_of_get_canonical_or_static do
      nil ->
        conn |> resp(404, "")
      {:static, mime, body} ->
        conn
        |> put_resp_content_type(mime)
        |> send_resp(200, body)
      {:note, note} ->
        serve_note(conn, note)
    end
  end

  def serve_note(conn, note) do
    case Auth.can_access_content?(conn, [note.text]) do
      true ->
        conn |> html(Markup.note_to_html(note.text))
      _ ->
        conn |> resp(404, "")
    end
  end

  def by_slug(conn, %{"slug1" => slug1, "slug2" => slug2, "slug3" => slug3}) do
    path = "/#{slug1}/#{slug2}/#{slug3}"
    serve_result_of_get_canonical_or_static(conn, get_canonical_or_static(path))
  end
  def by_slug(conn, %{"slug1" => slug1, "slug2" => slug2}) do
    path = "/#{slug1}/#{slug2}"
    serve_result_of_get_canonical_or_static(conn, get_canonical_or_static(path))
  end

  def by_slug(conn, %{"slug" => slug}) do
    case get_canonical_or_static("/" <> slug) do
      nil ->
        title_components = String.split(slug, "_")
        # TODO
        # Redirect to canonical URL that includes ID?
        # Or preferentially match exactly to slug that is embedded in a specific way in document?
        [note|_rest] = ReadBear.notes_by_title(title_components)

        serve_note(conn, note)
      results ->
        serve_result_of_get_canonical_or_static(conn, results)
    end
  end

  # TODO add way to browse a particular tag

  # TODO extract tags and show separately (e.g. in sidebar)

  # TODO make it look pretty

  # TODO RSS feed

  # TODO add the concept of an account (i.e. one for each Bear database uploader)
end
