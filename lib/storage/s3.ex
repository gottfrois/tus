defmodule Tus.Storage.S3 do
  @moduledoc """
  Provides a storage backend using AWS S3 or compatible servers.

  Configuration
  In order to allow this backend to function properly, the user accessing the bucket must have at least the
  following AWS IAM policy permissions for the bucket and all of its subresources:

  ```
  s3:AbortMultipartUpload
  s3:DeleteObject
  s3:GetObject
  s3:ListMultipartUploadParts
  s3:PutObject
  ```

  Tus.Storage.S3 uses the ExAWS package, so you'll need to add valid AWS keys to its config.
  Consult the (ExAWS documentation)[https://hexdocs.pm/ex_aws/ExAws.html#module-aws-key-configuration] for more details
  """
  alias ExAws.S3

  @default_host "https://s3.amazonaws.com"
  @default_min_part_size 5 * 1024 * 1024

  defp file_path(config, file) do
    Enum.join(
      [
        config
        |> Map.get(:s3_base_path, "")
        |> String.trim_trailing("/"),
        file.uid
      ],
      "/"
    )
  end

  defp host(config) do
    config |> Map.get(:s3_host, @default_host)
  end

  defp base_url(config, host, bucket) do
    case config |> Map.get(:base_url) do
      nil ->
        Enum.join(
          [
            host |> String.trim_trailing("/"),
            bucket |> String.trim_leading("/")
          ],
          "/"
        )

      base_url ->
        base_url
    end
  end

  defp url(config, host, bucket, file_path) do
    Enum.join(
      [
        base_url(config, host, bucket) |> String.trim_trailing("/"),
        file_path |> String.trim_leading("/")
      ],
      "/"
    )
  end

  defp min_part_size(config) do
    config |> Map.get(:s3_min_part_size, @default_min_part_size)
  end

  defp part_too_small?(config, file, part_size) do
    min_size = min_part_size(config)
    part_size < min_size && file.offset + min_size > file.size
  end

  def create(file, config) do
    host = host(config)
    file_path = file_path(config, file)

    %{bucket: config.s3_bucket, path: file_path, opts: [], upload_id: nil}
    |> S3.Upload.initialize(host: host)
    |> case do
      {:ok, rs} ->
        %Tus.File{
          file
          | upload_id: rs.upload_id,
            path: file_path,
            url: url(config, host, config.s3_bucket, file_path)
        }

      err ->
        {:error, err}
    end
  end

  def append(file, body, config) do
    part_size = byte_size(body)

    if part_too_small?(config, file, part_size) do
      :too_small
    else
      append_data(file, body, config, part_size)
    end
  end

  def append_data(file, body, config, part_size) do
    part_number = div(file.offset, min_part_size(config)) + 1

    config.s3_bucket
    |> S3.upload_part(file.path, file.upload_id, part_number, body, "Content-Length": part_size)
    |> ExAws.request(host: host(config))
    |> case do
      {:ok, _response} -> :ok
      error -> {:error, error}
    end
  end

  def delete(file, config) do
    ""
    |> ExAws.S3.delete_object(file_path(config, file))
    |> ExAws.request(host: host(config))
  end
end
