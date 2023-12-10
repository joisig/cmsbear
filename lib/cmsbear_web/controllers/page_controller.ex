defmodule CmsbearWeb.PageController do
  use CmsbearWeb, :controller

  alias Cmsbear.ReadBear
  alias Cmsbear.Markup
  alias CmsbearWeb.Auth

  def index(conn, _params) do
    by_slug(conn, %{"slug" => ""})
  end

  def get_canonical_or_static(path) when is_binary(path) do
    case ReadBear.get_permalink_note(path) do
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
        # Static files are not access controlled
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
        html = Markup.note_to_html(note.text, note.uid)
        with_layout = Cmsbear.Render.load_files_and_render(html, note.front_matter)
        case note.front_matter["layout"] do
          "atomxml" ->
            # Quick hack to get the right content type here...
            conn |> put_resp_content_type("application/atom+xml") |> send_resp(200, with_layout)
          _ ->
            conn |> html(with_layout)
        end
      _ ->
        conn |> resp(404, "")
    end
  end

  def by_slug(conn, %{"slug1" => slug1, "slug2" => slug2, "slug3" => slug3, "slug4" => slug4, "slug5" => slug5, "slug6" => slug6, "slug7" => slug7, "slug8" => slug8}) do
    path = "/#{slug1}/#{slug2}/#{slug3}/#{slug4}/#{slug5}/#{slug6}/#{slug7}/#{slug8}"
    serve_result_of_get_canonical_or_static(conn, get_canonical_or_static(path))
  end
  def by_slug(conn, %{"slug1" => slug1, "slug2" => slug2, "slug3" => slug3, "slug4" => slug4, "slug5" => slug5, "slug6" => slug6, "slug7" => slug7}) do
    path = "/#{slug1}/#{slug2}/#{slug3}/#{slug4}/#{slug5}/#{slug6}/#{slug7}"
    serve_result_of_get_canonical_or_static(conn, get_canonical_or_static(path))
  end
  def by_slug(conn, %{"slug1" => slug1, "slug2" => slug2, "slug3" => slug3, "slug4" => slug4, "slug5" => slug5, "slug6" => slug6}) do
    path = "/#{slug1}/#{slug2}/#{slug3}/#{slug4}/#{slug5}/#{slug6}"
    serve_result_of_get_canonical_or_static(conn, get_canonical_or_static(path))
  end
  def by_slug(conn, %{"slug1" => slug1, "slug2" => slug2, "slug3" => slug3, "slug4" => slug4, "slug5" => slug5}) do
    path = "/#{slug1}/#{slug2}/#{slug3}/#{slug4}/#{slug5}"
    serve_result_of_get_canonical_or_static(conn, get_canonical_or_static(path))
  end
  def by_slug(conn, %{"slug1" => slug1, "slug2" => slug2, "slug3" => slug3, "slug4" => slug4}) do
    path = "/#{slug1}/#{slug2}/#{slug3}/#{slug4}"
    serve_result_of_get_canonical_or_static(conn, get_canonical_or_static(path))
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
        [note|_rest] = ReadBear.notes_by_title(title_components)

        case Auth.can_access_content?(conn, [note.text]) do
          true ->
            case ReadBear.get_permalink(note) do
              nil ->
                # TODO this isn't reliable, needs fixing. Try for example /pdf_download
                # for one that's broken, but /covid_antigen is OK.
                case make_full_slug(note.title) do
                  "/" <> ^slug ->
                    serve_note(conn, note)
                  new_slug ->
                    conn |> redirect(to: new_slug)
                end
              slug ->
                conn |> redirect(to: slug)
            end
          false ->
            conn |> resp(404, "")
        end
      results ->
        serve_result_of_get_canonical_or_static(conn, results)
    end
  end

  def make_full_slug(title) when is_binary(title) do
    downcased_and_trimmed = title |> String.downcase() |> String.trim()
    removed = Regex.replace(~r/[^A-Za-z0-9-\s]/s, downcased_and_trimmed, "", [:global])
    unspaced = Regex.replace(~r/\s+/s, removed, "_", [:global])
    "/" <> unspaced
  end

  # TODO add way to browse a particular tag

  # TODO extract tags and show separately (e.g. in sidebar)

  # TODO add the concept of an account (i.e. one for each Bear database uploader)

  # TODO date_to_xmlschema (see post layout in Bear)

  # TODO make off-site links target="_blank" by default
end
