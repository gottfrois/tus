defmodule Tus.Delete do
  @moduledoc """
  """
  import Plug.Conn

  def delete(conn, %{version: version} = config) when version == "1.0.0" do
    with %Tus.File{} = file <- Tus.cache_get(config) do
      Tus.storage_delete(config, file)
      Tus.cache_delete(config, file)

      conn
      |> put_resp_header("tus-resumable", config.version)
      |> resp(:no_content, "")
    else
      nil ->
        conn
        |> put_resp_header("tus-resumable", config.version)
        |> resp(:not_found, "")
    end
  end
end
