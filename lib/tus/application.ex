defmodule Tus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  import Supervisor.Spec, only: [worker: 3]

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tus.Supervisor]
    Supervisor.start_link(get_children(), opts)
  end

  defp get_children do
    Application.get_env(:tus, :controllers, [])
    |> Enum.map(&get_worker/1)
  end

  defp get_worker(controller) do
    # Starts a worker by calling: Tus.Worker.start_link(arg)
    # {Tus.Worker, arg},
    config =
      Application.get_env(:tus, controller)
      |> Enum.into(%{})
      |> Map.put(:cache_name, Module.concat(controller, TusCache))

    worker(config.cache, [config], [])
  end
end
