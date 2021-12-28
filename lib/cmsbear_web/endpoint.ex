defmodule CmsbearWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :cmsbear

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_cmsbear_key",
    signing_salt: "MCrkfK0P"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :cmsbear,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt bimg bfile)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :cmsbear
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [
      :urlencoded,
      {:multipart, length: 134_217_728},  # 128 Mb if uploading multipart file
      :json
    ],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  # Could skip this here and do only when needed within this plug, then again in
  # the browser pipeline in the router. But fine for now.
  plug :fetch_session
  plug CmsbearWeb.AssetsPlug,
    bear_root: Application.get_env(:cmsbear, :file_root)

  plug CmsbearWeb.Router
end
