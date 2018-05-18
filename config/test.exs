use Mix.Config

config :tus, controllers: [Tus.TestController]

config :tus, Tus.TestController,
  storage: Tus.Storage.Local,
  base_path: "test/files",
  cache: Tus.Cache.Memory,
  max_size: 1024 * 1024 * 10
