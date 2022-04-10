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

  def notes_by_title(title_components) do
    get_results(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ztitle like ?1",
      [make_like(title_components)])
  end

  def note_by_id(id) do
    get_results(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZUNIQUEIDENTIFIER = ?1",
      [id])
  end

  def notes_by_content(content_string) do
    get_results(
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZTEXT like ?1",
      ["%#{content_string}%"])
  end

  def special_files() do
    %{
      static: static_files("staticfile"),
      layout: static_files("layout"),
      include: static_files("include"),
      hardcoded_slugs: hardcoded_slug_files()
    }
  end

  def hardcoded_slug_files() do

  end

  def static_files(of_type) do
    results = get_results(
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
    case Regex.named_captures(~r/^.*\#cmsbear\/#{of_type}\n.*?```\n?name:(?<name>[^\n]+)\n.*?mime:(?<mime>[^\n]+)\n.*?====*\n(?<body>.*)```.*?$/s, note) do
      nil ->
        %{}
      map ->
        map
    end
    |> Enum.map(fn {key, val} -> {String.to_atom(key), val} end)
    |> Enum.into(%{})
  end
end
