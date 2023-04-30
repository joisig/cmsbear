defmodule CmsbearWeb.Router do
  use CmsbearWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_live_flash
    plug :put_root_layout, {CmsbearWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  import CmsbearWeb.Auth
  pipeline :api_auth do
    plug :api_auth_plug
  end

  pipeline :owner_auth do
    plug :owner_auth_plug
  end

  # Enables LiveDashboard behind owner-only auth.
  import Phoenix.LiveDashboard.Router
  scope "/" do
    pipe_through :browser
    pipe_through :owner_auth

    live_dashboard "/phxdash", metrics: CmsbearWeb.Telemetry
  end

  scope "/api", CmsbearWeb do
    pipe_through :api
    pipe_through :api_auth

    get "/hashes", AssetController, :hashes

    post "/up/db", AssetController, :upsert_db
    post "/up/image/:guid/:filename", AssetController, :upsert_image
    post "/up/file/:guid/:filename", AssetController, :upsert_file
  end

  scope "/", CmsbearWeb do
    pipe_through :browser

    get "/innskra", OidcController, :initiate
    get "/auth/oidc/initiate", OidcController, :initiate
    get "/auth/oidc/callback", OidcController, :signin

    get "/", PageController, :index
    get "/:slug", PageController, :by_slug
    get "/:slug1/:slug2", PageController, :by_slug
    get "/:slug1/:slug2/:slug3", PageController, :by_slug
    get "/:slug1/:slug2/:slug3/:slug4", PageController, :by_slug
    get "/:slug1/:slug2/:slug3/:slug4/:slug5", PageController, :by_slug
    get "/:slug1/:slug2/:slug3/:slug4/:slug5/:slug6", PageController, :by_slug
    get "/:slug1/:slug2/:slug3/:slug4/:slug5/:slug6/:slug7", PageController, :by_slug
    get "/:slug1/:slug2/:slug3/:slug4/:slug5/:slug6/:slug7/:slug8", PageController, :by_slug
  end
end
