defmodule CmsbearWeb.OidcController do
  use CmsbearWeb, :controller

  alias CmsbearWeb.Auth

  require Logger

  def initiate(conn, _params) do
    conn |> redirect(external: get_auth_url())
  end

  def get_auth_url() do
    config = "google"
    OpenIDConnect.authorization_uri(:google, %{"state" => "#{config}:1"})
  end

  def signin(conn, %{"state" => state} = params) do
    [config_str, company_id_str] = String.split(state, ":")
    _company_id = String.to_integer(company_id_str)
    config = String.to_existing_atom(config_str)

    {:ok, tokens} = OpenIDConnect.fetch_tokens(config, params)
    {:ok, claims} = OpenIDConnect.verify(config, tokens["id_token"])

    %{"email" => email, "exp" => expiry_unix} = claims

    expiry_time = Timex.from_unix(expiry_unix)
    -1 = Timex.compare(Timex.now, expiry_time)

    # email_verified is always set to true for Google.
    true = Map.get(claims, "email_verified", false)

    IO.inspect claims

    conn
    |> Auth.record_login(email)
    |> redirect(external: "/")
  end

  def get_oidc_config() do
    Application.get_env(:cmsbear, :openid_connect_providers) || []
  end
end
