use Mix.Config

config :tus, controllers: [Tus.TestController]

# config :ex_aws,
#   access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
#   secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]


config :tus, Tus.TestController,
  base_url: "/static/files",

  storage: Tus.Storage.Local,
  base_path: "test/files",
  # storage: Tus.Storage.S3,
  # s3_bucket: "jpscaletti-tus-test",

  cache: Tus.Cache.Memory,
  # cache: Tus.Cache.Redis,

  max_size: 1024 * 1024 * 10
