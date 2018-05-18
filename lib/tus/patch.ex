defmodule Tus.Patch do
  @moduledoc """
  """
  import Plug.Conn

  def patch(conn, %{version: version} = config) when version == "1.0.0" do
    with {:ok, %Tus.File{} = file} <- get_file(config),
         :ok <- offsets_match?(conn, file),
         {:ok, data, conn} <- get_body(conn),
         data_size <- byte_size(data),
         :ok <- valid_size?(file, data_size),
         {:ok, file} <- append_data(file, config, data) do
      file = %Tus.File{file | offset: file.offset + data_size}
      Tus.cache_put(file, config)

      if upload_completed?(file) do
        Tus.storage_complete_upload(file, config)
        config.on_complete_upload.(file)
        Tus.cache_delete(file, config)
      end

      conn
      |> put_resp_header("tus-resumable", config.version)
      |> put_resp_header("upload-offset", "#{file.offset}")
      |> resp(:no_content, "")
    else
      :file_not_found ->
        conn |> resp(:not_found, "File not found")

      :offsets_mismatch ->
        conn |> resp(:conflict, "Offset don't match")

      :no_body ->
        conn |> resp(:bad_request, "No body")

      :too_large ->
        conn |> resp(:request_entity_too_large, "Data is larger than expected")

      {:error, _reason} ->
        conn |> resp(:bad_request, "Unable to save file")

      :too_small ->
        conn |> resp(:conflict, "Data is smaller than what the storage backend can handle")
    end
  end

  defp get_file(config) do
    case Tus.cache_get(config) do
      %Tus.File{} = file -> {:ok, file}
      _ -> :file_not_found
    end
  end

  defp offsets_match?(conn, file) do
    if file.offset == get_offset(conn) do
      :ok
    else
      :offsets_mismatch
    end
  end

  defp get_offset(conn) do
    conn
    |> get_req_header("upload-offset")
    |> List.first()
    |> Kernel.||("0")
    |> String.to_integer()
  end

  defp get_body(conn) do
    case read_body(conn) do
      {_, binary, conn} -> {:ok, binary, conn}
      _ -> :no_body
    end
  end

  defp valid_size?(file, data_size) do
    if file.offset + data_size > file.size do
      :too_large
    else
      :ok
    end
  end

  defp append_data(file, config, data) do
    Tus.storage_append(file, config, data)
  end

  defp upload_completed?(file) do
    file.size == file.offset
  end
end
