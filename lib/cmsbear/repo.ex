defmodule Cmsbear.Repo do
  use Ecto.Repo,
    otp_app: :cmsbear,
    adapter: Ecto.Adapters.SQLite3
end
