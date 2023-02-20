defmodule Tus.ConfigTest do
  use ExUnit.Case, async: true
  doctest Tus.Application

  test "Missing Tus controller config" do
    Application.put_env(:tus, :controllers, [Tus.SomeTestController])
    Application.put_env(:tus, Tus.OtherTestController, [
          storage: Tus.Storage.Local,
          base_path: "/tmp",
          cache: Tus.Cache.Memory,
          max_size: 1024 * 1024 * 200
          ])

    assert {:error, "Tus configuration for Elixir.Tus.SomeTestController not found"} =
      Tus.Application.start(nil, nil)

  end
end
