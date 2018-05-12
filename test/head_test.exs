defmodule Tus.HeadTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Tus.Head

  import Plug.Conn.Status, only: [code: 1]
  import Tus.TestHelpers, only: [test_conn: 3, get_config: 0]
  alias Tus.TestController

  setup_all do
    %{config: get_config()}
  end

  test "HEAD: include the offset and the length in the response", context do
    config = context[:config]
    uid = "heyyou123"
    file = %Tus.File{uid: uid, offset: 0, size: 123_456}
    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(
        :head,
        %Plug.Conn{
          req_headers: [{"tus-resumable", Tus.latest_version()}]
        },
        "/" <> uid
      )

    response = TestController.head(conn, %{"uid" => uid})

    assert response.status == code(:ok)
    assert response |> get_resp_header("tus-resumable") == [Tus.latest_version()]
    assert response |> get_resp_header("upload-offset") == ["#{file.offset}"]
    assert response |> get_resp_header("upload-length") == ["#{file.size}"]
    assert response |> get_resp_header("upload-defer-length") == []
  end

  test "HEAD: If the resource is not found, the Server SHOULD return a 404 and no Upload-Offset header" do
    conn =
      test_conn(
        :head,
        %Plug.Conn{
          req_headers: [{"tus-resumable", Tus.latest_version()}]
        },
        "/bad-file-id"
      )

    response = TestController.head(conn, %{"uid" => "bad-file-id"})

    assert response.status == code(:not_found)
    assert response |> get_resp_header("tus-resumable") == [Tus.latest_version()]
    assert response |> get_resp_header("upload-offset") == []
  end
end
