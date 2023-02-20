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
    case get_children() do
      {:error, _} = e -> e
      children when is_list(children) -> Supervisor.start_link(children, opts)
    end
  end

  defp get_children do
    Application.get_env(:tus, :controllers, [])
    |> Enum.reduce_while([], fn controller, lst ->
      case Application.get_env(:tus, controller) do
        worker_opts when is_list(worker_opts) ->
          {:cont, [start_worker(controller, worker_opts) | lst]}
        nil ->
            {:halt, {:error, "Tus configuration for #{controller} not found"}}
      end
    end)
  end

  defp start_worker(controller, opts) do
    # Starts a worker by calling: Tus.Worker.start_link(arg)
    # {Tus.Worker, arg},
    config = opts
    |> Enum.into(%{})
    |> Map.put(:cache_name, Module.concat(controller, TusCache))

    worker(config.cache, [config], [])
  end
end
