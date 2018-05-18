defmodule Tus.Post do
  @moduledoc """
  An empty POST request is used to create a new upload resource
  """
  import Plug.Conn

  def post(conn, %{version: version, max_size: max_size} = config) when version == "1.0.0" do
    with {:ok, file} <- build_file(conn),
         :ok <- file_size_ok?(conn, file, max_size),
         {:ok, file} <- create_file(file, config),
         :ok <- cache_file(file, config),
         :ok <- config.on_begin_upload.(file) do
      conn
      |> put_resp_header("tus-resumable", config.version)
      |> put_resp_header("location", file.uid)
      |> resp(:created, "")
    else
      :too_large ->
        conn
        |> resp(:request_entity_too_large, "Data is larger than expected")

      {:error, reason} ->
        conn
        |> put_resp_header("tus-resumable", config.version)
        |> resp(:bad_request, reason)
    end
  end

  defp build_file(conn) do
    metadata_src =
      conn
      |> get_req_header("upload-metadata")
      |> List.first()

    metadata =
      if metadata_src do
        parse_metadata(metadata_src)
      else
        nil
      end

    file = %Tus.File{
      uid: UUID.uuid1(),
      size: get_size(conn),
      created_at: DateTime.to_unix(DateTime.utc_now()),
      metadata_src: metadata_src,
      metadata: metadata
    }

    {:ok, file}
  end

  def parse_metadata(metadata_src) do
    metadata_src
    |> String.split(~r/\s*,\s*/)
    |> Enum.map(&split_metadata/1)
  end

  defp split_metadata(kv) do
    [key, value] = String.split(kv, ~r/\s+/, parts: 2)
    {key, Base.decode64!(value)}
  end

  defp get_size(conn) do
    conn
    |> get_req_header("upload-length")
    |> List.first()
    |> Kernel.||("0")
    |> String.to_integer()
  end

  defp file_size_ok?(conn, %{size: size}, hard_limit) do
    soft_limit =
      conn
      |> get_req_header("tus-max-size")
      |> List.first()
      |> Kernel.||("#{hard_limit}")
      |> String.to_integer()

    if size < min(hard_limit, soft_limit) do
      :ok
    else
      :too_large
    end
  end

  defp create_file(file, config) do
    file = Tus.storage_create(file, config)
    {:ok, file}
  end

  defp cache_file(file, config) do
    Tus.cache_put(file, config)
    :ok
  end
end
