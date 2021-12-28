defmodule CmsbearWeb.Auth do
  alias Plug.Conn
  alias Cmsbear.Markup

  def record_login(conn, email) do
    conn
    |> Conn.put_session(:login_time, Timex.now)
    |> Conn.put_session(:logged_in_email, email)
  end

  def is_logged_in_as_owner?(conn) do
    was_owner = Conn.get_session(conn, :logged_in_email) == Application.get_env(:cmsbear, :owner_email)
    now = Timex.now()
    login_time = case Conn.get_session(conn, :login_time) do
      nil -> Timex.subtract(now, Timex.Duration.from_days(10 * 365))
      t -> t
    end
    not_too_old = Timex.diff(now, login_time, :days) < 30
    was_owner and not_too_old
  end

  def can_access_content?(conn, notes_text) when is_list(notes_text) do
    can_access_content?(conn, fn -> notes_text end)
  end
  def can_access_content?(conn, get_notes_text_fn) do
    case is_logged_in_as_owner?(conn) do
      true ->
        true
      false ->
        public_tag = Application.get_env(:cmsbear, :public_tag)
        notes_text = get_notes_text_fn.()
        [] != Enum.filter(notes_text, &(public_tag in Markup.tags(&1)))
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
