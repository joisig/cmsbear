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

  scope "/", CmsbearWeb do
    pipe_through :browser

    get "/login", OidcController, :initiate
    get "/auth/oidc/initiate", OidcController, :initiate
    get "/auth/oidc/callback", OidcController, :signin

    get "/", PageController, :index
    get "/:slug", PageController, :by_slug
  end

  scope "/api", CmsbearWeb do
    pipe_through :api

    get "/hashes", AssetController, :hashes
    post "/up/image/:guid/:filename", AssetController, :upsert_image
    post "/up/file/:guid/:filename", AssetController, :upsert_file
  end

  # Other scopes may use custom stacks.
  # scope "/api", CmsbearWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: CmsbearWeb.Telemetry
    end
  end
end
