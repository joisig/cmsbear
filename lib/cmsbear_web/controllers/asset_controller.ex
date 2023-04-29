defmodule CmsbearWeb.AssetController do
  use CmsbearWeb, :controller

  def crash_if_local_db_or_local_symlinks() do
    nil = Application.get_env(:cmsbear, :local_bear_database_path)
    false = String.contains?(Application.get_env(:cmsbear, :file_root, ""), "symlinks")
    false = String.contains?(Application.get_env(:cmsbear, :file_root, ""), "net.shinyfrog.bear")
  end

  def hashes(conn, _params) do
    crash_if_local_db_or_local_symlinks()
    json(
      conn,
      %{
        "db" => file_hash(root_path("bear.sqlite")),
        "images" => all_hashes("bimg"),
        "files" => all_hashes("bfile")
      }
    )
  end

  def upsert_db(conn, %{"upload" => %Plug.Upload{path: tmp_path}}) do
    crash_if_local_db_or_local_symlinks()

    # This is really naive for now. Probably want to keep some
    # older versions and atomically switch new queries to use the latest
    # version of the DB file while the older queries get to complete
    # on older files... or do something smarter.
    case File.cp(tmp_path, root_path("bear.sqlite")) do
      :ok ->
        conn |> resp(201, "")
      {:error, posix} ->
        conn |> resp(500, Atom.to_string(posix))
    end
  end

  def upsert_image(conn, %{"guid" => guid, "filename" => filename, "upload" => upload}) do
    upsert(conn, "bimg", guid, filename, upload)
  end

  def upsert_file(conn, %{"guid" => guid, "filename" => filename, "upload" => upload}) do
    upsert(conn, "bfile", guid, filename, upload)
  end

  def upsert(conn, prefix, guid, filename, %Plug.Upload{path: tmp_path}) do
    crash_if_local_db_or_local_symlinks()
    dest_folder = Path.join([root_path(prefix)], guid)
    File.mkdir_p(dest_folder)  # Ignore error, as it may already exist
    dest_path = Path.join([dest_folder, filename])
    case File.cp(tmp_path, dest_path) do
      :ok ->
        conn |> resp(201, "")
      {:error, posix} ->
        conn |> resp(500, Atom.to_string(posix))
    end
  end

  def root_path(prefix) do
    Path.join(Application.get_env(:cmsbear, :file_root), prefix)
  end

  def all_paths(prefix) do
    root_path = root_path(prefix)
    path = Path.join([root_path, "*", "*"])
    Path.wildcard(path, match_dot: true)
    |> Enum.map(fn x -> {x, Path.relative_to(x, root_path)} end)
  end

  def file_hash(full_path) do
    case File.stat(full_path) do
      {:ok, _} ->
        initial_hash_state = :crypto.hash_init(:sha)
        File.stream!(full_path, [], 16_777_216)  # Process 16 Mb at a time
        |> Enum.reduce(initial_hash_state, &:crypto.hash_update(&2, &1))
        |> :crypto.hash_final()
        |> Base.encode32(case: :lower)
      {:error, :enoent} ->
        ""
    end
  end

  def path_hash(relative_path) do
    :crypto.hash(:sha, relative_path)
    |> Base.encode32(case: :lower)
  end

  def all_hashes(prefix) do
    all_paths(prefix) |> Enum.map(fn {fp, rp} -> {path_hash(rp), file_hash(fp)} end) |> Enum.into(%{})
  end
end
