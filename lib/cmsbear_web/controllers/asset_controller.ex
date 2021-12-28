defmodule CmsbearWeb.AssetController do
  use CmsbearWeb, :controller

  alias CmsbearWeb.Auth

  def hashes(conn, _params) do
    true = Auth.has_api_auth?(conn)

    json(
      conn,
      %{
        "images" => all_hashes("bimg"),
        "files" => all_hashes("bfile")
      }
    )
  end

  def upsert_image(conn, %{"guid" => guid, "filename" => filename, "upload" => upload}) do
    true = Auth.has_api_auth?(conn)

    upsert(conn, "bimg", guid, filename, upload)
  end

  def upsert_file(conn, %{"guid" => guid, "filename" => filename, "upload" => upload}) do
    true = Auth.has_api_auth?(conn)

    upsert(conn, "bfile", guid, filename, upload)
  end

  def upsert(conn, prefix, guid, filename, upload) do
    IO.inspect {conn, prefix, guid, filename, upload}
    conn |> text("ok")
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
    initial_hash_state = :crypto.hash_init(:sha)
    File.stream!(full_path, [], 16_777_216)  # Process 16 Mb at a time
    |> Enum.reduce(initial_hash_state, &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode32(case: :lower)
  end

  def path_hash(relative_path) do
    :crypto.hash(:sha, relative_path)
    |> Base.encode32(case: :lower)
  end

  def all_hashes(prefix) do
    all_paths(prefix) |> Enum.map(fn {fp, rp} ->
      %{
        ph: path_hash(rp),
        ch: file_hash(fp)
      }
    end)
  end
end
