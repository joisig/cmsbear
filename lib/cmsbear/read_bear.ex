defmodule Cmsbear.ReadBear do
  alias Exqlite.Sqlite3;

  def path2like(path) do
    String.split(path, "_") |> make_like()
  end

  def make_like(components) do
    percents = List.duplicate("%", length(components) + 1)
    parts = (Enum.zip([percents, components]) |> Enum.flat_map(fn {l, r} -> [l, r] end)) ++ ["%"]
    Enum.join(parts, "")
  end

  def open_db() do
    Application.get_env(:cmsbear, :file_root) <> "/bear.sqlite"
    |> Sqlite3.open()
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
    results = db_results(conn, statement, [:text, :title, :uid], [])
    :ok = Sqlite3.release(conn, statement)
    results
  end

  def get_notes(query, params \\ []) do
    get_results(query, params)
    |> Enum.map(&process_front_matter/1)
  end

  def process_front_matter(%{text: text} = note) do
    front_matter = get_note_front_matter(text)
    override_note = case Map.get(front_matter, "title", nil) do
      nil -> %{front_matter: Map.put(front_matter, "title", note.title), text: text_without_front_matter(text)}
      front_matter_title -> %{front_matter: front_matter, title: front_matter_title, text: text_without_front_matter(text)}
    end
    Map.merge(note, override_note)
  end

  def text_without_front_matter(text) when is_binary(text) do
    Regex.split(~r/```\n?FRONTMATTER\n(?<frontmatter>.*?)```/s, text)
    |> Enum.join("\n")
  end

  def get_note_front_matter(text) when is_binary(text) do
    front_matter = case Regex.named_captures(~r/^.*?```\n?FRONTMATTER\n(?<frontmatter>.*?)```.*?$/s, text) do
      nil ->
        []
      %{"frontmatter" => lines} ->
        String.split(lines, "\n")
    end
    |> Enum.flat_map(fn line ->
      case Regex.named_captures(~r/\s*(?<key>[a-zA-Z0-9_]+):\s*(?<val>.*)/, line) do
        nil ->
          []
        %{"key" => key, "val" => val} -> [{key, val}]
      end
    end)
    |> Enum.into(%{"layout" => "default", "language" => "en", "site_title" => "joisig gone awol", "author" => "joisig"})
  end

  def notes_by_title(title_components) do
    get_notes(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ztitle like ?1",
      [make_like(title_components)])
  end

  def note_by_id(id) do
    get_notes(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZUNIQUEIDENTIFIER = ?1",
      [id])
  end

  def notes_by_content(content_string) do
    get_notes(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZTEXT like ?1",
      ["%#{content_string}%"])
  end

  def special_files() do
    %{
      static: static_files("staticfile"),
      layout: static_files("layout"),
      include: static_files("include")
    }
  end

  def get_canonical_slug(note) when is_map(note) do
    Map.get(note.front_matter, "canonical_slug", nil)
  end

  def canonical_slug_notes() do
    get_notes(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZTEXT like ?1",
      ["%canonical_slug:%"])
    |> Enum.filter(fn item -> get_canonical_slug(item) != nil end)
    |> Enum.map(fn %{front_matter: %{"canonical_slug" => slug}} = item -> {slug, item} end)
    |> Enum.into(%{})
  end

  def static_files(of_type) do
    results = get_notes(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZTEXT like ?1",
      ["%#cmsbear/#{of_type}%"])
    Enum.map(results, fn obj -> parse_static_file_note(of_type, obj.text) end)
    |> Enum.flat_map(fn
      %{name: name} = item -> [{name, item}]
      _ -> []
    end)
    |> Enum.into(%{})
  end

  def parse_static_file_note(of_type, note) do
    case Regex.named_captures(~r/^.*\#cmsbear\/#{of_type}\n.*?```\n?name:\s*(?<name>[^\n]+)\n.*?mime:(?<mime>[^\n]+)\n.*?====*\n(?<body>.*)```.*?$/s, note) do
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
