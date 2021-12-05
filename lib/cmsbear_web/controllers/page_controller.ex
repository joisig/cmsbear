defmodule CmsbearWeb.PageController do
  use CmsbearWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
