defmodule Tus.DeleteTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Tus.Delete

  import Plug.Conn.Status, only: [code: 1]
  import Tus.TestHelpers, only: [test_conn: 2, get_config: 0]
  alias Tus.TestController

  setup_all do
    %{config: get_config()}
  end

  test "file never existed" do
    conn =
      test_conn(:patch, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-offset", "0"},
          {"content-type", "application/offset+octet-stream"}
        ]
      })

    response = TestController.delete(conn, %{"uid" => "ineverwasandneverbe"})
    assert response.status == code(:not_found)
  end

  test "file in cache but not in storage", context do
    config = context[:config]
    uid = "ibelieveicanfly"

    file = %Tus.File{
      uid: uid,
      offset: 0,
      size: 123,
      path: "meh/#{uid}"
    }
    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(:delete, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-offset", "0"},
          {"content-type", "application/offset+octet-stream"}
        ]
      })

    response = TestController.delete(conn, %{"uid" => uid})
    assert response.status == code(:no_content)
    assert is_nil(config.cache.get(config.cache_name, uid))
  end


  test "delete file", context do
    config = context[:config]
    uid = "goodbyecruelworld"

    file =
      config.storage.create(
        %Tus.File{
          uid: uid,
          offset: 0,
          size: 123,
        },
        config
      )
    config.cache.put(config.cache_name, uid, file)
    assert File.exists?(Path.join(config.base_path, file.path))

    conn =
      test_conn(:delete, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-offset", "0"},
          {"content-type", "application/offset+octet-stream"}
        ]
      })

    response = TestController.delete(conn, %{"uid" => uid})
    assert response.status == code(:no_content)
    assert is_nil(config.cache.get(config.cache_name, uid))
    refute File.exists?(Path.join(config.base_path, file.path))
  end
end
