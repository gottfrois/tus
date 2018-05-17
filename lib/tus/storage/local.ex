defmodule Tus.Storage.Local do
  @default_base_path "priv/static/files/"

  def get_path() do
    time = DateTime.utc_now()
    Path.join(["#{time.year}", "#{time.month}", "#{time.day}"])
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
    path = get_path()

    path
    |> make_basepath(config)
    |> Path.join(file.uid)
    |> File.open!([:write])
    |> File.close()

    path = path |> Path.join(file.uid)

    %Tus.File{file | path: path}
  end

  def append(file, body, config) do
    base_path(config)
    |> Path.join(file.path)
    |> File.open([:append, :binary, :delayed_write, :raw])
    |> case do
      {:ok, filesto} ->
        IO.binwrite(filesto, body)
        File.close(filesto)
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  def delete(file, config) do
    Path.join([base_path(config), file.path])
    |> File.rm()
  end
end
