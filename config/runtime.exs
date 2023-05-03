import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/cmsbear/cmsbear.db
      """

  config :cmsbear, Cmsbear.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :cmsbear, CmsbearWeb.Endpoint,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base

  cmsbear_api_key =
    System.get_env("CMSBEAR_API_KEY") ||
      raise """
      environment variable CMSBEAR_API_KEY is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  cmsbear_file_root =
    System.get_env("CMSBEAR_FILE_ROOT") ||
      raise """
      environment variable CMSBEAR_FILE_ROOT is missing.
      Value might be e.g. /Users/joi/projects/cmsbearfileroot
      """

  cmsbear_client_id =
    System.get_env("CMSBEAR_OIDC_GOOGLE_CLIENT_ID") ||
      raise """
      environment variable CMSBEAR_OIDC_GOOGLE_CLIENT_ID is missing.
      """

  cmsbear_client_secret =
    System.get_env("CMSBEAR_OIDC_GOOGLE_CLIENT_SECRET") ||
      raise """
      environment variable CMSBEAR_OIDC_GOOGLE_CLIENT_SECRET is missing.
      """

  cmsbear_url =
    System.get_env("CMSBEAR_URL") ||
      raise """
      environment variable CMSBEAR_URL is missing.
      Value might be e.g. https://new.joisig.com
      """

  cmsbear_owner_email =
    System.get_env("CMSBEAR_OWNER_EMAIL") ||
      raise """
      environment variable CMSBEAR_OWNER_EMAIL is missing.
      """

  config :cmsbear,
    api_key: cmsbear_api_key,
    file_root: cmsbear_file_root,
    owner_email: cmsbear_owner_email,
    openid_connect_providers: [
      google: [
        discovery_document_uri: "https://accounts.google.com/.well-known/openid-configuration",
        client_id: cmsbear_client_id,
        client_secret: cmsbear_client_secret,
        redirect_uri: "#{cmsbear_url}/auth/oidc/callback",
        response_type: "code",
        scope: "openid email profile"
      ]
    ]

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :cmsbear, CmsbearWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.
end
