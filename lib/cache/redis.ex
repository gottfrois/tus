defmodule Tus.Cache.Redis do
  def start_link(%{cache_name: cache_name} = config) do
    Redix.start_link(
      [
        host: Map.get(config, :redis_host, "localhost"),
        port: Map.get(config, :redis_port, 6379)
      ],
      name: cache_name
    )
  end

  def get(name, key) do
    case Redix.command(name, ["GET", key]) do
      {:ok, nil} -> nil
      {:ok, value} -> decode(value)
      _ -> nil
    end
  end

  def put(name, key, file) do
    {:ok, _} = Redix.command(name, ["SET", key, encode(file)])
  end

  def delete(name, key) do
    _ = Redix.command(name, ["DEL", key])
  end

  defp encode(file) do
    :erlang.term_to_binary(file)
  end

  defp decode(value) do
    :erlang.binary_to_term(value)
  end
end
