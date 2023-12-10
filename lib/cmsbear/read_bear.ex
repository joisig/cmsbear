defmodule Cmsbear.ReadBear do
  @doc """
  Never write to the database - only read!
  """

  alias Exqlite.Sqlite3;

  def path2like(path) do
    String.split(path, "_") |> make_like()
  end

  def make_like(components) do
    percents = List.duplicate("%", length(components) + 1)
    parts = (Enum.zip([percents, components]) |> Enum.flat_map(fn {l, r} -> [l, r] end)) ++ ["%"]
    Enum.join(parts, "")
  end

  def get_db_path() do
    case Application.get_env(:cmsbear, :local_bear_database_path) do
      nil ->
        Application.get_env(:cmsbear, :file_root) <> "/bear.sqlite"
      path ->
        path
    end
  end

  def open_db() do
    get_db_path() |> Sqlite3.open(mode: :readonly)
  end

  def db_results(conn, statement, headings, acc) do
    case Sqlite3.step(conn, statement) do
      {:row, row} ->
        acc = [Enum.zip(headings, row) |> Enum.into(%{})|acc]
        db_results(conn, statement, headings, acc)
      :done ->
        acc |> Enum.reverse()
    end
  end

  def get_results(query, params \\ []) do
    {:ok, conn} = open_db()
    {:ok, statement} = Sqlite3.prepare(conn, query)
    :ok = Sqlite3.bind(conn, statement, params)
    results = db_results(conn, statement, [:text, :title, :uid, :creation_date, :modification_date], [])
    :ok = Sqlite3.release(conn, statement)
    results
  end

  def get_notes(query, params \\ []) do
    get_results(query, params)
    |> Enum.map(&process_timestamps/1)
    |> Enum.map(&process_front_matter/1)
    |> order_notes_by_main_date()
  end

  def get_file_uid(path, uid) do
    {:ok, conn} = open_db()
    {:ok, statement} = Sqlite3.prepare(
      conn, "select f.ZUNIQUEIDENTIFIER from ZSFNOTEFILE f inner join ZSFNOTE n on f.ZNOTE = n.Z_PK where n.ZUNIQUEIDENTIFIER = ?1 and f.ZFILENAME = ?2")
    :ok = Sqlite3.bind(conn, statement, [uid, path])
    results = db_results(conn, statement, [:file_uid], [])
    :ok = Sqlite3.release(conn, statement)
    case results do
      [%{file_uid: file_uid}] ->
        file_uid
      _ ->
        IO.inspect {:error_getting_file_uid, path, uid, results}
        "missingimage"
    end
  end

  def fm_val_to_timestamp(fm, key) do
    case Map.get(fm, key, nil) do
      nil ->
        fm
      val ->
        {ok, time} = Elixir.Timex.Parse.DateTime.Parser.parse(val, "{ISO:Extended:Z}")
        Map.put(fm, key, time)
    end
  end

  def fm_default_value(fm, key, default) do
    case Map.get(fm, key, nil) do
      nil ->
        Map.put(fm, key, default)
      _ ->
        fm
    end
  end

  def fm_date_human(%{"date" => date, "modification_date" => modification_date} = fm) do
    {:ok, human_date} = Timex.format(date, "%Y-%m-%d", :strftime)
    {:ok, human_modification_date} = Timex.format(date, "%Y-%m-%d", :strftime)
    fm
    |> Map.put("human_date", human_date)
    |> Map.put("human_modification_date", human_modification_date)
  end

  @spec fm_date_itemprop(map) :: map
  def fm_date_itemprop(%{"date" => date, "modification_date" => modification_date} = fm) do
    {:ok, itemprop_date} = Timex.format(date, "%Y-%m-%dT%H:%M:%S+00:00", :strftime)
    {:ok, itemprop_modification_date} = Timex.format(modification_date, "%Y-%m-%dT%H:%M:%S+00:00", :strftime)
    fm
    |> Map.put("itemprop_date", itemprop_date)
    |> Map.put("itemprop_modification_date", itemprop_modification_date)
  end

  def fm_canonical_url(%{"site_base_url" => base} = fm) do
    case Map.get(fm, "canonical_url", "") do
      "" ->
        case Map.get(fm, "permalink", "") do
          "" ->
            fm
          slug ->
            Map.put(fm, "canonical_url", base <> slug)
        end
      _url ->
        fm
    end
  end

  def fm_canonical_link(fm) do
    link = case Map.get(fm, "canonical_url", nil) do
      nil ->
        fm
      url ->
        Map.put(fm, "canonical_link", "<link rel='canonical' href='#{url}' />")
    end
  end

  def strip_title_for_layout?(layout) do
    layout in ["post", "page", "home", "home_item"]  # TODO
  end

  def process_front_matter(%{text: text} = note) do
    front_matter = get_note_front_matter(text)
    |> fm_val_to_timestamp("date")
    |> fm_default_value("description", "")
    |> fm_default_value("date", note.modification_date)
    |> fm_default_value("modification_date", note.modification_date)
    |> fm_date_human()
    |> fm_date_itemprop()
    |> fm_canonical_url()
    |> fm_canonical_link()

    text = case strip_title_for_layout?(Map.get(front_matter, "layout", "default")) do
      true -> text_without_front_matter_or_title(text)
      _ -> text_without_front_matter(text)
    end

    # Title is handled specially, as we want to modify the note.title to match the front matter
    # title if set, otherwise use the note.title as the default title in front matter.
    override_note = case Map.get(front_matter, "title", nil) do
      nil -> %{front_matter: Map.put(front_matter, "title", note.title), text: text}
      front_matter_title -> %{front_matter: front_matter, title: front_matter_title, text: text}
    end
    Map.merge(note, override_note)
  end

  def process_timestamps(%{modification_date: mod, creation_date: create} = note) do
    %{note | modification_date: bearstamp_to_timex(mod), creation_date: bearstamp_to_timex(create)}
  end

  def text_without_front_matter(text) when is_binary(text) do
    Regex.split(~r/```\n?cmsbear-frontmatter\n(?<frontmatter>.*?)```/s, text)
    |> Enum.join("\n")
  end

  def text_without_title(text) when is_binary(text) do
    lines = case String.split(text, "\n") do
      ["# " <> _title_text|rest] -> rest
      all -> all
    end
    |> Enum.join("\n")
  end

  def text_without_front_matter_or_title(text) when is_binary(text) do
    text
    |> text_without_front_matter()
    |> text_without_title()
  end

  def get_kv_section(text, section_id) do
    case Regex.named_captures(~r/^.*?```\n?(#{section_id})\n(?<lines>.*?)```.*?$/s, text) do
      nil ->
        ""
      %{"lines" => lines} ->
        lines
    end
    |> YamlElixir.read_from_string!()
  end

  def get_note_front_matter(text) when is_binary(text) do
    # TODO - site title, language, author from config
    get_kv_section(text, "cmsbear-frontmatter")
    |> Enum.into(%{
      "layout" => "default",
      "language" => "en",
      "site_title" => "joisig gone awol",
      "site_description" => "Jói Sigurdsson's post-employment adventures",
      "site_base_url" => "https://joisig.com",
      "author" => "joisig"})
  end

  def notes_by_title(title_components) do
    get_notes(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER, ZCREATIONDATE, ZMODIFICATIONDATE from zsfnote where zencrypted = 0 and zarchived = 0 and ztrashed =0 and ztitle like ?1",
      [make_like(title_components)])
  end

  def note_by_id(id) do
    get_notes(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER, ZCREATIONDATE, ZMODIFICATIONDATE from zsfnote where zencrypted = 0 and zarchived = 0 and ztrashed =0 and ZUNIQUEIDENTIFIER = ?1",
      [id])
  end

  def notes_by_file(file_uid, file_path) do
    notes = get_notes(
      "select n.ZTEXT, n.ZTITLE, n.ZUNIQUEIDENTIFIER, n.ZCREATIONDATE, n.ZMODIFICATIONDATE from ZSFNOTE n inner join ZSFNOTEFILE f on f.ZNOTE = n.Z_PK where n.zencrypted = 0 and n.zarchived = 0 and n.ztrashed = 0 and f.ZUNIQUEIDENTIFIER = ?1 and f.ZFILENAME = ?2",
      [file_uid, file_path])
  end

  def notes_by_content(content_string, exclude_frontmatter_matches \\ true) do
    notes = get_notes(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER, ZCREATIONDATE, ZMODIFICATIONDATE from zsfnote where zencrypted = 0 and zarchived = 0 and ztrashed =0 and ZTEXT like ?1",
      ["%#{content_string}%"])
    case exclude_frontmatter_matches do
      true ->
        Enum.filter(notes, fn (note) ->
          String.contains?(note.text, content_string)
        end)
      _ ->
        notes
    end
  end

  def special_files() do
    %{
      static: static_files("staticfile"),
      layout: static_files("layout"),
      include: static_files("include")
    }
  end

  def get_permalink(note) when is_map(note) do
    Map.get(note.front_matter, "permalink", nil)
  end

  def order_notes_by_main_date(notes) do
    Enum.sort(notes, fn (left, right) ->
      Timex.compare(Map.get(left.front_matter, "date"), Map.get(right.front_matter, "date")) >= 0
    end)
  end

  @spec permalink_notes :: none
  def permalink_notes() do
    get_notes(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER, ZCREATIONDATE, ZMODIFICATIONDATE from zsfnote where zencrypted = 0 and zarchived = 0 and ztrashed =0 and ZTEXT like ?1",
      ["%permalink:%"])
    |> Enum.filter(fn item -> get_permalink(item) != nil end)
    |> Enum.map(fn %{front_matter: %{"permalink" => slug}} = item -> {slug, item} end)
    |> Enum.into(%{})
  end

  def get_permalink_note(path) do
    notes = permalink_notes()
    Map.get(notes, path, Map.get(notes, path <> "/", nil))
  end

  def static_files(of_type) do
    results = get_notes(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER, ZCREATIONDATE, ZMODIFICATIONDATE from zsfnote where zencrypted = 0 and zarchived = 0 and ztrashed =0 and ZTEXT like ?1",
      ["%#cmsbear/#{of_type}%"])
    Enum.map(results, fn obj -> parse_static_file_note(of_type, obj.text) end)
    |> Enum.flat_map(fn
      %{name: name} = item -> [{name, item}]
      _ -> []
    end)
    |> Enum.into(%{})
  end

  def parse_static_file_note(of_type, note) do
    case Regex.named_captures(~r/^.*\#cmsbear\/#{of_type}\n.*?```\n?name:\s*(?<name>[^\n]+)\n.*?mime:\s*(?<mime>[^\n]+)\n.*?====*\n(?<body>.*)```.*?$/s, note) do
      nil ->
        %{}
      map ->
        map
    end
    |> Enum.map(fn {key, val} -> {String.to_atom(key), val} end)
    |> Enum.into(%{})
  end

  def bearstamp_to_timex(ts) when is_float(ts) do
    bearstamp_to_timex(trunc(ts))
  end
  def bearstamp_to_timex(ts) when is_integer(ts) do
    Timex.add(
      Timex.DateTime.new!(Timex.Date.new!(2001, 1, 1), Timex.Time.new!(0,0,0)),
      Timex.Duration.from_seconds(ts)
    )
  end
end
