defmodule Tus.Storage.Local do
  @default_base_path "priv/static/files/"

  def get_path(uid) do
    uid
    |> String.split("")
    |> Enum.slice(1, 3)
    |> Path.join()
  end

  defp base_path(config) do
    config
    |> Map.get(:base_path, @default_base_path)
    |> Path.expand()
  end

  def make_basepath(path, config) do
    basepath = Path.join([base_path(config), path])
    File.mkdir_p!(basepath)
    basepath
  end

  def create(file, config) do
    path = get_path(file.uid)

    path
    |> make_basepath(config)
    |> Path.join(file.uid)
    |> File.open!([:write])
    |> File.close()

    path = path |> Path.join(file.uid)

    %Tus.File{file | path: path}
  end

  def append(file, config, body) do
    base_path(config)
    |> Path.join(file.path)
    |> File.open([:append, :binary, :delayed_write, :raw])
    |> case do
      {:ok, filesto} ->
        IO.binwrite(filesto, body)
        File.close(filesto)
        {:ok, file}

      {:error, error} ->
        {:error, error}
    end
  end

  def complete_upload(file, _config) do
    {:ok, file}
  end

  def delete(file, config) do
    Path.join([base_path(config), file.path])
    |> File.rm()
  end
end
