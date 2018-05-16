defmodule Tus.Delete do
  @moduledoc """
  """
  import Plug.Conn

  def delete(conn, %{version: version} = config) when version == "1.0.0" do
    with {:ok, %Tus.File{} = file} <- get_file(config) do
      Tus.storage_delete(config, file)
      Tus.cache_delete(config, file)

      conn
      |> put_resp_header("tus-resumable", config.version)
      |> resp(:no_content, "")
    else
      :file_not_found ->
        conn
        |> put_resp_header("tus-resumable", config.version)
        |> resp(:not_found, "")
    end
  end

  defp get_file(config) do
    case Tus.cache_get(config) do
      %Tus.File{} = file -> {:ok, file}
      _ -> :file_not_found
    end
  end
end
