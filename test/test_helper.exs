defmodule Tus.TestController do
  use Tus.Controller

  def on_begin_upload(_file) do
    send self(), :on_begin_upload_called
    :ok
  end

  def on_complete_upload(_file) do
    send self(), :on_complete_upload_called
    :ok
  end
end

defmodule Tus.TestHelpers do
  def test_conn(method, conn \\ [], uri \\ "/", body \\ nil) do
    Plug.Adapters.Test.Conn.conn(
      conn,
      method,
      uri,
      body
    )
  end

  def get_config do
    Application.get_env(:tus, Tus.TestController)
    |> Enum.into(%{})
    |> Map.put(:cache_name,  Module.concat(Tus.TestController, TusCache))
  end
end

ExUnit.start()
config = Tus.TestHelpers.get_config()
config.cache.start_link(config)
