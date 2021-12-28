defmodule CmsbearWeb.Auth do
  alias Plug.Conn
  alias Cmsbear.Markup

  def record_login(conn, email) do
    conn
    |> Conn.put_session(:login_time, Timex.now)
    |> Conn.put_session(:logged_in_email, email)
  end

  def is_logged_in_as_owner?(conn) do
    Conn.get_session(conn, :logged_in_email) == Application.get_env(:cmsbear, :owner_email)
  end

  def can_access_content(conn, notes_text) when is_list(notes_text) do
    can_access_content(conn, fn -> notes_text end)
  end
  def can_access_content(conn, get_notes_text_fn) do
    case is_logged_in_as_owner?(conn) do
      true ->
        true
      false ->
        public_tag = Application.get_env(:cmsbear, :public_tag)
        notes_text = get_notes_text_fn.()
        [] != Enum.filter(notes_text, &(public_tag in Markup.tags(&1)))
    end
  end
end
