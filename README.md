# Elixir-tus

**THIS IS A WORK IN PROGRESS**

**NOT READY FOR PRODUCTION USE**

<img alt="Tus logo" src="https://github.com/tus/tus.io/blob/master/assets/img/tus1.png?raw=true" width="30%" align="right" />

An implementation of a *[tus](https://tus.io/)* **server** in Elixir

> **tus** is a protocol based on HTTP for *resumable file uploads*. Resumable
> means that an upload can be interrupted at any moment and can be resumed without
> re-uploading the previous data again. An interruption may happen willingly, if
> the user wants to pause, or by accident in case of an network issue or server
> outage.

It's currently capable of accepting uploads with arbitrary sizes and storing them locally
on disk. Due to its modularization and extensibility, support for any cloud provider
*could* easily be added.

## Features

This library implements the core TUS API v1.0.0 protocol and the following extensions:

- Creation Protocol (http://tus.io/protocols/resumable-upload.html#creation). Deferring the upload's length is not possible.
- Termination Protocol (http://tus.io/protocols/resumable-upload.html#termination) **TODO**


## Installation

Add this repo to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tus, "~> 0.1.0"},
  ]
end
```

If you're going to use Tus.Storage.S3 you'll also need to add this other dependencies:

```elixir
def deps do
  [
    {:tus, "~> 0.1.0"},

    {:ex_aws, "~> 2.0"},
    {:ex_aws_s3, "~> 2.0"},
    {:hackney, "~> 1.9"},
    {:sweet_xml, "~> 0.6"},
  ]
end
```

## Usage

**1. Add new controller(s)**

```elixir
defmodule DemoWeb.UploadController do
  use DemoWeb, :controller
  use Tus.Controller

  # start upload optional callback
  def on_begin_upload(file) do
    ...
    :ok  # or {:error, reason} to reject the uplaod
  end
	
  # Completed upload optional callback
  def on_complete_upload(file) do
    ...
  end
end
```

**2. Add routes for each of your upload controllers**

```elixir
scope "/files", DemoWeb do
    options "/",          UploadController, :options
    match :head, "/:uid", UploadController, :head
    post "/",             UploadController, :post
    patch "/:uid",        UploadController, :patch
    delete "/:uid",       UploadController, :delete
end
```

**3. Add config for each controller (see next section)**


## Config

```elixir
# List here all of your upload controllers
config :tus, controllers: [DemoWeb.UploadController]

# This is the config for the DemoWeb.UploadController
config :tus, DemoWeb.UploadController,
  base_url: "/static/files",

  storage: Tus.Storage.Local,
  # storage: Tus.Storage.S3,

  # Tus.Storage.Local
  base_path: "priv/static/files/",

  # Tus.Storage.S3
  # s3_host: "https://s3.amazonaws.com"
  # s3_bucket: "mybucketname"
  # s3_base_path: ""

  cache: Tus.Cache.Redis,
  # cache: Tus.Cache.Memory,

  # Tus.Cache.Redis
  redis_host: "localhost",
  redis_port: 6379,

  # max supported file size, in bytes (default 20 MB)
  max_size: 1024 * 1024 * 20
```

- `base_url`:
  Tus requires that the server returns the URL of the uploaded file.
  This could be a static location a local route that does authentication
  checks, a CDN, etc.

- `storage`:
  module which handle storage file application
  This library includes `Tus.Storage.Local` and `Tus.Storage.S3`

- `cache`:
  module for handling the temporary uploads metadata
  This library comes with `Tus.Cache.Memory` and `Tus.Cache.Redis`

- `max_size`:
  hard limit on the maximum size an uploaded file can have 

### Options for `Tus.Storage.Local`

- `base_path`:
  where in the filesystem the uploaded files'll be stored

### Options for `Tus.Storage.S3`

- `s3_host`:
  Optional — Amazon S3 host (https://s3.amazonaws.com) will be used by default.

- `s3_bucket`:
  Name of the bucket were the uploaded files'll be stored

- `s3_base_path`:
  Optipnal – This allows you to store the files in a "subfolder" of the bucket.

Tus.Storage.S3 uses the ExAWS package, so you'll need to add valid AWS keys to its config.

```elixir
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]
```
This means it will try to resolve credentials in order

a. Look for the AWS standard AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
b. Resolve credentials with IAM

Consult the (ExAWS documentation)[https://hexdocs.pm/ex_aws/ExAws.html#module-aws-key-configuration] for more details

