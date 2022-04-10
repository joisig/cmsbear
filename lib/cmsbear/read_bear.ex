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

  def notes_by_title(title_components) do
    {:ok, conn} = open_db()
    {:ok, statement} = Sqlite3.prepare(conn,
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ztitle like ?1")
    :ok = Sqlite3.bind(conn, statement, [make_like(title_components)])
    results = db_results(conn, statement, [:text, :title, :uid], [])
    :ok = Sqlite3.release(conn, statement)
    results
  end

  def note_by_id(id) do
    {:ok, conn} = open_db()
    {:ok, statement} = Sqlite3.prepare(conn,
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZUNIQUEIDENTIFIER = ?1")
    :ok = Sqlite3.bind(conn, statement, [id])
    [result] = db_results(conn, statement, [:text, :title, :uid], [])
    :ok = Sqlite3.release(conn, statement)
    result
  end

  def notes_by_content(content_string) do
    {:ok, conn} = open_db()
    {:ok, statement} = Sqlite3.prepare(conn,
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZTEXT like ?1")
    :ok = Sqlite3.bind(conn, statement, ["%#{content_string}%"])
    results = db_results(conn, statement, [:text, :title, :uid], [])
    :ok = Sqlite3.release(conn, statement)
    results
  end

  def special_files() do
    %{
      static: static_files("staticfile"),
      layout: static_files("layout"),
      include: static_files("include")
    }
  end

  def static_files(of_type) do
    {:ok, conn} = open_db()
    {:ok, statement} = Sqlite3.prepare(conn,
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZTEXT like ?1")
    :ok = Sqlite3.bind(conn, statement, ["%#cmsbear/#{of_type}%"])
    results = db_results(conn, statement, [:text, :title, :uid], [])
    :ok = Sqlite3.release(conn, statement)
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
