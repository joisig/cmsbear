defmodule CmsbearWeb.Auth do
  alias Plug.Conn
  alias Cmsbear.Markup

  def record_login(conn, email) do
    conn
    |> Conn.put_session(:login_time, Timex.now)
    |> Conn.put_session(:logged_in_email, email)
  end

  def get_owner_email() do
    Application.get_env(:cmsbear, :owner_email)
  end

  def get_public_tags() do
    ["#cmsbear/page", "#cmsbear/post"]  #TODO nice if these were configurable
  end

  def is_logged_in_as_owner?(conn) do
    was_owner = Conn.get_session(conn, :logged_in_email) == get_owner_email()
    now = Timex.now()
    login_time = case Conn.get_session(conn, :login_time) do
      nil -> Timex.subtract(now, Timex.Duration.from_days(10 * 365))
      t -> t
    end
    not_too_old = Timex.diff(now, login_time, :days) < 30
    was_owner and not_too_old
  end

  def is_public(note_text) when is_binary(note_text), do: is_public([note_text])
  def is_public(note_texts) when is_list(note_texts) do
    public_tags = get_public_tags()
    [] != Enum.filter(note_texts, fn text ->
      0 != MapSet.size(MapSet.intersection(MapSet.new(public_tags), MapSet.new(Markup.tags(text))))
    end)
  end

  def can_access_content?(conn, note_texts) when is_list(note_texts) do
    case is_logged_in_as_owner?(conn) do
      true ->
        true
      false ->
        is_public(note_texts)
    end
  end

  def has_api_auth?(conn) do
    key = Application.get_env(:cmsbear, :api_key)
    [("Basic " <> key)] == Conn.get_req_header(conn, "authorization")
  end

  def api_auth_plug(conn, _opts) do
    case has_api_auth?(conn) do
      true -> conn
      false -> conn |> Conn.resp(403, "") |> Conn.halt()
    end
  end

  def owner_auth_plug(conn, _opts) do
    case is_logged_in_as_owner?(conn) do
      true -> conn
      false -> conn |> Conn.resp(403, "") |> Conn.halt()
    end
  end
end
