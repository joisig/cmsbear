defmodule CmsbearWeb.AssetsPlug do
  @behaviour Plug
  alias Plug.Static
  alias Cmsbear.ReadBear
  alias CmsbearWeb.Auth

  @impl true
  def init(_) do
    :ok
  end

  @impl true
  def call(conn, :ok) do
    # We don't do this in init because then we can't take the file_root
    # as an environment variable. Plug init values are done at compile
    # time, not at runtime.
    root = Application.get_env(:cmsbear, :file_root)
    bear_root = case Application.get_env(:cmsbear, :use_local_bimg_and_bfile, nil) do
      true -> Path.join(root, "symlinks")
      _ -> root
    end

    case conn.path_info do
      [_, "..", _] -> conn
      [_, _, ".."] -> conn
      ["bimg", _, _] -> call_when_asset(conn, bear_root)
      ["bfile", _, _] -> call_when_asset(conn, bear_root)
      _ -> conn  # Forward to the rest of the pipeline
    end
  end

  def call_when_asset(conn, bear_root) do
    [_, file_uid, filename] = conn.path_info

    note_texts = ReadBear.notes_by_file(file_uid, filename)
    |> Enum.map(&(&1.text))
    case Auth.can_access_content?(conn, note_texts) do
      true ->
        # We do the init here rather than in the init function above, because that is what we'll
        # need to do if/when we add multi-account support (each account will have its own static root).
        opts = Static.init([at: "/", from: bear_root, only: ["bimg", "bfile"]])
        Static.call(conn, opts)
      false ->
        conn  # Forward to the rest of the pipeline
    end
  end
end
