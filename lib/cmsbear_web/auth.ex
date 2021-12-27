defmodule CmsbearWeb.Auth do
  alias Plug.Conn

  def record_login(conn, email) do
    conn
    |> Conn.put_session(:login_time, Timex.now)
    |> Conn.put_session(:logged_in_email, email)
  end

  def is_logged_in_as_owner(conn) do
    Conn.get_session(conn, :logged_in_email) == Application.get_env(:cmsbear, :owner_email)
  end
end
