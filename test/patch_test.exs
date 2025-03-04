defmodule Tus.PatchTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Tus.Patch

  import Plug.Conn.Status, only: [code: 1]
  import Tus.TestHelpers, only: [test_conn: 2, test_conn: 4, get_config: 0]
  alias Tus.TestController

  setup_all do
    %{config: get_config()}
  end

  test "error if file not found" do
    conn =
      test_conn(:patch, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-offset", "0"},
          {"content-type", "application/offset+octet-stream"}
        ]
      })

    response = TestController.patch(conn, %{"uid" => "imnotherelalalaa"})
    assert response.status == code(:not_found)
  end

  test "error if offsets mismatch", context do
    config = context[:config]
    uid = "heyyou123"
    offset = 100

    file = %Tus.File{
      uid: uid,
      offset: 0,
      size: 123_456,
      path: "meh/#{uid}"
    }

    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(:patch, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-offset", "#{offset + 100}"},
          {"content-type", "application/offset+octet-stream"}
        ]
      })

    response = TestController.patch(conn, %{"uid" => uid})
    assert response.status == code(:conflict)
  end

  test "error if no body", context do
    config = context[:config]
    uid = "ihavenocontent"

    file = %Tus.File{
      uid: uid,
      offset: 0,
      size: 123_456,
      path: "meh/#{uid}"
    }

    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(:patch, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-offset", "0"},
          {"content-type", "application/offset+octet-stream"}
        ]
      })

    response = TestController.patch(conn, %{"uid" => uid})
    assert response.status == code(:bad_request)
  end

  test "error if body larger than expected", context do
    config = context[:config]
    uid = "radicalcandor"

    file = %Tus.File{
      uid: uid,
      offset: 0,
      size: 10,
      path: "meh/#{uid}"
    }

    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(
        :patch,
        %Plug.Conn{
          req_headers: [
            {"tus-resumable", Tus.latest_version()},
            {"upload-offset", "0"},
            {"content-type", "application/offset+octet-stream"}
          ]
        },
        "/files/#{uid}",
        "lorem ipsum sit amet 1234567890 this is a test"
      )

    response = TestController.patch(conn, %{"uid" => uid})
    assert response.status == code(:request_entity_too_large)
  end

  test "error if file doesn't already exists", context do
    config = context[:config]
    uid = "somethingsomething"
    body = "lorem ipsum sit amet 1234567890 this is a test"

    file = %Tus.File{
      uid: uid,
      offset: 0,
      size: 123_456,
      path: "meh/#{uid}"
    }

    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(
        :patch,
        %Plug.Conn{
          req_headers: [
            {"tus-resumable", Tus.latest_version()},
            {"upload-offset", "0"},
            {"content-type", "application/offset+octet-stream"}
          ]
        },
        "/files/#{uid}",
        body
      )

    response = TestController.patch(conn, %{"uid" => uid})
    assert response.status == code(:bad_request)
  end

  test "body shorter than total is ok", context do
    config = context[:config]
    uid = "somethingsomething"
    body = "lorem ipsum sit amet 1234567890 this is a test"
    initial_offset = 100

    file =
      config.storage.create(
        %Tus.File{
          uid: uid,
          offset: initial_offset,
          size: 123_456
        },
        config
      )

    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(
        :patch,
        %Plug.Conn{
          req_headers: [
            {"tus-resumable", Tus.latest_version()},
            {"upload-offset", "#{initial_offset}"},
            {"content-type", "application/offset+octet-stream"}
          ]
        },
        "/files/#{uid}",
        body
      )

    response = TestController.patch(conn, %{"uid" => uid})
    assert response.status == code(:no_content)
    assert response |> get_resp_header("tus-resumable") == [Tus.latest_version()]
    assert response |> get_resp_header("upload-offset") == ["#{initial_offset + byte_size(body)}"]

    # Still exists
    assert config.cache.get(config.cache_name, uid)
  end

  test "storage can control reported offset", context do
    config = context[:config]
    uid = "customoffset"
    body = "lorem ipsum sit amet 1234567890 this is a test"
    initial_offset = 10
    expected_offset = 25  # Different from initial_offset + byte_size(body)

    # Create a mock storage module that returns a custom offset
    defmodule MockStorage do
      @custom_offset 25  # Define the offset as a module attribute
      
      def create(file, _config), do: %{file | path: "meh/#{file.uid}"}
      def append(_file, _config, _data), do: {:ok, %Tus.File{uid: "customoffset", offset: @custom_offset, size: 100, path: "meh/customoffset"}, @custom_offset}
      def complete_upload(file, _config), do: {:ok, file}
      def delete(_file, _config), do: :ok
      def file_path(uid, _config), do: "meh/#{uid}"
      def url(uid, _config), do: "http://example.com/#{uid}"
      
      # Add these methods to handle any other operations that might be called
      def base_path(_config), do: ""
      def local_path(path, _config), do: path
    end

    # Override the storage in config
    config = Map.put(config, :storage, MockStorage)

    file = MockStorage.create(
      %Tus.File{
        uid: uid,
        offset: initial_offset,
        size: 100
      },
      config
    )

    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(
        :patch,
        %Plug.Conn{
          req_headers: [
            {"tus-resumable", Tus.latest_version()},
            {"upload-offset", "#{initial_offset}"},
            {"content-type", "application/offset+octet-stream"}
          ]
        },
        "/files/#{uid}",
        body
      )

    # Use Tus.Patch directly to bypass controller
    config = Map.put(config, :uid, uid)
    config = Map.put(config, :version, Tus.latest_version())
    response = Tus.Patch.patch(conn, config)
    assert response.status == code(:no_content)
    assert response |> get_resp_header("tus-resumable") == [Tus.latest_version()]
    
    # Verify the custom offset is used, not the calculated one
    assert response |> get_resp_header("upload-offset") == ["#{expected_offset}"]
    
    # Verify the file in cache has the custom offset
    cached_file = config.cache.get(config.cache_name, uid)
    assert cached_file.offset == expected_offset
  end

  test "on_complete_upload called", context do
    config = context[:config]
    uid = "youcompleteme"
    body = "lorem ipsum sit amet 1234567890 this is a test"

    file =
      config.storage.create(
        %Tus.File{
          uid: uid,
          offset: 0,
          size: byte_size(body)
        },
        config
      )

    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(
        :patch,
        %Plug.Conn{
          req_headers: [
            {"tus-resumable", Tus.latest_version()},
            {"upload-offset", "0"},
            {"content-type", "application/offset+octet-stream"}
          ]
        },
        "/files/#{uid}",
        body
      )

    response = TestController.patch(conn, %{"uid" => uid})
    assert response.status == code(:no_content)
    assert response |> get_resp_header("tus-resumable") == [Tus.latest_version()]
    assert response |> get_resp_header("upload-offset") == ["#{byte_size(body)}"]

    # https://dockyard.com/blog/2016/03/24/testing-function-delegation-in-elixir-without-stubbing
    assert_receive :on_complete_upload_called

    # Deleted after calling `on_complete_upload`
    refute config.cache.get(config.cache_name, uid)
  end

  test "with expiration protocol enabled", context do
    config = context[:config]
    app_env = Application.get_env(:tus, Tus.TestController, [])

    new_app_env =
      app_env
      |> Keyword.update(:expiration_period, 300, fn _ -> 300 end)

    Application.put_env(:tus, Tus.TestController, new_app_env)

    uid = "youcompleteme"
    body = "lorem ipsum sit amet 1234567890 this is a test"

    file =
      config.storage.create(
        %Tus.File{
          uid: uid,
          offset: 0,
          created_at: DateTime.to_unix(DateTime.utc_now()),
          size: byte_size(body)
        },
        config
      )

    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(
        :patch,
        %Plug.Conn{
          req_headers: [
            {"tus-resumable", Tus.latest_version()},
            {"upload-offset", "0"},
            {"content-type", "application/offset+octet-stream"}
          ]
        },
        "/files/#{uid}",
        body
      )

    response = TestController.patch(conn, %{"uid" => uid})
    assert response.status == code(:no_content)
    assert response |> get_resp_header("tus-resumable") == [Tus.latest_version()]
    assert response |> get_resp_header("upload-offset") == ["#{byte_size(body)}"]
    [expire_at] = response |> get_resp_header("upload-expires")
    assert is_binary(expire_at)

    on_exit(fn ->
      Application.put_env(:tus, Tus.TestController, app_env)
    end)
  end
end
