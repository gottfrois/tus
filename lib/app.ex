defmodule Tus.App do
  @moduledoc false
  use Application
  import Supervisor.Spec, only: [worker: 3]

  def start(_, _) do
    Supervisor.start_link(get_children(), strategy: :one_for_one)
  end

  defp get_children do
    Application.get_env(:tus, :controllers)
    |> Enum.map(&get_worker/1)
  end

  defp get_worker(controller) do
    config =
      Application.get_env(:tus, controller)
      |> Enum.into(%{})
      |> Map.put(:cache_name, Module.concat(controller, TusCache))
    worker(config.cache, [config], [])
  end
end
