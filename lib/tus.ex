defmodule Tus do
  @moduledoc """
  An implementation of a *[tus.io](https://tus.io/)* **server** in Elixir

  > **tus** is a protocol based on HTTP for *resumable file uploads*. Resumable
  > means that an upload can be interrupted at any moment and can be resumed without
  > re-uploading the previous data again.
  >
  > An interruption may happen willingly, if the user wants to pause,
  > or by accident in case of an network issue or server outage.

  It's currently capable of accepting uploads with arbitrary sizes and storing them locally
  on disk. Due to its modularization and extensibility, support for any cloud provider
  *could* easily be added.

  ## Features

  This library implements the core TUS API v1.0.0 protocol and the following extensions:

  - Creation Protocol (http://tus.io/protocols/resumable-upload.html#creation). Deferring the upload's length is not possible.
  - Termination Protocol (http://tus.io/protocols/resumable-upload.html#termination)


  ## Installation

  Add this repo to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:tus, "~> 0.1.0"},
    ]
  end
  ```

  ## Usage

  **1. Add new controller(s)**

  ```elixir
  defmodule DemoWeb.UploadController do
    use DemoWeb, :controller
    use Tus.Controller

    # start upload optional callback
    def on_begin_upload(file) do
      ...
      :ok  # or {:error, reason} to reject the uplaod
    end
    
    # Completed upload optional callback
    def on_complete_upload(file) do
      ...
    end
  end
  ```

  **2. Add routes for each of your upload controllers**

  ```elixir
  scope "/files", DemoWeb do
      options "/",          UploadController, :options
      match :head, "/:uid", UploadController, :head
      post "/",             UploadController, :post
      patch "/:uid",        UploadController, :patch
      delete "/:uid",       UploadController, :delete
  end
  ```

  **3. Add config for each controller (see next section)**


  ## Configuration (the global way) 

  ```elixir
  # List here all of your upload controllers
  config :tus, controllers: [DemoWeb.UploadController]

  # This is the config for the DemoWeb.UploadController
  config :tus, DemoWeb.UploadController,
    storage: Tus.Storage.Local,
    base_path: "priv/static/files/",

    cache: Tus.Cache.Memory,

    # max supported file size, in bytes (default 20 MB)
    max_size: 1024 * 1024 * 20
  ```

  - `storage`:
    module which handle storage file application
    This library includes only `Tus.Storage.Local` but you can install the
    [`tus_storage_s3`](https://hex.pm/packages/tus_storage_s3) hex package to use **Amazon S3**.

  - `cache`:
    module for handling the temporary uploads metadata
    This library comes with `Tus.Cache.Memory` but you can install the
    [`tus_cache_redis`](https://hex.pm/packages/tus_cache_redis) hex package to use a **Redis** based one.

  - `max_size`:
    hard limit on the maximum size an uploaded file can have 

  ### Options for `Tus.Storage.Local`

  - `base_path`:
    where in the filesystem the uploaded files'll be stored

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

  @doc false
  def cache_get(%{cache: cache, cache_name: cache_name, uid: uid}) do
    cache.get(cache_name, uid)
  end

  @doc false
  def cache_put(%Tus.File{uid: uid} = file, %{cache: cache, cache_name: cache_name}) do
    cache.put(cache_name, uid, file)
  end

  @doc false
  def cache_delete(%Tus.File{uid: uid}, %{cache: cache, cache_name: cache_name}) do
    cache.delete(cache_name, uid)
  end

  @doc false
  def storage_create(%Tus.File{} = file, %{storage: storage} = config) do
    storage.create(file, config)
  end

  @doc false
  def storage_append(%Tus.File{} = file, %{storage: storage} = config, data) do
    storage.append(file, config, data)
  end

  @doc false
  def storage_complete_upload(%Tus.File{} = file, %{storage: storage} = config) do
    storage.complete_upload(file, config)
  end

  @doc false
  def storage_delete(%Tus.File{} = file, %{storage: storage} = config) do
    storage.delete(file, config)
  end
end
