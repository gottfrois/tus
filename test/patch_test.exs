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
end
