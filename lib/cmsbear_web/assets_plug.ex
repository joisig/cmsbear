defmodule CmsbearWeb.AssetsPlug do
  @behaviour Plug
  alias Plug.Static
  alias Cmsbear.ReadBear
  alias CmsbearWeb.Auth

  @impl true
  def init([bear_root: root] = opts) do
    root = case Application.get_env(:cmsbear, :use_local_bimg_and_bfile, nil) do
      true -> Path.join(root, "symlinks")
      _ -> root
    end
    [bear_root: root]
  end

  @impl true
  def call(conn, [bear_root: bear_root]) do
    case conn.path_info do
      [_, "..", _] -> conn
      [_, _, ".."] -> conn
      ["bimg", _, _] -> call_when_asset(conn, bear_root)
      ["bfile", _, _] -> call_when_asset(conn, bear_root)
      _ -> conn  # Forward to the rest of the pipeline
    end
  end

  def call_when_asset(conn, bear_root) do
    link_text = case conn.path_info do
      ["bimg", guid, filename] -> "[image:#{guid}/#{URI.decode(filename)}]"
      ["bfile", guid, filename] -> "[file:#{guid}/#{URI.decode(filename)}]"
    end

    note_texts = ReadBear.notes_by_content(link_text)
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
