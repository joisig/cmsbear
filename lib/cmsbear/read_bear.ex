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
    {:ok, conn} = Sqlite3.open("beardata/bear.sqlite")
    {:ok, statement} = Sqlite3.prepare(conn,
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ztitle like ?1")
    :ok = Sqlite3.bind(conn, statement, [make_like(title_components)])
    results = db_results(conn, statement, [:text, :title, :uid], [])
    :ok = Sqlite3.release(conn, statement)
    results
  end

  def note_by_id(id) do
    {:ok, conn} = Sqlite3.open("beardata/bear.sqlite")
    {:ok, statement} = Sqlite3.prepare(conn,
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZUNIQUEIDENTIFIER = ?1")
    :ok = Sqlite3.bind(conn, statement, [id])
    [result] = db_results(conn, statement, [:text, :title, :uid], [])
    :ok = Sqlite3.release(conn, statement)
    result
  end

  def notes_by_content(content_string) do
    {:ok, conn} = Sqlite3.open("beardata/bear.sqlite")
    {:ok, statement} = Sqlite3.prepare(conn,
      "select ZTEXT, ZTITLE, ZUNIQUEIDENTIFIER from zsfnote where zencrypted = 0 and zarchived = 0 and ZTEXT like ?1")
    :ok = Sqlite3.bind(conn, statement, ["%#{content_string}%"])
    results = db_results(conn, statement, [:text, :title, :uid], [])
    :ok = Sqlite3.release(conn, statement)
    results
  end
end
