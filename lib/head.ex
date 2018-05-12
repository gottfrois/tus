defmodule Tus.Head do
  @moduledoc """
  """
  import Plug.Conn

  def head(conn, %{version: version} = config) when version == "1.0.0" do
    response(
      conn
        |> put_resp_header("tus-resumable", config.version)
        # The Server MUST prevent the client and/or proxies from caching the response
        # by adding the Cache-Control: no-store header to the response.
        |> put_resp_header("cache-control", "no-store"),

        Tus.cache_get(config)
    )
  end

  defp response(conn, nil) do
    conn |> resp(:not_found, "")
  end

  defp response(conn, %{} = file) do
    # If an upload contains additional metadata, responses to HEAD requests MUST
    # include the `Upload-Metadata` header and its value **as specified by the Client
    # during the creation**.
    conn =
      if file.metadata_src do
        conn |> put_resp_header("upload-metadata", file.metadata_src)
      else
        conn
      end

    conn
    # If the size of the upload is known, the Server MUST include the `Upload-Length`
    # header in the response.
    |> put_resp_header("upload-length", "#{file.size}")
    # The Server MUST always include the Upload-Offset header in the response for a HEAD request,
    #  even if the offset is 0, or the upload is already considered completed.
    |> put_resp_header("upload-offset", "#{file.offset}")
    |> resp(:ok, "")
  end
end
