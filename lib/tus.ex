defmodule Tus do
  @moduledoc """
  """
  import Plug.Conn

  @latest_version "1.0.0"
  @supported_versions ["1.0.0"]
  @extension "creation,termination"

  def latest_version, do: @latest_version
  def supported_versions, do: @supported_versions
  def str_supported_versions, do: Enum.join(@supported_versions, ",")
  def extension, do: @extension

  def options(conn, %{max_size: max_size}) do
    conn
    |> put_resp_header("tus-resumable", latest_version())
    |> put_resp_header("tus-version", str_supported_versions())
    |> put_resp_header("tus-max-size", "#{max_size}")
    |> put_resp_header("tus-extension", extension())
    |> resp(:no_content, "")
  end

  def post(conn, %{version: version} = config) when version in @supported_versions do
    Tus.Post.post(conn, config)
  end

  def post(conn, _config) do
    unsupported_version(conn)
  end

  def head(conn, %{version: version} = config) when version in @supported_versions do
    Tus.Head.head(conn, config)
  end

  def head(conn, _config) do
    unsupported_version(conn)
  end

  def patch(conn, %{version: version} = config) when version in @supported_versions do
    Tus.Patch.patch(conn, config)
  end

  def patch(conn, _config) do
    unsupported_version(conn)
  end

  def delete(conn, %{version: version} = config) when version in @supported_versions do
    Tus.Delete.delete(conn, config)
  end

  def delete(conn, _config) do
    unsupported_version(conn)
  end

  defp unsupported_version(conn) do
    conn
    |> put_resp_header("tus-version", str_supported_versions())
    |> resp(:precondition_failed, "API version not supported")
  end

  def cache_get(%{cache: cache, cache_name: cache_name, uid: uid}) do
    cache.get(cache_name, uid)
  end

  def cache_put(%{cache: cache, cache_name: cache_name}, %Tus.File{uid: uid} = file) do
    cache.put(cache_name, uid, file)
  end

  def cache_delete(%{cache: cache, cache_name: cache_name}, %Tus.File{uid: uid}) do
    cache.delete(cache_name, uid)
  end

  def storage_create(%{storage: storage} = config, %Tus.File{} = file) do
    storage.create(file, config)
  end

  def storage_append(%{storage: storage} = config, %Tus.File{} = file, data) do
    storage.append(file, data, config)
  end

  def storage_delete(%{storage: storage} = config, %Tus.File{} = file) do
    storage.delete(file, config)
  end

end
